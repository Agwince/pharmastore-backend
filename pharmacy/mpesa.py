import requests
import base64
from datetime import datetime
from django.conf import settings
from django.http import JsonResponse

# Safaricom Sandbox Configurations
CONSUMER_KEY = "DEG0u7XHcplFV58Du7C0mrC44TFVtAh3G30qlY6kJvfPwfZp"
CONSUMER_SECRET = "qEPAfP5eKD09axZBh7LzLAFotpnjGy6vLQkwTT3Gk8Mco4tdqjZpcDq43QWjujNK"
BUSINESS_SHORT_CODE = "174379"  # Default Safaricom Sandbox Shortcode
PASSKEY = "bfb272f65253e7428b8d473e34360430784759675007558729d259c3c0a8d8ae"  # Default Sandbox Passkey
CALLBACK_URL = "https://your-domain.onrender.com/api/mpesa/callback/" # We will update this later

def get_access_token():
    """Generates the dynamic OAuth access token from Safaricom"""
    url = "https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials"
    try:
        response = requests.get(url, auth=(CONSUMER_KEY, CONSUMER_SECRET))
        if response.status_code == 200:
            return response.json()['access_token']
    except Exception as e:
        print(f"Token Generation Error: {e}")
    return None

def initiate_stk_push(phone_number, amount, order_id):
    """Triggers the STK Push Menu prompt on the user's phone"""
    access_token = get_access_token()
    if not access_token:
        return {"status": "error", "message": "Failed to authenticate with Safaricom"}

    url = "https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest"
    headers = {"Authorization": f"Bearer {access_token}", "Content-Type": "application/json"}
    
    # Format timestamp: YYYYMMDDHHmmss
    timestamp = datetime.now().strftime('%Y%m%d%H%m%S')
    
    # Generate Password: Base64(Shortcode + Passkey + Timestamp)
    data_to_encode = BUSINESS_SHORT_CODE + PASSKEY + timestamp
    password = base64.b64encode(data_to_encode.encode()).decode('utf-8')
    
    # Format Kenyan phone numbers safely (2547xxxxxxxx)
    if phone_number.startswith('0'):
        phone_number = '254' + phone_number[1:]
    elif phone_number.startswith('+254'):
        phone_number = phone_number[1:]

    payload = {
        "BusinessShortCode": BUSINESS_SHORT_CODE,
        "Password": password,
        "Timestamp": timestamp,
        "TransactionType": "CustomerPayBillOnline",
        "Amount": int(amount),
        "PartyA": phone_number,
        "PartyB": BUSINESS_SHORT_CODE,
        "PhoneNumber": phone_number,
        "CallBackURL": CALLBACK_URL,
        "AccountReference": f"Order-{order_id}",
        "TransactionDesc": "Pharmacy Order Payment"
    }

    try:
        response = requests.post(url, json=payload, headers=headers)
        return response.json()
    except Exception as e:
        return {"status": "error", "message": str(e)}