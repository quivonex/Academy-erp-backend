from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ("accounts", "0002_user_auth_version_passwordresetotp"),
    ]

    operations = [
        migrations.DeleteModel(name="RolePermission"),
        migrations.DeleteModel(name="UserRole"),
        migrations.DeleteModel(name="Permission"),
        migrations.DeleteModel(name="Role"),
    ]
