from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'users', views.UserViewSet)

urlpatterns = [
    path('auth/login/', views.api_login_view, name='api_login'),
    path('auth/register/', views.api_register_view, name='api_register'),
    path('', include(router.urls)),
]
