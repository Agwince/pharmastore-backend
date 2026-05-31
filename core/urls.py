from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
# NEW: Imports Django's built-in Login system!
from rest_framework.authtoken.views import obtain_auth_token 

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('pharmacy.urls')), 
    
    # NEW: The official Login Door!
    path('api/login/', obtain_auth_token, name='api_token_auth'), 
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)