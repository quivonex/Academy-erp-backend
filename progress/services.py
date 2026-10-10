from decimal import Decimal

from django.db import transaction
from django.utils import timezone

from materials.models import LearningMaterial

from .models import (
    StudentMaterialProgress,
    StudentVideoWatchSession,
)


VIDEO_COMPLETION_PERCENTAGE = Decimal("90.00")

# Flutter should send a heartbeat every 15 seconds.
# The small tolerance supports normal network delay.
HEARTBEAT_TOLERANCE_SECONDS = 5
MAX_CREDIT_PER_HEARTBEAT_SECONDS = 20


def _issue_certificate_after_verified_progress(enrollment_id):
    """
    Called only after a video becomes verified-complete.
    The certificate service performs the final eligibility checks:
    video percentage, active enrollment, and full fee payment.
    """
    from certificates.services import issue_certificate_if_eligible
    from courses.models import Enrollment

    enrollment = Enrollment.objects.filter(
        pk=enrollment_id
    ).first()

    if enrollment:
        issue_certificate_if_eligible(
            enrollment=enrollment
        )


@transaction.atomic
def update_material_progress(
    *,
    student,
    material,
    validated_data,
):
    now = timezone.now()

    progress, created = (
        StudentMaterialProgress.objects
        .select_for_update()
        .get_or_create(
            student=student,
            material=material,
            defaults={
                "firm": student.firm,
                "course": material.course,
                "started_at": now,
            },
        )
    )

    if not progress.started_at:
        progress.started_at = now

    watched_seconds = validated_data.get(
        "watched_seconds"
    )

    last_position_seconds = validated_data.get(
        "last_position_seconds"
    )

    mark_completed = validated_data.get(
        "mark_completed",
        False,
    )

    if watched_seconds is not None:
        progress.watched_seconds = max(
            progress.watched_seconds,
            watched_seconds,
        )

    if last_position_seconds is not None:
        progress.last_position_seconds = (
            last_position_seconds
        )

    if (
        material.material_type
        == LearningMaterial.MaterialType.VIDEO
        and material.duration_seconds
    ):
        duration = material.duration_seconds

        percentage = (
            Decimal(progress.watched_seconds)
            / Decimal(duration)
        ) * Decimal("100")

        progress.completion_percentage = min(
            percentage,
            Decimal("100.00"),
        )

        if progress.completion_percentage >= Decimal(
            "90.00"
        ):
            progress.is_completed = True

    elif mark_completed:
        progress.completion_percentage = Decimal(
            "100.00"
        )
        progress.is_completed = True

    if progress.is_completed and not progress.completed_at:
        progress.completed_at = now

    progress.last_accessed_at = now
    progress.save()

    return progress


@transaction.atomic
def start_video_watch_session(
    *,
    student,
    material,
):
    now = timezone.now()

    progress, _ = (
        StudentMaterialProgress.objects
        .select_for_update()
        .get_or_create(
            firm=student.firm,
            student=student,
            material=material,
            defaults={
                "course": material.course,
                "started_at": now,
            },
        )
    )

    if not progress.started_at:
        progress.started_at = now
        progress.save(
            update_fields=[
                "started_at",
                "updated_at",
            ]
        )

    StudentVideoWatchSession.objects.filter(
        firm=student.firm,
        student=student,
        material=material,
        is_active=True,
    ).update(
        is_active=False,
        ended_at=now,
    )

    duration = material.duration_seconds or 0

    resume_position = min(
        progress.verified_watched_seconds,
        duration,
    )

    return StudentVideoWatchSession.objects.create(
        firm=student.firm,
        student=student,
        material=material,
        progress=progress,
        last_player_position_seconds=resume_position,
        last_heartbeat_at=now,
    )


@transaction.atomic
def record_verified_video_heartbeat(
    *,
    session,
    player_position_seconds,
):
    now = timezone.now()

    session = (
        StudentVideoWatchSession.objects
        .select_for_update()
        .select_related(
            "progress",
            "material",
            "student",
        )
        .get(pk=session.pk)
    )

    if not session.is_active:
        raise ValueError(
            "This video watch session has already ended."
        )

    material = session.material
    progress = session.progress
    duration = material.duration_seconds

    if not duration or duration <= 0:
        raise ValueError(
            "Video duration is required for secure tracking."
        )

    # Remember the previous status. This prevents certificate
    # evaluation on every heartbeat after video completion.
    was_verified_completed = (
        progress.is_verified_completed
    )

    player_position = min(
        player_position_seconds,
        duration,
    )

    previous_position = (
        session.last_player_position_seconds
    )

    last_heartbeat_at = (
        session.last_heartbeat_at
        or session.started_at
    )

    elapsed_seconds = max(
        0,
        int(
            (now - last_heartbeat_at).total_seconds()
        ),
    )

    maximum_allowed_advance = min(
        elapsed_seconds + HEARTBEAT_TOLERANCE_SECONDS,
        MAX_CREDIT_PER_HEARTBEAT_SECONDS,
    )

    # Seeking forward cannot give verified certificate progress.
    can_verify_forward_playback = (
        player_position >= previous_position
        and previous_position
        <= (
            progress.verified_watched_seconds
            + HEARTBEAT_TOLERANCE_SECONDS
        )
        and player_position
        <= (
            progress.verified_watched_seconds
            + maximum_allowed_advance
        )
    )

    if can_verify_forward_playback:
        progress.verified_watched_seconds = min(
            player_position,
            duration,
        )

    percentage = (
        Decimal(progress.verified_watched_seconds)
        / Decimal(duration)
    ) * Decimal("100")

    progress.verified_completion_percentage = min(
        percentage,
        Decimal("100.00"),
    )

    if (
        progress.verified_completion_percentage
        >= VIDEO_COMPLETION_PERCENTAGE
    ):
        progress.is_verified_completed = True

        if not progress.completed_at:
            progress.completed_at = now

    progress.last_position_seconds = player_position
    progress.last_accessed_at = now
    progress.save()

    session.last_player_position_seconds = player_position
    session.last_heartbeat_at = now
    session.save(
        update_fields=[
            "last_player_position_seconds",
            "last_heartbeat_at",
        ]
    )

    # Check certificate eligibility only when this video changes
    # from incomplete to verified-complete.
    if (
        progress.is_verified_completed
        and not was_verified_completed
    ):
        from courses.models import Enrollment

        enrollment = Enrollment.objects.filter(
            firm=material.firm,
            student=session.student,
            course=material.course,
            status=Enrollment.Status.ACTIVE,
        ).only("pk").first()

        if enrollment:
            transaction.on_commit(
                lambda enrollment_id=enrollment.pk: (
                    _issue_certificate_after_verified_progress(
                        enrollment_id
                    )
                )
            )

    return session


@transaction.atomic
def end_video_watch_session(*, session):
    now = timezone.now()

    session = (
        StudentVideoWatchSession.objects
        .select_for_update()
        .get(pk=session.pk)
    )

    if session.is_active:
        session.is_active = False
        session.ended_at = now
        session.save(
            update_fields=[
                "is_active",
                "ended_at",
            ]
        )

    return session