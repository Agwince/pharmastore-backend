from rest_framework import serializers
from .models import Medicine, Supplier, Order, VendorProfile, PromoBanner, Prescription # ⚠️ ADDED Prescription

class MedicineSerializer(serializers.ModelSerializer):
    class Meta:
        model = Medicine
        fields = '__all__'  # This tells it to grab every single column

class SupplierSerializer(serializers.ModelSerializer):
    class Meta:
        model = Supplier
        fields = '__all__'

class OrderSerializer(serializers.ModelSerializer):
    class Meta:
        model = Order
        fields = '__all__'

# ==========================================
# Serializer for the Vendor Registrations
# ==========================================
class VendorProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = VendorProfile
        fields = '__all__'

# ==========================================
# Serializer for the Promotional Banners
# ==========================================
class PromoBannerSerializer(serializers.ModelSerializer):
    class Meta:
        model = PromoBanner
        fields = '__all__'

# ==========================================
# ⚠️ NEW: Serializer for Prescription Uploads
# ==========================================
class PrescriptionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Prescription
        fields = '__all__'