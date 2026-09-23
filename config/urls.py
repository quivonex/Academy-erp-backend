"""
URL configuration for config project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import include, path

from drf_spectacular.views import (
    SpectacularAPIView,
    SpectacularSwaggerView,
)
from courses.urls import (
    category_urlpatterns,
    chapter_urlpatterns,
    enrollment_urlpatterns,
    lesson_urlpatterns,
    subject_urlpatterns,
    public_course_urlpatterns,
    
)

from teachers.urls import staff_urlpatterns

urlpatterns = [
    path("admin/", admin.site.urls,),

    path("api/schema/", SpectacularAPIView.as_view(), name="schema",),
    path("api/docs/", SpectacularSwaggerView.as_view(url_name="schema"), name="swagger-ui"),
    
    path("api/v1/auth/", include("accounts.urls"),),
    path("api/v1/firms/",include("firms.urls"),),
    path("api/v1/students/", include("students.urls"),),
    path("api/v1/teachers/", include("teachers.urls"),),
    path("api/v1/staff/", include(staff_urlpatterns),),
    path("api/v1/course-categories/", include(category_urlpatterns),),

    path("api/v1/courses/", include("courses.urls"),),

    path("api/v1/subjects/", include(subject_urlpatterns),),

    path("api/v1/chapters/", include(chapter_urlpatterns),),

    path("api/v1/lessons/", include(lesson_urlpatterns),),
    
    path("api/v1/enrollments/", include(enrollment_urlpatterns),),
    
    path("api/v1/student/", include("students.portal_urls"),),
    
    path("api/v1/live-classes/", include("classes.urls"),),
    
    path("api/v1/public/courses/", include(public_course_urlpatterns),),

    path("api/v1/materials/", include("materials.urls"),),
    
    path("api/v1/student/", include("progress.urls"),),
]

from django.conf import settings
from django.conf.urls.static import static

if settings.DEBUG:
    urlpatterns += static(
        settings.MEDIA_URL,
        document_root=settings.MEDIA_ROOT,
    )
