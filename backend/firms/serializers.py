from rest_framework import serializers

from .models import Firm


class FirmSerializer(serializers.ModelSerializer):

    class Meta:
        model = Firm

        fields = (
            "uuid",
            "name",
            "code",
            "email",
            "phone",
            "address",
            "logo",
            "status",
            "is_active",
            "created_at",
            "updated_at",
        )

        read_only_fields = (
            "uuid",
            "created_at",
            "updated_at",
        )

    def validate_code(self, value):
        return value.strip().upper()


class FirmListSerializer(serializers.ModelSerializer):

    class Meta:
        model = Firm

        fields = (
            "uuid",
            "name",
            "code",
            "email",
            "phone",
            "status",
            "is_active",
            "created_at",
        )
        
        
