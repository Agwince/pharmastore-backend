from django.contrib import admin
from .models import Medicine, Supplier, Order, VendorProfile, PromoBanner, Prescription # ⚠️ ADDED Prescription

# 1. Customize the Medicine Table
class MedicineAdmin(admin.ModelAdmin):
    # ⚠️ UPGRADED: Now shows offers and discounts on the main table
    list_display = ('name', 'category', 'price', 'stock_quantity', 'is_on_offer', 'discount_percentage', 'expiry_date')
    
    # ⚠️ NEW: Allows the boss to change prices and discounts without clicking into the item!
    list_editable = ('price', 'stock_quantity', 'is_on_offer', 'discount_percentage')
    
    search_fields = ('name', 'category')
    
    # ⚠️ UPGRADED: Added a filter to quickly find items on offer
    list_filter = ('category', 'is_on_offer')

# 2. Customize the Supplier Table
class SupplierAdmin(admin.ModelAdmin):
    list_display = ('company_name', 'contact_person', 'phone_number', 'email')
    search_fields = ('company_name', 'contact_person')

# 3. Customize the Order Table
class OrderAdmin(admin.ModelAdmin):
    # ⚠️ UPGRADED: Now shows Dispatch Status and Payment Method at a glance!
    list_display = ('medicine', 'quantity_sold', 'total_price', 'status', 'payment_method', 'date_sold')
    list_filter = ('status', 'payment_method', 'date_sold')
    readonly_fields = ('date_sold',)

# 4. Customize the Vendor Profile Table
class VendorProfileAdmin(admin.ModelAdmin):
    list_display = ('pharmacy_name', 'phone_number', 'national_id', 'ppb_license', 'is_approved')
    search_fields = ('pharmacy_name', 'ppb_license', 'national_id')
    list_filter = ('is_approved', 'created_at')
    list_editable = ('is_approved',)

# ==========================================
# 5. Customize the Promo Banner Table
# ==========================================
class PromoBannerAdmin(admin.ModelAdmin):
    # Shows the banner title, badge, and whether it is showing on the app
    list_display = ('title', 'badge', 'is_active')
    
    # Allows the boss to turn banners on/off with one click!
    list_editable = ('is_active',)

# ==========================================
# 6. ⚠️ NEW: Customize the Prescription Table
# ==========================================
class PrescriptionAdmin(admin.ModelAdmin):
    list_display = ('patient_name', 'phone_number', 'status', 'uploaded_at')
    list_filter = ('status', 'uploaded_at')
    # Allows admin to quickly approve/reject from the main table
    list_editable = ('status',)


# 7. Register them all together
admin.site.register(Medicine, MedicineAdmin)
admin.site.register(Supplier, SupplierAdmin)
admin.site.register(Order, OrderAdmin)
admin.site.register(VendorProfile, VendorProfileAdmin)
admin.site.register(PromoBanner, PromoBannerAdmin)
admin.site.register(Prescription, PrescriptionAdmin) # ⚠️ REGISTERED PRESCRIPTIONS