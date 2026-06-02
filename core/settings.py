"""
Django settings for core project.
"""

from pathlib import Path
import os
import dj_database_url
from dotenv import load_dotenv

# 1. Define BASE_DIR (Where the root of the project is)
BASE_DIR = Path(__file__).resolve().parent.parent

# 2. Tell Django exactly where to find the .env file
ENV_PATH = BASE_DIR / '.env'
load_dotenv(ENV_PATH)

# 3. Grab the URL from the .env file
DB_URL = os.environ.get('DATABASE_URL')

# Debug prints to help us see exactly what Windows is doing
print(f"--- DEBUG: Looking for .env at: {ENV_PATH} ---")
print(f"--- DEBUG: DATABASE_URL is: {'FOUND' if DB_URL else 'MISSING!'} ---")

# Quick-start development settings - unsuitable for production
SECRET_KEY = 'django-insecure-*nz1&$orlh$fk_pte!k@x4k$cpf(+1ba+$1-it+o!w!12auo_*'

DEBUG = True

ALLOWED_HOSTS = ['*']

# Application definition
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',          # For building the API
    'rest_framework.authtoken', # <--- NEW: Activates the secure Token Login system!
    'corsheaders',             # Allows front-end apps to connect to your API
    'pharmacy',                # Your custom app
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware', # ⚠️ ADDED: Whitenoise for cloud static files!
    'corsheaders.middleware.CorsMiddleware',  # Must be high up in this list
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'core.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'core.wsgi.application'

# Database Configuration
if not DB_URL:
    raise ValueError(
        "\n\nCRITICAL ERROR: Django cannot find the DATABASE_URL in your .env file! "
        "Your file might be accidentally named '.env.txt' by Windows, or it is empty.\n\n"
    )

DATABASES = {
    'default': dj_database_url.config(
        default=DB_URL,
        conn_max_age=600,
        conn_health_checks=True,
    )
}

# Password validation
AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

# Internationalization
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

# Static files (CSS, JavaScript, Images)
STATIC_URL = 'static/'
# ⚠️ ADDED: Tell the cloud server where to collect static files (required for Render)
STATIC_ROOT = BASE_DIR / 'staticfiles'
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

# Default primary key field type
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'


# --- API CONFIGURATION ---
# This explicitly allows your deployed frontend to communicate with your backend
CORS_ALLOWED_ORIGINS = [
    "https://pharmastore-web.onrender.com",
    "http://localhost:3000",
    "http://127.0.0.1:8000",
]

# Media files (Images you upload)
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

# ==========================================
# ⚠️ NEW: EMAIL CONFIGURATION
# ==========================================
EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = 'smtp.gmail.com'
EMAIL_PORT = 587
EMAIL_USE_TLS = True
# TODO: Replace these with your actual details before pushing!
EMAIL_HOST_USER = 'your_pharmastore_email@gmail.com' 
EMAIL_HOST_PASSWORD = 'your_app_password'