from django.db import models, transaction

from accounts.models import User
from .models import Firm


@transaction.atomic
def create_firm(validated_data):
    return Firm.objects.create(**validated_data)


@transaction.atomic
def update_firm(firm, validated_data):
    for field, value in validated_data.items():
        setattr(firm, field, value)

    firm.save()

    return firm


@transaction.atomic
def deactivate_firm(firm):
    firm.is_active = False
    firm.status = Firm.Status.INACTIVE

    firm.save(
        update_fields=[
            "is_active",
            "status",
            "updated_at",
        ]
    )

    User.objects.filter(
        firm=firm,
        is_active=True,
    ).update(
        is_active=False,
    )

    User.objects.filter(
        firm=firm,
    ).update(
        auth_version=models.F("auth_version") + 1,
    )

    return firm


@transaction.atomic
def activate_firm(firm):
    firm.is_active = True
    firm.status = Firm.Status.ACTIVE

    firm.save(
        update_fields=[
            "is_active",
            "status",
            "updated_at",
        ]
    )


    return firm