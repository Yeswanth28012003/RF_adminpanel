import secrets
import string
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.http import JsonResponse
from rest_framework import status, viewsets
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAdminUser
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from drf_spectacular.utils import extend_schema, OpenApiResponse
from .models import User
from .serializers import UserSerializer, CreateUserSerializer, LoginSerializer


# ============ API Views ============

@extend_schema(
    tags=['Auth'],
    summary='Login',
    description='Authenticate with username/password and receive JWT tokens',
    request=LoginSerializer,
    responses={200: OpenApiResponse(description='JWT tokens and user info')},
)
@api_view(['POST'])
@permission_classes([AllowAny])
def api_login_view(request):
    serializer = LoginSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    user = serializer.validated_data['user']
    
    refresh = RefreshToken.for_user(user)
    
    return Response({
        'access': str(refresh.access_token),
        'refresh': str(refresh),
        'user': UserSerializer(user).data
    })


@extend_schema(
    tags=['Auth'],
    summary='Register',
    description='Create a new user account and receive JWT tokens',
    request=CreateUserSerializer,
    responses={201: OpenApiResponse(description='JWT tokens and user info')},
)
@api_view(['POST'])
@permission_classes([AllowAny])
def api_register_view(request):
    serializer = CreateUserSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    user = serializer.save()
    
    refresh = RefreshToken.for_user(user)
    
    return Response({
        'access': str(refresh.access_token),
        'refresh': str(refresh),
        'user': UserSerializer(user).data
    }, status=status.HTTP_201_CREATED)


class UserViewSet(viewsets.ModelViewSet):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [IsAdminUser]

    def perform_create(self, serializer):
        user = serializer.save()
        password = self.request.data.get('password')
        if password:
            user.set_password(password)
            user.save()


# ============ Frontend Views ============

def frontend_login_view(request):
    if request.user.is_authenticated:
        return redirect('dashboard')
    
    if request.method == 'POST':
        username = request.POST.get('username')
        password = request.POST.get('password')
        user = authenticate(request, username=username, password=password)
        if user is not None:
            login(request, user)
            return redirect('dashboard')
        else:
            return render(request, 'users/login.html', {'error': 'Invalid username or password'})
    
    return render(request, 'users/login.html')


@login_required
def dashboard_view(request):
    users = User.objects.all().order_by('-date_joined')
    return render(request, 'users/dashboard.html', {'users': users})


@login_required
def add_user_view(request):
    is_ajax = request.headers.get('X-Requested-With') == 'XMLHttpRequest'

    if request.method == 'POST':
        username = request.POST.get('username')
        password = request.POST.get('password')
        is_active = request.POST.get('is_active') == 'on'

        if User.objects.filter(username=username).exists():
            if is_ajax:
                return JsonResponse({'error': 'Username already exists'}, status=400)
            return render(request, 'users/user_form.html', {
                'error': 'Username already exists',
                'title': 'Add User',
                'button_text': 'Add User',
                'user_data': request.POST
            })

        user = User.objects.create_user(
            username=username,
            password=password
        )
        user.is_active = is_active
        user.password_plain = password
        user.save()

        if is_ajax:
            return JsonResponse({
                'success': True,
                'id': user.id,
                'username': username,
                'password': password,
                'is_active': user.is_active,
                'date_joined': user.date_joined.strftime('%b %d, %Y'),
            })

        return render(request, 'users/user_created.html', {
            'username': username,
            'password': password
        })

    return render(request, 'users/user_form.html', {
        'title': 'Add User',
        'button_text': 'Add User',
        'edit': False
    })


@login_required
def edit_user_view(request, user_id):
    user_obj = get_object_or_404(User, id=user_id)
    
    if request.method == 'POST':
        user_obj.username = request.POST.get('username')
        user_obj.is_active = request.POST.get('is_active') == 'on'
        
        password = request.POST.get('password')
        if password:
            user_obj.set_password(password)
            user_obj.password_plain = password
        elif not user_obj.password_plain:
            user_obj.password_plain = ''
        
        user_obj.save()
        messages.success(request, f'User {user_obj.username} updated successfully')
        return redirect('dashboard')
    
    return render(request, 'users/user_form.html', {
        'title': f'Edit User: {user_obj.username}',
        'button_text': 'Update User',
        'user_data': user_obj,
        'edit': True
    })


@login_required
def delete_user_view(request, user_id):
    user_obj = get_object_or_404(User, id=user_id)
    username = user_obj.username
    user_obj.delete()
    messages.success(request, f'User {username} deleted successfully')
    return redirect('dashboard')


def frontend_logout_view(request):
    logout(request)
    return redirect('login')


@login_required
def reset_password_view(request, user_id):
    user_obj = get_object_or_404(User, id=user_id)
    alphabet = string.ascii_letters + string.digits + "!@#$%&*"
    new_password = ''.join(secrets.choice(alphabet) for _ in range(12))
    user_obj.set_password(new_password)
    user_obj.password_plain = new_password
    user_obj.save()
    messages.success(request, f'Password reset for {user_obj.username}: {new_password}')
    return redirect('dashboard')
