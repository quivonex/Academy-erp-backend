from rest_framework import serializers

from .models import Staff, Teacher


class TeacherSerializer(serializers.ModelSerializer):
    full_name = serializers.ReadOnlyField()

    firm_uuid = serializers.UUIDField(
        source="firm.uuid",
        read_only=True,
    )

    firm_name = serializers.CharField(
        source="firm.name",
        read_only=True,
    )

    class Meta:
        model = Teacher
        fields = (
            "uuid",
            "firm_uuid",
            "firm_name",
            "employee_id",
            "first_name",
            "last_name",
            "full_name",
            "email",
            "phone",
            "gender",
            "qualification",
            "specialization",
            "experience_years",
            "address",
            "joined_date",
            "is_active",
            "created_at",
            "updated_at",
        )

        read_only_fields = (
            "uuid",
            "firm_uuid",
            "firm_name",
            "full_name",
            "created_at",
            "updated_at",
        )


class TeacherListSerializer(serializers.ModelSerializer):
    full_name = serializers.ReadOnlyField()

    class Meta:
        model = Teacher
        fields = (
            "uuid",
            "employee_id",
            "first_name",
            "last_name",
            "full_name",
            "email",
            "phone",
            "specialization",
            "experience_years",
            "is_active",
            "created_at",
        )


class StaffSerializer(serializers.ModelSerializer):
    full_name = serializers.ReadOnlyField()

    firm_uuid = serializers.UUIDField(
        source="firm.uuid",
        read_only=True,
    )

    firm_name = serializers.CharField(
        source="firm.name",
        read_only=True,
    )

    class Meta:
        model = Staff
        fields = (
            "uuid",
            "firm_uuid",
            "firm_name",
            "employee_id",
            "first_name",
            "last_name",
            "full_name",
            "email",
            "phone",
            "designation",
            "department",
            "address",
            "joined_date",
            "is_active",
            "created_at",
            "updated_at",
        )

        read_only_fields = (
            "uuid",
            "firm_uuid",
            "firm_name",
            "full_name",
            "created_at",
            "updated_at",
        )


class StaffListSerializer(serializers.ModelSerializer):
    full_name = serializers.ReadOnlyField()

    class Meta:
        model = Staff
        fields = (
            "uuid",
            "employee_id",
            "first_name",
            "last_name",
            "full_name",
            "email",
            "phone",
            "designation",
            "department",
            "is_active",
            "created_at",
        )
        
        