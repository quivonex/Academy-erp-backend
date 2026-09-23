from decimal import Decimal

from django.db import transaction
from django.utils import timezone

from materials.models import LearningMaterial

from .models import StudentMaterialProgress


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
        # Never move cumulative watched time backward.
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

        # 90% watched = completed.
        if progress.completion_percentage >= Decimal(
            "90.00"
        ):
            progress.is_completed = True

    elif mark_completed:
        # PDF / document / link can be explicitly
        # marked complete by the client.
        progress.completion_percentage = Decimal(
            "100.00"
        )
        progress.is_completed = True

    if progress.is_completed and not progress.completed_at:
        progress.completed_at = now

    progress.last_accessed_at = now

    progress.save()

    return progress

