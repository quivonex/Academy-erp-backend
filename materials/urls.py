from django.urls import path

from .views import (
    LearningMaterialDetailView,
    LearningMaterialListCreateView,
)


urlpatterns = [
    path(
        "",
        LearningMaterialListCreateView.as_view(),
        name="material-list-create",
    ),

    path(
        "<uuid:material_uuid>/",
        LearningMaterialDetailView.as_view(),
        name="material-detail",
    ),
]

