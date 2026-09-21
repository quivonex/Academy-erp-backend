from django.urls import path


from .views import (
    FirmActivateView,
    FirmAdminCreateView,
    FirmAdminListView,
    FirmDeactivateView,
    FirmDetailView,
    FirmListCreateView,
)


urlpatterns = [
    
    path("", FirmListCreateView.as_view(), name="firm-list-create",),
    path("<uuid:firm_uuid>/", FirmDetailView.as_view(), name="firm-detail",),
    path("<uuid:firm_uuid>/activate/", FirmActivateView.as_view(), name="firm-activate",),
    path("<uuid:firm_uuid>/deactivate/", FirmDeactivateView.as_view(), name="firm-deactivate",),
    path("<uuid:firm_uuid>/admins/", FirmAdminListView.as_view(), name="firm-admin-list",),
    path("<uuid:firm_uuid>/admins/create/", FirmAdminCreateView.as_view(), name="firm-admin-create",),


]