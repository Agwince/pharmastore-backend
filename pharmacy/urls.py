from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    MedicineViewSet, 
    SupplierViewSet, 
    OrderViewSet, 
    VendorRegistrationViewSet, 
    CheckoutViewSet,
    PromoBannerViewSet,
    upload_prescription,
    vendor_login,  # ⚠️ NEW: Imported the login view
    verify_otp     # ⚠️ NEW: Imported the OTP verification view
)

router = DefaultRouter(trailing_slash=False)
router.register(r'medicines', MedicineViewSet)
router.register(r'suppliers', SupplierViewSet)
router.register(r'orders', OrderViewSet)
router.register(r'register', VendorRegistrationViewSet, basename='register')
router.register(r'checkout', CheckoutViewSet, basename='checkout')
router.register(r'banners', PromoBannerViewSet, basename='banners') 

urlpatterns = [
    path('', include(router.urls)),
    
    # ==========================================
    # Prescription Upload Endpoint
    # ==========================================
    path('prescriptions/upload', upload_prescription, name='upload_prescription'),
    
    # ==========================================
    # ⚠️ NEW: Authentication & OTP Endpoints
    # ==========================================
    path('login/', vendor_login, name='vendor-login'),
    path('verify-otp/', verify_otp, name='verify-otp'),
]