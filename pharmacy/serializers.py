from rest_framework import serializers
from .models import Medicine, Supplier, Order, VendorProfile, PromoBanner, Prescription

class MedicineSerializer(serializers.ModelSerializer):
    class Meta:
        model = Medicine
        # ⚠️ MAGIC: Grabs every column, including 'is_on_offer' and 'discount_percentage'
        fields = '__all__'  

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
        # ⚠️ MAGIC: Automatically includes the new 'email' and 'has_pos_access' fields!
        fields = '__all__'

# ==========================================
# Serializer for the Promotional Banners
# ==========================================
class PromoBannerSerializer(serializers.ModelSerializer):
    class Meta:
        model = PromoBanner
        fields = '__all__'

# ==========================================
# Serializer for Prescription Uploads
# ==========================================
class PrescriptionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Prescription
        fields = '__all__'