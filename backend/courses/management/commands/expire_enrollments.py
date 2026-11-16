from django.core.management.base import BaseCommand

from courses.services import expire_ended_enrollments


class Command(BaseCommand):
    help = "Expire enrollments whose access_end_at has passed"

    def handle(self, *args, **options):
        count = expire_ended_enrollments()
        self.stdout.write(
            self.style.SUCCESS(
                f"Expired {count} enrollment(s)"
            )
        )
