import random
from django.contrib.auth.models import User
from django.contrib.auth import authenticate 
from django.core.mail import send_mail
from django.conf import settings
from rest_framework import viewsets, status
from rest_framework.response import Response
from rest_framework.decorators import api_view, parser_classes
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.authtoken.models import Token 

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

class PromoBannerViewSet(viewsets.ModelViewSet):
    queryset = PromoBanner.objects.filter(is_active=True)
    serializer_class = PromoBannerSerializer

# ==========================================
# UPGRADED: Vendor Registration with Auto-OTP
# ==========================================
class VendorRegistrationViewSet(viewsets.ViewSet):
    def create(self, request):
        data = request.data
        try:
            # Create core user
            user = User.objects.create_user(username=data['phone_number'], password=data['password'])
            
            # 1. Generate 6-digit OTP
            otp = str(random.randint(100000, 999999))
            
            # 2. Create Profile and save Email & OTP
            profile = VendorProfile.objects.create(
                user=user, 
                pharmacy_name=data['pharmacy_name'], 
                email=data['email'], # Saving the email!
                phone_number=data['phone_number'],
                national_id=data['national_id'], 
                ppb_license=data['ppb_license'], 
                county_license=data['county_license'],
                otp_code=otp,
                is_email_verified=False
            )
            
            # 3. Print to terminal for easy demo testing
            print(f"\n======================================")
            print(f"🔒 OTP CODE FOR {data['email']}: {otp}")
            print(f"======================================\n")

            # 4. Attempt to send actual email
            try:
                send_mail(
                    subject='Verify your PharmaStore Account',
                    message=f'Hello {data["pharmacy_name"]}!\n\nYour secure verification code is: {otp}\n\nPlease enter this in the app to activate your account.',
                    from_email=settings.EMAIL_HOST_USER,
                    recipient_list=[data['email']],
                    fail_silently=True, # Prevents crash if SMTP is not set up
                )
            except Exception as e:
                print("Email sending skipped/failed:", e)

            return Response({'message': 'Registration successful. OTP sent.'}, status=status.HTTP_201_CREATED)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

class CheckoutViewSet(viewsets.ViewSet):
    def create(self, request):
        cart_items = request.data.get('items', [])
        payment_method = request.data.get('payment_method', 'Cash') 
        
        payment_status = 'Paid' if payment_method in ['Cash', 'M-Pesa'] else 'Pending'

        try:
            for item in cart_items:
                med = Medicine.objects.get(id=item['id'])
                
                med.stock_quantity -= item['cart_quantity']
                med.save()
                
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

@api_view(['POST'])
@parser_classes([MultiPartParser, FormParser])
def upload_prescription(request):
    serializer = PrescriptionSerializer(data=request.data)
    if serializer.is_valid():
        serializer.save()
        return Response({"message": "Prescription successfully sent to pharmacy!"}, status=201)
    else:
        return Response(serializer.errors, status=400)


# ==========================================
# NEW: OTP Verification Endpoint
# ==========================================
@api_view(['POST'])
def verify_otp(request):
    email = request.data.get('email')
    otp = request.data.get('otp')
    
    try:
        profile = VendorProfile.objects.get(email=email, otp_code=otp)
        profile.is_email_verified = True
        profile.otp_code = '' # Clear the code once it is used for security
        profile.save()
        return Response({'message': 'Email verified successfully!'}, status=200)
    except VendorProfile.DoesNotExist:
        return Response({'error': 'Invalid OTP or email address.'}, status=400)


# ==========================================
# UPGRADED: Vendor Login (Dynamic Names & OTP Check)
# ==========================================
@api_view(['POST'])
def vendor_login(request):
    username = request.data.get('username')
    password = request.data.get('password')
    
    user = authenticate(username=username, password=password)
    
    if user is not None:
        try:
            vendor_profile = user.vendor_profile
        except Exception:
            return Response({'error': 'This user does not have a vendor profile.'}, status=400)
            
        # 1. Block if they haven't done OTP verification
        if not getattr(vendor_profile, 'is_email_verified', False):
            return Response({'error': 'Email not verified. Please complete OTP verification.'}, status=403)
            
        # 2. Block if Admin hasn't approved their licenses
        if not vendor_profile.is_approved:
            return Response({'error': 'Account is pending Admin approval.'}, status=403)
            
        token, created = Token.objects.get_or_create(user=user)
        
        # 3. Pass all dynamic data directly back to Flutter!
        return Response({
            'token': token.key,
            'name': vendor_profile.pharmacy_name, # THIS is what updates "Hello, Agwince!"
            'has_pos_access': vendor_profile.has_pos_access,
            'profile_pic': '' # Ready for image paths later
        })
    else:
        return Response({'error': 'Invalid credentials'}, status=400)