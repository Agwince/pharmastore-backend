from django.db import models
from django.contrib.auth.models import User

class Medicine(models.Model):
    name = models.CharField(max_length=200)
    category = models.CharField(max_length=100, default="General")
    image = models.ImageField(upload_to='medicines/images/', null=True, blank=True)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    stock_quantity = models.IntegerField()
    expiry_date = models.DateField()

    # ==========================================
    # ⚠️ NEW: Easy Offer Toggles
    # ==========================================
    is_on_offer = models.BooleanField(default=False)
    discount_percentage = models.IntegerField(default=0, help_text="Enter discount (e.g., 20 for 20%)")

    def __str__(self):
        return self.name

class Supplier(models.Model):
    company_name = models.CharField(max_length=200)
    contact_person = models.CharField(max_length=100)
    phone_number = models.CharField(max_length=20)
    email = models.EmailField()

    def __str__(self):
        return self.company_name

class Order(models.Model):
    STATUS_CHOICES = (
        ('Processed', 'Processed'),
        ('Dispatched', 'Dispatched'),
        ('Delivered', 'Delivered'),
    )
    # Payment Methods
    PAYMENT_CHOICES = (
        ('Cash', 'Cash'),
        ('M-Pesa', 'M-Pesa'),
        ('Credit', 'Credit'),
        ('Pay on Delivery', 'Pay on Delivery'),
    )
    
    medicine = models.ForeignKey(Medicine, on_delete=models.CASCADE)
    quantity_sold = models.IntegerField()
    total_price = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='Processed')
    
    # Tracking the money
    payment_method = models.CharField(max_length=50, choices=PAYMENT_CHOICES, default='Cash')
    payment_status = models.CharField(max_length=20, default='Pending') # Will be 'Paid' or 'Pending'
    
    date_sold = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"[{self.status}] {self.quantity_sold}x {self.medicine.name} ({self.payment_method})"

class VendorProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='vendor_profile')
    pharmacy_name = models.CharField(max_length=200)
    phone_number = models.CharField(max_length=20)
    national_id = models.CharField(max_length=50)
    ppb_license = models.CharField(max_length=100)
    county_license = models.CharField(max_length=100)
    is_approved = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        status = "✅ Approved" if self.is_approved else "⏳ Pending"
        return f"{self.pharmacy_name} - {status}"


# ==========================================
# Dynamic Banners for Flutter
# ==========================================
class PromoBanner(models.Model):
    title = models.CharField(max_length=100, blank=True, null=True)
    subtitle = models.CharField(max_length=100, blank=True, null=True)
    badge = models.CharField(max_length=50, default="PROMO")
    image = models.ImageField(upload_to='banners/', null=True, blank=True)
    is_active = models.BooleanField(default=True)
    
    # Fallback colors if no image is uploaded
    color1 = models.CharField(max_length=10, default="0xFF003876")
    color2 = models.CharField(max_length=10, default="0xFF0056b3")

    def __str__(self):
        return self.title if self.title else "Banner Image"

# ==========================================
# ⚠️ NEW: Prescription Uploads
# ==========================================
class Prescription(models.Model):
    STATUS_CHOICES = (
        ('Pending Verification', 'Pending Verification'),
        ('Approved - Processing', 'Approved - Processing'),
        ('Rejected', 'Rejected'),
    )
    
    patient_name = models.CharField(max_length=200)
    phone_number = models.CharField(max_length=20)
    delivery_address = models.TextField()
    
    # This is where the actual photo of the doctor's note goes
    prescription_image = models.ImageField(upload_to='prescriptions/')
    
    # Admin tracking
    status = models.CharField(max_length=50, choices=STATUS_CHOICES, default='Pending Verification')
    uploaded_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.patient_name} - {self.status}"