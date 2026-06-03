from django.contrib.auth.models import User
from django.contrib.auth import authenticate # ⚠️ NEW: Required for custom login
from rest_framework import viewsets, status
from rest_framework.response import Response
from rest_framework.decorators import api_view, parser_classes
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.authtoken.models import Token # ⚠️ NEW: Required for custom login

from .models import Medicine, Supplier, Order, VendorProfile, PromoBanner, Prescription
from .serializers import MedicineSerializer, SupplierSerializer, OrderSerializer, PromoBannerSerializer, PrescriptionSerializer

class MedicineViewSet(viewsets.ModelViewSet):
    queryset = Medicine.objects.all()
    serializer_class = MedicineSerializer

class SupplierViewSet(viewsets.ModelViewSet):
    queryset = Supplier.objects.all()
    serializer_class = SupplierSerializer

class OrderViewSet(viewsets.ModelViewSet):
    queryset = Order.objects.all()
    serializer_class = OrderSerializer

# ==========================================
# The Banner Endpoint for Flutter
# ==========================================
class PromoBannerViewSet(viewsets.ModelViewSet):
    # This ensures Flutter only downloads banners marked as "Active" in the admin panel
    queryset = PromoBanner.objects.filter(is_active=True)
    serializer_class = PromoBannerSerializer

class VendorRegistrationViewSet(viewsets.ViewSet):
    def create(self, request):
        data = request.data
        try:
            user = User.objects.create_user(username=data['phone_number'], password=data['password'])
            profile = VendorProfile.objects.create(
                user=user, pharmacy_name=data['pharmacy_name'], phone_number=data['phone_number'],
                national_id=data['national_id'], ppb_license=data['ppb_license'], county_license=data['county_license']
            )
            return Response({'message': 'Registration successful. Application is pending approval.'}, status=status.HTTP_201_CREATED)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

# ==========================================
# UPGRADED: The Checkout Engine (With Payment Tracking)
# ==========================================
class CheckoutViewSet(viewsets.ViewSet):
    def create(self, request):
        cart_items = request.data.get('items', [])
        payment_method = request.data.get('payment_method', 'Cash') # Catches the payment method from Flutter!
        
        # If it's Cash or M-Pesa, it's paid immediately. Otherwise, it's pending.
        payment_status = 'Paid' if payment_method in ['Cash', 'M-Pesa'] else 'Pending'

        try:
            for item in cart_items:
                med = Medicine.objects.get(id=item['id'])
                
                # 1. Deduct the stock silently
                med.stock_quantity -= item['cart_quantity']
                med.save()
                
                # 2. Create the official order with the payment data
                Order.objects.create(
                    medicine=med,
                    quantity_sold=item['cart_quantity'],
                    total_price=float(med.price) * item['cart_quantity'],
                    payment_method=payment_method,
                    payment_status=payment_status
                )
            return Response({'message': 'Checkout complete! Orders processed.'}, status=status.HTTP_201_CREATED)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

# ==========================================
# ⚠️ NEW: Secure Prescription Upload Endpoint
# ==========================================
@api_view(['POST'])
@parser_classes([MultiPartParser, FormParser]) # This tells Django to expect a FILE upload!
def upload_prescription(request):
    serializer = PrescriptionSerializer(data=request.data)
    if serializer.is_valid():
        serializer.save()
        return Response({"message": "Prescription successfully sent to pharmacy!"}, status=201)
    else:
        return Response(serializer.errors, status=400)


# ==========================================
# ⚠️ UPGRADED: Vendor Login (Handles POS check dynamically)
# ==========================================
@api_view(['POST'])
def vendor_login(request):
    username = request.data.get('username')
    password = request.data.get('password')
    
    # 1. Authenticate checks if the password is correct
    user = authenticate(username=username, password=password)
    
    if user is not None:
        try:
            vendor_profile = user.vendor_profile
        except Exception:
            return Response({'error': 'This user does not have a vendor profile.'}, status=400)
            
        # 2. ONLY block them if they are NOT approved
        if not vendor_profile.is_approved:
            return Response({'error': 'Account not verified or pending approval.'}, status=403)
            
        # 3. Create or get their login token
        token, created = Token.objects.get_or_create(user=user)
        
        # 4. Let them in! Pass the pos_access flag to Flutter so the phone knows what to hide.
        return Response({
            'token': token.key,
            'pharmacy_name': vendor_profile.pharmacy_name,
            'has_pos_access': vendor_profile.has_pos_access
        })
    else:
        return Response({'error': 'Invalid credentials'}, status=400)