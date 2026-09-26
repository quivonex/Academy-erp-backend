from django.db.models import Q
from django.shortcuts import get_object_or_404
from django.utils import timezone

from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.views import APIView

from common.pagination import StandardResultsSetPagination
from common.permissions import IsFirmAdminOrStaff
from common.responses import error_response, success_response
from courses.models import Course

from .models import HomeBanner
from .serializers import (
    BannerSerializer,
    PublicHomeBannerQuerySerializer,
    PublicHomeBannerSerializer,
)


class BannerListCreateView(APIView):
    permission_classes = [IsAuthenticated, IsFirmAdminOrStaff]

    def get(self, request):
        banners = (
            HomeBanner.objects.filter(firm=request.user.firm)
            .select_related("course")
            .order_by("display_order", "-created_at")
        )

        paginator = StandardResultsSetPagination()
        page = paginator.paginate_queryset(banners, request)

        serializer = BannerSerializer(
            page,
            many=True,
            context={"request": request},
        )

        return paginator.get_paginated_response(serializer.data)

    def post(self, request):
        serializer = BannerSerializer(
            data=request.data,
            context={"request": request},
        )

        if not serializer.is_valid():
            return error_response(
                message="Banner creation failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        course_uuid = serializer.validated_data.pop("course_uuid", None)
        course = None

        if course_uuid:
            course = get_object_or_404(
                Course,
                uuid=course_uuid,
                firm=request.user.firm,
            )

        banner = HomeBanner.objects.create(
            firm=request.user.firm,
            course=course,
            **serializer.validated_data,
        )

        return success_response(
            message="Banner created successfully",
            data=BannerSerializer(
                banner,
                context={"request": request},
            ).data,
            status_code=status.HTTP_201_CREATED,
        )


class BannerDetailView(APIView):
    permission_classes = [IsAuthenticated, IsFirmAdminOrStaff]

    def get_object(self, request, banner_uuid):
        return get_object_or_404(
            HomeBanner.objects.select_related("course"),
            uuid=banner_uuid,
            firm=request.user.firm,
        )

    def get(self, request, banner_uuid):
        banner = self.get_object(request, banner_uuid)

        return success_response(
            message="Banner retrieved successfully",
            data=BannerSerializer(
                banner,
                context={"request": request},
            ).data,
        )

    def patch(self, request, banner_uuid):
        banner = self.get_object(request, banner_uuid)

        serializer = BannerSerializer(
            banner,
            data=request.data,
            partial=True,
            context={"request": request},
        )

        if not serializer.is_valid():
            return error_response(
                message="Banner update failed",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        validated_data = serializer.validated_data

        if "course_uuid" in validated_data:
            course_uuid = validated_data.pop("course_uuid")

            if course_uuid:
                banner.course = get_object_or_404(
                    Course,
                    uuid=course_uuid,
                    firm=request.user.firm,
                )
            else:
                banner.course = None

        for field, value in validated_data.items():
            setattr(banner, field, value)

        banner.save()

        return success_response(
            message="Banner updated successfully",
            data=BannerSerializer(
                banner,
                context={"request": request},
            ).data,
        )
        
    def delete(self, request, banner_uuid):
        banner = self.get_object(request, banner_uuid)

        if banner.image:
            banner.image.delete(save=False)

        banner.delete()

        return success_response(
            message="Banner deleted successfully",
            data={},
        )


class PublicHomeBannerListView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        query_serializer = PublicHomeBannerQuerySerializer(
            data=request.query_params
        )

        if not query_serializer.is_valid():
            return error_response(
                message="Invalid query parameters",
                errors=query_serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        now = timezone.now()

        banners = (
            HomeBanner.objects.filter(
                is_active=True,
                firm__is_active=True,
            )
            .filter(
                Q(starts_at__isnull=True) | Q(starts_at__lte=now)
            )
            .filter(
                Q(ends_at__isnull=True) | Q(ends_at__gte=now)
            )
            .filter(
                Q(course__isnull=True)
                | Q(
                    course__is_active=True,
                    course__is_published=True,
                    course__is_purchasable_online=True,
                )
            )
            .select_related("firm", "course")
            .order_by("display_order", "-created_at")
        )

        firm_uuid = query_serializer.validated_data.get("firm_uuid")

        if firm_uuid:
            banners = banners.filter(firm__uuid=firm_uuid)

        return success_response(
            message="Home banners retrieved successfully",
            data=PublicHomeBannerSerializer(
                banners,
                many=True,
                context={"request": request},
            ).data,
        )
        
        
