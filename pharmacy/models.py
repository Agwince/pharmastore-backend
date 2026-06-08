from django.db import models
from django.contrib.auth.models import User
from django.core.mail import send_mail
from django.conf import settings

class Medicine(models.Model):
    # ==========================================
    # ⚠️ NEW: Category Choices Dropdown
    # ==========================================
    CATEGORY_CHOICES = [
        ('First Aid', 'First Aid'),
        ('Medicines', 'Medicines'),
        ('Injections', 'Injections'),
        ('Baby Care', 'Baby Care'),
        ('Pain Relief', 'Pain Relief'),
        ('Vitamins', 'Vitamins'),
        ('Supplements', 'Supplements'),
        ('Personal Care', 'Personal Care'),
        ('Devices', 'Devices'),
        ('General', 'General'),
    ]

    name = models.CharField(max_length=200)
    category = models.CharField(max_length=100, choices=CATEGORY_CHOICES, default="General")
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
    
    # ==========================================
    # ⚠️ NEW: Email Field for Auto-Notifications
    # ==========================================
    email = models.EmailField(max_length=255, null=True, blank=True) 
    
    phone_number = models.CharField(max_length=20)
    national_id = models.CharField(max_length=50)
    ppb_license = models.CharField(max_length=100)
    county_license = models.CharField(max_length=100)
    
    # ==========================================
    # ⚠️ NEW: POS Access Toggle
    # ==========================================
    has_pos_access = models.BooleanField(default=False, help_text="Can this vendor use the POS system?")
    
    # ==========================================
    # ⚠️ NEW: OTP Verification Fields
    # ==========================================
    is_email_verified = models.BooleanField(default=False)
    otp_code = models.CharField(max_length=6, blank=True, null=True)

    is_approved = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def save(self, *args, **kwargs):
        # 1. Check if this is an existing profile being updated (not a brand new one)
        if self.pk:
            old_profile = VendorProfile.objects.get(pk=self.pk)
            
            # 2. If they were NOT approved before, but they ARE approved now, send the email!
            if not old_profile.is_approved and self.is_approved:
                
                # ⚠️ TEMPORARILY DISABLED TO PREVENT CRASH DURING DEMO
                print(f"Vendor {self.pharmacy_name} approved! (Email skipped)")
                
                # if self.email:
                #     send_mail(
                #         subject='Your PharmaStore Account is Verified!',
                #         message=f'Hello {self.pharmacy_name},\n\nGreat news! Your PPB and County licenses have been verified. You can now log in to the PharmaStore Vendor Portal.\n\nPOS Access Granted: {"Yes" if self.has_pos_access else "No"}\n\nWelcome to the team!',
                #         from_email=settings.EMAIL_HOST_USER,
                #         recipient_list=[self.email],
                #         fail_silently=False,
                #     )
        
        # 3. Save the actual record to the database
        super().save(*args, **kwargs)

    def __str__(self):
        status = "✅ Approved" if self.is_approved else "⏳ Pending"
        pos = "💻 POS Enabled" if self.has_pos_access else "🚫 No POS"
        return f"{self.pharmacy_name} - {status} | {pos}"


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