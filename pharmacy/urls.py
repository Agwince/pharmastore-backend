from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    MedicineViewSet, 
    SupplierViewSet, 
    OrderViewSet, 
    VendorRegistrationViewSet, 
    CheckoutViewSet,
    PromoBannerViewSet,
    upload_prescription # ⚠️ NEW: Imported the Prescription Upload View
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
    # ⚠️ NEW: The endpoint where Flutter sends photos!
    # ==========================================
    path('prescriptions/upload', upload_prescription, name='upload_prescription'),
]