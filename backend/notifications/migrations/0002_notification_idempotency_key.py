from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("notifications", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="notification",
            name="idempotency_key",
            field=models.CharField(
                blank=True,
                db_index=True,
                default="",
                max_length=64,
            ),
        ),
        migrations.AddConstraint(
            model_name="notification",
            constraint=models.UniqueConstraint(
                condition=models.Q(
                    ("idempotency_key__gt", "")
                ),
                fields=("recipient", "idempotency_key"),
                name="unique_notification_idempotency",
            ),
        ),
    ]
