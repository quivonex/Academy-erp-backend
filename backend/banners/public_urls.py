from django.urls import path

from .views import PublicHomeBannerListView

urlpatterns = [
    path("", PublicHomeBannerListView.as_view(), name="public-home-banner-list"),
]