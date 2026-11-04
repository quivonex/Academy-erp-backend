from django.urls import path

from .views import (
    LiveClassCancelView,
    LiveClassCompleteView,
    LiveClassListCreateView,
    LiveClassStartView,
    LiveClassDetailView,
)


urlpatterns = [
    path("",LiveClassListCreateView.as_view(), name="live-class-list-create",),
    path("<uuid:live_class_uuid>/start/", LiveClassStartView.as_view(),name="live-class-start",),

    path("<uuid:live_class_uuid>/complete/", LiveClassCompleteView.as_view(), name="live-class-complete",),

    path("<uuid:live_class_uuid>/cancel/", LiveClassCancelView.as_view(), name="live-class-cancel",),
    
    path("<uuid:live_class_uuid>/", LiveClassDetailView.as_view(),name="live-class-detail",),

]