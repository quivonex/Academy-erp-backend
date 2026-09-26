from urllib.parse import urlparse

from rest_framework import serializers

from .models import HomeBanner


class BannerSerializer(serializers.ModelSerializer):
    course_uuid = serializers.UUIDField(
        write_only=True,
        required=False,
        allow_null=True,
    )
    course_name = serializers.CharField(
        source="course.name",
        read_only=True,
        allow_null=True,
    )
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = HomeBanner
        fields = [
            "uuid",
            "course_uuid",
            "course_name",
            "title",
            "subtitle",
            "image",
            "image_url",
            "action_label",
            "action_url",
            "display_order",
            "starts_at",
            "ends_at",
            "is_active",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "uuid",
            "image_url",
            "course_name",
            "created_at",
            "updated_at",
        ]

    def get_image_url(self, obj):
        request = self.context.get("request")

        if not obj.image:
            return ""

        if request:
            return request.build_absolute_uri(obj.image.url)

        return obj.image.url

    def validate_image(self, image):
        allowed_types = {
            "image/jpeg",
            "image/png",
            "image/webp",
        }

        if image.size > 5 * 1024 * 1024:
            raise serializers.ValidationError(
                "Image size must not exceed 5 MB."
            )

        if image.content_type not in allowed_types:
            raise serializers.ValidationError(
                "Only JPEG, PNG, and WebP images are allowed."
            )

        return image

    def validate_action_url(self, value):
        if not value:
            return value

        parsed_url = urlparse(value)

        if parsed_url.scheme not in {"http", "https"}:
            raise serializers.ValidationError(
                "Action URL must start with http:// or https://."
            )

        return value

    def validate(self, attrs):
        current_course = (
            self.instance.course.uuid
            if self.instance and self.instance.course
            else None
        )
        current_action_url = (
            self.instance.action_url if self.instance else ""
        )

        course_uuid = attrs.get("course_uuid", current_course)
        action_url = attrs.get("action_url", current_action_url)

        current_starts_at = (
            self.instance.starts_at if self.instance else None
        )
        current_ends_at = self.instance.ends_at if self.instance else None

        starts_at = attrs.get("starts_at", current_starts_at)
        ends_at = attrs.get("ends_at", current_ends_at)

        if course_uuid and action_url:
            raise serializers.ValidationError(
                "Select either a course or an external action URL, not both."
            )

        if starts_at and ends_at and ends_at <= starts_at:
            raise serializers.ValidationError(
                "End date/time must be later than start date/time."
            )

        return attrs


class PublicHomeBannerSerializer(serializers.ModelSerializer):
    course_uuid = serializers.UUIDField(
        source="course.uuid",
        read_only=True,
        allow_null=True,
    )
    course_name = serializers.CharField(
        source="course.name",
        read_only=True,
        allow_null=True,
    )
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = HomeBanner
        fields = [
            "uuid",
            "title",
            "subtitle",
            "image_url",
            "action_label",
            "action_url",
            "course_uuid",
            "course_name",
            "display_order",
        ]

    def get_image_url(self, obj):
        request = self.context.get("request")

        if not obj.image:
            return ""

        if request:
            return request.build_absolute_uri(obj.image.url)

        return obj.image.url


class PublicHomeBannerQuerySerializer(serializers.Serializer):
    firm_uuid = serializers.UUIDField(required=False)
    
    
    