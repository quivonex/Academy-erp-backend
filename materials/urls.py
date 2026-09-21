from django.urls import path

from .views import LearningMaterialListCreateView


urlpatterns = [
    path("", LearningMaterialListCreateView.as_view(), name="material-list-create",),
]

