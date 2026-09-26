from django.urls import path

from .views import BannerDetailView, BannerListCreateView

urlpatterns = [
    path("", BannerListCreateView.as_view(), name="banner-list-create"),
    path("<uuid:banner_uuid>/", BannerDetailView.as_view(), name="banner-detail"),
]


