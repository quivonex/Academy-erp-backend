from django.db import transaction

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