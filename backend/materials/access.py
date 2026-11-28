"""One access decision for student URLs, progress and secure watch sessions."""
from django.db.models import Q
from django.utils import timezone
from rest_framework.exceptions import PermissionDenied

from courses.access import student_has_course_access, student_has_chapter_video_access
from .models import LearningMaterial


def available_materials(course):
    now = timezone.now()
    return LearningMaterial.objects.filter(
        firm=course.firm, course=course, is_active=True,
    ).filter(Q(available_from__isnull=True) | Q(available_from__lte=now)).filter(
        Q(available_until__isnull=True) | Q(available_until__gt=now)
    ).order_by("sequence", "created_at", "pk")


def material_access(student, material, cache=None):
    if not student.is_active or not student.firm.is_active or not material.course.is_active:
        return False, "ACCESS_INACTIVE", None
    cache = cache if cache is not None else {}
    scope_key = ("course_access", student.pk, material.course_id)
    if scope_key not in cache:
        cache[scope_key] = student_has_course_access(student=student, course=material.course)
    full = cache[scope_key]
    if not full and not (
        material.material_type == "VIDEO" and material.chapter_id
        and student_has_chapter_video_access(
            student=student, course=material.course, chapter=material.chapter,
        )
    ):
        return False, "COURSE_ACCESS_REQUIRED", None
    if material.material_type != "VIDEO":
        return True, None, None
    # Sequence is course-wide; ties use creation time and database ID.
    video_key = ("video_sequence", student.pk, material.course_id)
    if video_key not in cache:
        videos = available_materials(material.course).filter(material_type="VIDEO")
        if not full:
            now = timezone.now()
            chapters = student.chapter_video_accesses.filter(
                course=material.course, is_active=True,
            ).filter(Q(access_start_at__isnull=True) | Q(access_start_at__lte=now)).filter(
                Q(access_end_at__isnull=True) | Q(access_end_at__gt=now)
            ).values_list("chapter_id", flat=True)
            videos = videos.filter(chapter_id__in=chapters)
        from progress.models import StudentMaterialProgress
        completed = set(StudentMaterialProgress.objects.filter(
            student=student, firm=student.firm, course=material.course,
            is_verified_completed=True,
        ).values_list("material_id", flat=True))
        cache[video_key] = (list(videos.values_list("pk", "uuid")), completed)
    videos, completed = cache[video_key]
    for previous_pk, previous_uuid in videos:
        if previous_pk == material.pk:
            break
        if previous_pk not in completed:
            return False, "PREVIOUS_VIDEO_INCOMPLETE", str(previous_uuid)
    return True, None, None


def require_material_access(student, material):
    allowed, reason, prerequisite = material_access(student, material)
    if not allowed:
        raise PermissionDenied({"reason": reason, "prerequisite_material_uuid": prerequisite})
