from rest_framework import serializers

from .models import ParentGuardian, Student


class ParentGuardianSerializer(serializers.ModelSerializer):

    class Meta:
        model = ParentGuardian
        fields = (
            "uuid",
            "name",
            "relationship",
            "phone",
            "email",
            "address",
            "is_primary",
        )

        read_only_fields = (
            "uuid",
        )


class StudentSerializer(serializers.ModelSerializer):

    guardians = ParentGuardianSerializer(
        many=True,
        required=False,
    )

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
        model = Student

        fields = (
            "uuid",
            "firm_uuid",
            "firm_name",
            "admission_number",
            "first_name",
            "last_name",
            "full_name",
            "email",
            "phone",
            "date_of_birth",
            "gender",
            "address",
            "joined_date",
            "is_active",
            "guardians",
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


class StudentListSerializer(serializers.ModelSerializer):

    full_name = serializers.ReadOnlyField()

    class Meta:
        model = Student

        fields = (
            "uuid",
            "admission_number",
            "first_name",
            "last_name",
            "full_name",
            "email",
            "phone",
            "gender",
            "is_active",
            "created_at",
        )
        
        
class StudentEnableLoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(
        write_only=True,
        min_length=8,
    )
    confirm_password = serializers.CharField(
        write_only=True,
        min_length=8,
    )

    def validate(self, attrs):
        if attrs["password"] != attrs["confirm_password"]:
            raise serializers.ValidationError({
                "confirm_password": [
                    "Passwords do not match."
                ]
            })

        return attrs
    
    
