from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("courses", "0012_course_offer_price"),
    ]

    operations = [
        migrations.AddField(
            model_name="course",
            name="thumbnail_key",
            field=models.CharField(blank=True, max_length=1000),
        ),
    ]
