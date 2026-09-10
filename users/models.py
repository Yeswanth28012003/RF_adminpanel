from django.db import models
from django.contrib.auth.models import AbstractUser


class User(AbstractUser):
    password_plain = models.CharField(max_length=128, blank=True, editable=False)

    class Meta:
        verbose_name = 'User'
        verbose_name_plural = 'Users'

    def __str__(self):
        return self.username