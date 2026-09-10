from django.urls import path
from . import views

urlpatterns = [
    path('', views.frontend_login_view, name='login'),
    path('dashboard/', views.dashboard_view, name='dashboard'),
    path('add-user/', views.add_user_view, name='add_user'),
    path('edit-user/<int:user_id>/', views.edit_user_view, name='edit_user'),
    path('delete-user/<int:user_id>/', views.delete_user_view, name='delete_user'),
    path('reset-password/<int:user_id>/', views.reset_password_view, name='reset_password'),
    path('logout/', views.frontend_logout_view, name='logout'),
]
