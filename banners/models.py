import uuid

from django.db import models
from django.db.models import F, Q

from courses.models import Course
from firms.models import Firm


class HomeBanner(models.Model):
    uuid = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)

    firm = models.ForeignKey(
        Firm,
        on_delete=models.PROTECT,
        related_name="home_banners",
    )
    course = models.ForeignKey(
        Course,
        on_delete=models.SET_NULL,
        related_name="home_banners",
        null=True,
        blank=True,
    )

    title = models.CharField(max_length=160)
    subtitle = models.TextField(blank=True)

    image = models.ImageField(upload_to="home_banners/%Y/%m/")

    action_label = models.CharField(max_length=60, blank=True)
    action_url = models.URLField(blank=True)

    display_order = models.PositiveIntegerField(default=0)
    starts_at = models.DateTimeField(null=True, blank=True, db_index=True)
    ends_at = models.DateTimeField(null=True, blank=True, db_index=True)

    is_active = models.BooleanField(default=True, db_index=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "home_banners"
        ordering = ["display_order", "-created_at"]
        indexes = [
            models.Index(fields=["firm", "is_active"]),
            models.Index(fields=["starts_at", "ends_at"]),
        ]
        constraints = [
            models.CheckConstraint(
                condition=(
                    Q(starts_at__isnull=True)
                    | Q(ends_at__isnull=True)
                    | Q(ends_at__gt=F("starts_at"))
                ),
                name="banner_end_after_start",
            )
        ]

    def __str__(self):
        return f"{self.firm.name} - {self.title}"
    

