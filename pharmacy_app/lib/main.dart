import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; 
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shimmer/shimmer.dart'; 
import 'package:image_picker/image_picker.dart'; 
import 'package:url_launcher/url_launcher.dart'; 
import 'package:geolocator/geolocator.dart'; 
import 'package:geocoding/geocoding.dart';   

void main() {
  runApp(const PharmacyApp());
}

class PharmacyApp extends StatelessWidget {
  const PharmacyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PharmaStore',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2C8C7C),
          primary: const Color(0xFF2C8C7C), // Dark Teal
          secondary: const Color(0xFFE54A4A), // Red for accents
          tertiary: const Color(0xFF1E2826), // Dark charcoal for nav
          surface: const Color(0xFFE8F4F1), // Soft mint background
        ),
        scaffoldBackgroundColor: const Color(0xFFE8F4F1),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFE8F4F1),
          foregroundColor: Color(0xFF1E2826),
          elevation: 0,
          scrolledUnderElevation: 0, 
        ),
      ),
      home: const StorefrontScreen(), 
    );
  }
}

class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  const ResponsiveWrapper({super.key, required this.child});
  @override Widget build(BuildContext context) { return SizedBox(width: double.infinity, child: child); }
}

// ==========================================
// 1. THE MAIN APPLICATION
// ==========================================
class StorefrontScreen extends StatefulWidget {
  const StorefrontScreen({super.key});
  @override State<StorefrontScreen> createState() => _StorefrontScreenState();
}

class _StorefrontScreenState extends State<StorefrontScreen> {
  List<dynamic> medicines = [];
  List<dynamic> filteredMedicines = []; 
  List<dynamic> orders = []; 
  List<Map<String, dynamic>> cart = []; 
  List<Map<String, dynamic>> posCart = []; 

  final List<Map<String, dynamic>> partnerPharmacies = [
    {'name': 'Health-plus pharmacy', 'isOpen': true, 'rating': 4.8, 'distance': '1.2 km', 'image': 'https://images.unsplash.com/photo-1586281380349-632531db7ed4?w=500'},
    {'name': 'CareRX Pharmacy', 'isOpen': false, 'rating': 4.5, 'distance': '3.0 km', 'image': 'https://images.unsplash.com/photo-1576602976047-174e57a47881?w=500'},
    {'name': 'City Health', 'isOpen': true, 'rating': 4.9, 'distance': '5.5 km', 'image': 'https://images.unsplash.com/photo-1631549916768-4119b2e5f926?w=500'},
  ];

  // Dynamic user data variables
  String userName = '';
  String userProfilePic = '';

  List<dynamic> promoBanners = [
    {
      'title': 'Fast Drone\nMedicine Delivery',
      'subtitle': 'Safe and contactless',
      'badge': 'NEW',
      'image': 'https://images.unsplash.com/photo-1579684385127-1ef15d508118?auto=format&fit=crop&w=800&q=80',
      'color1': 0xFF2C8C7C, 'color2': 0xFF1E2826
    },
    {
      'title': '20% Off All\nVitamins Today',
      'subtitle': 'Boost your immunity',
      'badge': 'PROMO',
      'color1': 0xFF1E2826, 'color2': 0xFF2C8C7C
    }
  ];
  
  bool isLoading = true;
  String errorMessage = '';
  String _currentScreen = 'shop'; 
  bool isLoggedIn = false;
  bool hasPosAccess = false; 
  String _selectedCategory = 'All';
  String _userLocation = 'Locating...'; 

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _posSearchController = TextEditingController();
  
  // Real Tracking Controllers
  final TextEditingController _trackController = TextEditingController();
  Map<String, dynamic>? _trackedOrder;
  String _trackError = '';

  final PageController _bannerController = PageController(viewportFraction: 0.9);
  final ScrollController _mainScrollController = ScrollController(); 
  Timer? _bannerTimer;
  int _currentBannerIndex = 0;

  final List<Map<String, dynamic>> categories = [
    {'name': 'All', 'icon': Icons.apps, 'color': Colors.grey},
    {'name': 'First Aid', 'icon': Icons.medical_services, 'color': Colors.red},
    {'name': 'Medicines', 'icon': Icons.medication, 'color': Colors.orange},
    {'name': 'Injections', 'icon': Icons.vaccines, 'color': Colors.blue},
    {'name': 'Baby Care', 'icon': Icons.child_care, 'color': Colors.purple},
  ];

  @override
  void initState() {
    super.initState();
    _fetchRealLocation(); 
    fetchMedicines();
    fetchOrders(); 
    _startBannerTimer(); 
    fetchBanners(); 
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _mainScrollController.dispose();
    _trackController.dispose();
    super.dispose();
  }

  Future<void> _fetchRealLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) { setState(() => _userLocation = 'Nairobi (Default)'); return; }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) { setState(() => _userLocation = 'Nairobi (Default)'); return; }
      }
      Position position = await Geolocator.getCurrentPosition(timeLimit: const Duration(seconds: 5));
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) setState(() => _userLocation = placemarks.first.subLocality ?? placemarks.first.locality ?? "Nairobi");
    } catch (e) { setState(() => _userLocation = 'Nairobi (Default)'); }
  }

  void _startBannerTimer() {
    _bannerTimer?.cancel(); 
    _bannerTimer = Timer.periodic(const Duration(seconds: 6), (Timer timer) {
      if (_bannerController.hasClients && promoBanners.isNotEmpty) {
        _currentBannerIndex++;
        if (_currentBannerIndex >= promoBanners.length) _currentBannerIndex = 0;
        _bannerController.animateToPage(_currentBannerIndex, duration: const Duration(milliseconds: 800), curve: Curves.fastOutSlowIn);
      }
    });
  }

  Future<void> fetchBanners() async {
    try {
      final response = await http.get(Uri.parse('https://pharmastore-backend-jmcl.onrender.com/api/banners'));
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        final List apiBanners = (decodedData is List) ? decodedData : decodedData['results'] ?? [];
        if (apiBanners.isNotEmpty) { setState(() { promoBanners = apiBanners; }); }
      }
    } catch (e) { debugPrint("Using default banners."); }
  }

  Future<void> fetchMedicines() async {
    try {
      final response = await http.get(Uri.parse('https://pharmastore-backend-jmcl.onrender.com/api/medicines'));
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        setState(() { medicines = (decodedData is List) ? decodedData : decodedData['results'] ?? []; _applyFilters(); isLoading = false; errorMessage = ''; });
      } else { setState(() { errorMessage = 'Server is waking up. Please wait...'; isLoading = false; }); }
    } catch (e) { setState(() { errorMessage = 'Failed to connect to database.'; isLoading = false; }); }
  }

  Future<void> fetchOrders() async {
    try {
      final response = await http.get(Uri.parse('https://pharmastore-backend-jmcl.onrender.com/api/orders'));
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        setState(() => orders = (decodedData is List) ? decodedData : decodedData['results'] ?? []);
      }
    } catch (e) {}
  }

  void _applyFilters([String? explicitQuery]) {
    setState(() {
      String activeSearch = explicitQuery ?? _searchController.text;
      filteredMedicines = medicines.where((med) {
        final name = med['name'].toString().toLowerCase();
        return name.contains(activeSearch.toLowerCase()) && (_selectedCategory == 'All' || med['category'] == _selectedCategory);
      }).toList();
    });
  }

  void _filterSearch(String query) => _applyFilters(query);
  void _setCategory(String categoryName) { setState(() => _selectedCategory = categoryName); _applyFilters(); }
  void _showTopSnackbar(String message, {Color color = const Color(0xFF2C8C7C)}) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar(); 
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: const TextStyle(color: Colors.white)), backgroundColor: color, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24)));
  }

  void _addToCart(dynamic med, {bool isPos = false, int qty = 1}) {
    setState(() {
      List<Map<String, dynamic>> activeCart = isPos ? posCart : cart;
      int existingIndex = activeCart.indexWhere((item) => item['id'] == med['id']);
      if (existingIndex >= 0) activeCart[existingIndex]['cart_quantity'] += qty; 
      else { Map<String, dynamic> cartItem = Map.from(med); cartItem['cart_quantity'] = qty; activeCart.add(cartItem); }
    });
    if (!isPos) _showTopSnackbar('$qty x ${med['name']} added to cart!'); 
  }

  void _showProductDetails(dynamic med, {bool isPos = false, required String heroTag}) {
    int selectedQuantity = 1;
    String? imageUrl = med['image'] != null ? (med['image'].toString().startsWith('http') ? med['image'] : 'https://pharmastore-backend-jmcl.onrender.com${med['image']}') : null;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.65, 
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))),
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 50, height: 6, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))), const SizedBox(height: 32),
                  Expanded(child: Center(child: Hero(tag: heroTag, child: imageUrl != null ? Image.network(imageUrl, fit: BoxFit.contain) : const Icon(Icons.medication, size: 120, color: Colors.grey)))), const SizedBox(height: 24),
                  Text(med['name'], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
                  Text('Category: ${med['category'] ?? 'General'}', style: const TextStyle(fontSize: 16, color: Colors.grey)), const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('KES ${med['price']}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2C8C7C))),
                      Container(
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(30)),
                        child: Row(
                          children: [
                            IconButton(icon: const Icon(Icons.remove, color: Colors.red), onPressed: () { if (selectedQuantity > 1) setModalState(() => selectedQuantity--); }),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0), child: Text('$selectedQuantity', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                            IconButton(icon: const Icon(Icons.add, color: Colors.green), onPressed: () => setModalState(() => selectedQuantity++)),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity, height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C8C7C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                      onPressed: () { Navigator.pop(context); _addToCart(med, isPos: isPos, qty: selectedQuantity); },
                      child: Text('Add $selectedQuantity to Cart', style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            );
          }
        );
      }
    );
  }

  Future<void> _updateOrderStatus(int orderId, String newStatus) async {
    try {
      final response = await http.patch(Uri.parse('https://pharmastore-backend-jmcl.onrender.com/api/orders/$orderId'), headers: {'Content-Type': 'application/json'}, body: json.encode({'status': newStatus}));
      if (response.statusCode == 200) { _showTopSnackbar('Order #$orderId updated to $newStatus!', color: Colors.green); fetchOrders(); }
    } catch (e) { _showTopSnackbar('Server connection error.', color: Colors.red); }
  }

  void _showDispatchControlPanel(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 50, height: 6, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))), const SizedBox(height: 24),
              Text('Update Order #${order['id']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2C8C7C))), const SizedBox(height: 8),
              Text('Current Status: ${order['status']}', style: const TextStyle(fontSize: 16, color: Colors.grey)), const SizedBox(height: 24),
              _buildStatusButton(order['id'], 'Processed', Icons.inventory, Colors.blue), const SizedBox(height: 12),
              _buildStatusButton(order['id'], 'Dispatched', Icons.local_shipping, Colors.orange), const SizedBox(height: 12),
              _buildStatusButton(order['id'], 'Delivered', Icons.check_circle, Colors.green),
            ],
          ),
        );
      }
    );
  }

  Widget _buildStatusButton(int orderId, String statusName, IconData icon, Color color) {
    return SizedBox(
      width: double.infinity, height: 60,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(side: BorderSide(color: color, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        onPressed: () { Navigator.pop(context); _updateOrderStatus(orderId, statusName); },
        icon: Icon(icon, color: color), label: Text('Mark as $statusName', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      )
    );
  }

  Future<void> _showPaymentDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Select Payment Method', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C8C7C))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(leading: const Icon(Icons.money, color: Colors.green), title: const Text('Cash', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(context); _processCheckout(paymentMethod: 'Cash'); }), const Divider(),
              ListTile(leading: const Icon(Icons.phone_android, color: Colors.green), title: const Text('M-Pesa', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(context); _processCheckout(paymentMethod: 'M-Pesa'); }), const Divider(),
              ListTile(leading: const Icon(Icons.credit_card, color: Colors.orange), title: const Text('Credit Line (30 Days)', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(context); _processCheckout(paymentMethod: 'Credit'); }), const Divider(),
              ListTile(leading: const Icon(Icons.local_shipping, color: Colors.blue), title: const Text('Pay on Delivery', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(context); _processCheckout(paymentMethod: 'Pay on Delivery'); }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _processCheckout({bool isPos = false, String paymentMethod = 'Cash'}) async {
    if (paymentMethod == 'M-Pesa') {
      showDialog(context: context, barrierDismissible: false, builder: (context) => MpesaSimulationDialog(onComplete: () => _finalizeCheckoutAPI(isPos: isPos, paymentMethod: paymentMethod)));
    } else { _finalizeCheckoutAPI(isPos: isPos, paymentMethod: paymentMethod); }
  }

  Future<void> _finalizeCheckoutAPI({required bool isPos, required String paymentMethod}) async {
    setState(() => isLoading = true);
    try {
      final itemsToProcess = isPos ? posCart : cart;
      final response = await http.post(Uri.parse('https://pharmastore-backend-jmcl.onrender.com/api/checkout'), headers: {'Content-Type': 'application/json'}, body: json.encode({'items': itemsToProcess, 'payment_method': paymentMethod}));
      if (response.statusCode == 201) {
        setState(() { if (isPos) { posCart.clear(); } else { cart.clear(); _currentScreen = 'track'; } });
        _showTopSnackbar(isPos ? 'Cash Sale Complete! Stock updated.' : 'Order successfully sent to Dispatch!', color: Colors.green);
        fetchMedicines(); fetchOrders(); 
      }
    } catch (e) { _showTopSnackbar('Checkout failed.', color: Colors.red); }
    setState(() => isLoading = false);
  }

  Future<void> _printReceipt(Map<String, dynamic> order) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a5, build: (pw.Context context) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Header(level: 0, child: pw.Text('PharmaStore Dispatch Receipt', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900))), pw.SizedBox(height: 20), pw.Text('Order Number: #${order['id']}', style: const pw.TextStyle(fontSize: 16)), pw.Text('Date: ${DateTime.now().toString().split(' ')[0]}', style: const pw.TextStyle(fontSize: 16)), pw.SizedBox(height: 20), pw.Divider(), pw.SizedBox(height: 10), pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Items Processed:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text('${order['quantity_sold']} Units')]), pw.SizedBox(height: 10), pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Payment Method:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text('${order['payment_method'] ?? 'Cash'}')]), pw.SizedBox(height: 10), pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Dispatch Status:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text('${order['status'] ?? 'Processed'}')]), pw.SizedBox(height: 10), pw.Divider(), pw.SizedBox(height: 10), pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('TOTAL DUE', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)), pw.Text('KES ${order['total_price']}', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.green700))]), pw.Spacer(), pw.Center(child: pw.Text('Thank you for choosing PharmaStore!', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey)))
      ]);
    }));
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'PharmaStore_Receipt_${order['id']}');
  }

  Future<void> _generateAdminReport() async {
    double totalRev = 0, pendingRev = 0, cash = 0, mpesa = 0, credit = 0; int delivered = 0;
    for (var o in orders) {
      double price = double.parse(o['total_price'].toString()); totalRev += price;
      if (o['status'] == 'Delivered') delivered++;
      if (o['payment_status'] == 'Pending' || o['payment_method'] == 'Credit' || o['payment_method'] == 'Pay on Delivery') pendingRev += price;
      if (o['payment_method'] == 'Cash') cash += price;
      if (o['payment_method'] == 'M-Pesa') mpesa += price;
      if (o['payment_method'] == 'Credit') credit += price;
    }
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(40), build: (pw.Context context) => [
      pw.Header(level: 0, child: pw.Text('PharmaStore Live Business Report', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800))), pw.SizedBox(height: 10), pw.Text('Generated on: ${DateTime.now().toString().split('.')[0]}', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)), pw.SizedBox(height: 30), pw.Text('1. Revenue Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)), pw.Divider(color: PdfColors.grey300), pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Gross Revenue Volume:', style: const pw.TextStyle(fontSize: 16)), pw.Text('KES $totalRev', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green800))]), pw.SizedBox(height: 8), pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Pending/Credit Receivables:'), pw.Text('KES $pendingRev', style: const pw.TextStyle(color: PdfColors.orange700))]), pw.SizedBox(height: 30), pw.Text('2. Payment Method Breakdown', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)), pw.Divider(color: PdfColors.grey300), pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Cash Sales:'), pw.Text('KES $cash')]), pw.SizedBox(height: 4), pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('M-Pesa Sales:'), pw.Text('KES $mpesa')]), pw.SizedBox(height: 4), pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Credit/Terms Sales:'), pw.Text('KES $credit')]), pw.SizedBox(height: 30), pw.Text('3. Logistics & Fulfillment', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)), pw.Divider(color: PdfColors.grey300), pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Total Orders Processed:'), pw.Text('${orders.length}')]), pw.SizedBox(height: 4), pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Successfully Delivered:'), pw.Text('$delivered')]), pw.SizedBox(height: 40), pw.Center(child: pw.Text('-- Confidential: Internal Pharmacy Use Only --', style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10))),
    ]));
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'PharmaStore_Report_${DateTime.now().millisecondsSinceEpoch}');
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 850;
    Widget currentBody;
    switch (_currentScreen) {
      case 'dashboard': currentBody = _buildDashboardBody(); break;
      case 'cart': currentBody = _buildCartBody(); break;
      case 'pos': currentBody = _buildPOSBody(); break;
      case 'track': currentBody = _buildTrackingBody(); break; 
      case 'shop':
      default: currentBody = _buildStoreBody(isDesktop); break; 
    }

    return Scaffold(
      extendBody: !isDesktop, 
      appBar: isDesktop ? null : _buildMobileAppBar(),
      body: Column(
        children: [
          if (isDesktop) _buildDesktopHeader(), 
          Expanded(
            child: Stack(
              children: [
                ResponsiveWrapper(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: KeyedSubtree(key: ValueKey<String>(_currentScreen), child: currentBody),
                  ),
                ),
                if (!isDesktop) 
                  Positioned(bottom: 24, left: 24, right: 24, child: _buildFloatingNavBar())
              ],
            ),
          ),
        ],
      ), 
    );
  }

  // Updated Nav bar (Removed Wishlist)
  Widget _buildFloatingNavBar() {
    return Container(
      height: 70, decoration: BoxDecoration(color: const Color(0xFF1E2826), borderRadius: BorderRadius.circular(35), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(Icons.home_filled, 'shop'), 
          _buildNavItem(Icons.shopping_cart_outlined, 'cart', badge: cart.length), 
          _buildNavItem(Icons.my_location_outlined, 'track'), 
          _buildNavItem(Icons.person_outline, isLoggedIn ? 'dashboard' : 'login'),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String targetScreen, {int badge = 0}) {
    bool isSelected = _currentScreen == targetScreen || (targetScreen == 'login' && _currentScreen == 'dashboard');
    return GestureDetector(
      onTap: () {
        if (targetScreen == 'login') {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())).then((res) {
            if (res != null && res['loggedIn'] == true) { 
              setState(() { 
                isLoggedIn = true; hasPosAccess = res['posAccess']; _currentScreen = 'dashboard'; 
                userName = res['name'] ?? 'Vendor';
                userProfilePic = res['pic'] ?? '';
              }); 
              fetchOrders(); 
            }
          });
        } else { setState(() => _currentScreen = targetScreen); }
      },
      child: Container(
        padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isSelected ? const Color(0xFF2C8C7C) : Colors.transparent, shape: BoxShape.circle),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey[400], size: 26),
            if (badge > 0) Positioned(top: -4, right: -4, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))))
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopHeader() {
    return Container(
      color: Colors.white, width: double.infinity,
      child: Column(
        children: [
          Container(width: double.infinity, color: const Color(0xFF2C8C7C), padding: const EdgeInsets.symmetric(vertical: 6), child: const Text("Free Delivery for orders above KES 2,000 | T&Cs Apply", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(onTap: () => setState(() => _currentScreen = 'shop'), child: Row(children: [const Icon(Icons.local_pharmacy, color: Color(0xFF2C8C7C), size: 40), const SizedBox(width: 8), const Text('PharmaStore', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2C8C7C)))])),
                Row(
                  children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Row(children: [Icon(Icons.flash_on, color: Colors.orange, size: 20), SizedBox(width: 8), Text("Express Delivery to\nNairobi", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))])), const SizedBox(width: 32),
                    IconButton(
                      icon: Icon(isLoggedIn ? Icons.account_circle : Icons.person_outline, color: isLoggedIn ? const Color(0xFF2C8C7C) : Colors.black87, size: 28),
                      onPressed: () {
                        if (!isLoggedIn) { 
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())).then((res) { 
                            if (res != null && res['loggedIn'] == true) { 
                              setState(() { 
                                isLoggedIn = true; hasPosAccess = res['posAccess']; 
                                userName = res['name'] ?? 'Vendor';
                                userProfilePic = res['pic'] ?? '';
                              }); 
                              fetchOrders(); 
                            } 
                          }); 
                        } 
                        else { setState(() => _currentScreen = 'dashboard'); }
                      }
                    ), const SizedBox(width: 16),
                    ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E2826), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)), onPressed: () => setState(() => _currentScreen = 'cart'), icon: const Icon(Icons.shopping_cart, size: 20), label: Text(cart.length.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))
                  ]
                )
              ]
            )
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  TextButton(onPressed: () { if (_currentScreen != 'shop') setState(() => _currentScreen = 'shop'); Future.delayed(const Duration(milliseconds: 100), () => _mainScrollController.animateTo(450, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut)); }, child: const Text("Shop by Category", style: TextStyle(color: Colors.black87, fontSize: 15))), const SizedBox(width: 16),
                  TextButton(onPressed: () { if (_currentScreen != 'shop') setState(() => _currentScreen = 'shop'); Future.delayed(const Duration(milliseconds: 100), () => _mainScrollController.animateTo(900, duration: const Duration(milliseconds: 800), curve: Curves.easeInOut)); }, child: const Text("All Products", style: TextStyle(color: Colors.black87, fontSize: 15))), const SizedBox(width: 16),
                  TextButton(onPressed: () => setState(() => _currentScreen = 'track'), child: const Text("Track Order", style: TextStyle(color: Colors.black87, fontSize: 15))),
                ]),
                Row(children: [
                  ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E2826), foregroundColor: Colors.white, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)), onPressed: () => _showTopSnackbar('Telehealth coming soon!', color: Colors.blue), child: const Text("Speak to a Doctor", style: TextStyle(fontWeight: FontWeight.bold))), const SizedBox(width: 16),
                  ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C8C7C), foregroundColor: Colors.white, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)), onPressed: () async { final url = Uri.parse('/pharmastore.apk'); await launchUrl(url, mode: LaunchMode.externalApplication); }, icon: const Icon(Icons.android), label: const Text("Download App", style: TextStyle(fontWeight: FontWeight.bold))), const SizedBox(width: 16),
                  ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE54A4A), foregroundColor: Colors.white, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PrescriptionUploadScreen())), child: const Text("Upload a Prescription", style: TextStyle(fontWeight: FontWeight.bold))),
                ])
              ]
            )
          )
        ]
      )
    );
  }

  // Updated Mobile App Bar (Dynamic Name, Photo, Interactive Notification)
  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      toolbarHeight: 90,
      title: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                if (!isLoggedIn) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())).then((res) {
                    if (res != null && res['loggedIn'] == true) { 
                      setState(() { 
                        isLoggedIn = true; hasPosAccess = res['posAccess']; _currentScreen = 'dashboard'; 
                        userName = res['name'] ?? 'Vendor';
                        userProfilePic = res['pic'] ?? '';
                      }); 
                      fetchOrders(); 
                    }
                  });
                } else { setState(() => _currentScreen = 'dashboard'); }
              },
              child: CircleAvatar(
                radius: 24, 
                backgroundColor: Colors.grey.shade300,
                backgroundImage: userProfilePic.isNotEmpty ? NetworkImage(userProfilePic) : null,
                child: userProfilePic.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 30) : null,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(children: [
                  const Text('Hello, ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)), 
                  Text(userName.isNotEmpty ? userName : 'Guest!', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C8C7C)))
                ]),
                const Text('How are you feel today?', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
              ],
            ),
            const Spacer(),
            GestureDetector(
              onTap: () { _showTopSnackbar('No new notifications.', color: Colors.orange); },
              child: Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.notifications_outlined, color: Color(0xFF2C8C7C))),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStoreBody(bool isDesktop) {
    if (isLoading) { return CustomScrollView(controller: _mainScrollController, slivers: [SliverPadding(padding: const EdgeInsets.all(24), sliver: SliverGrid(gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, childAspectRatio: 0.75, crossAxisSpacing: 16, mainAxisSpacing: 16), delegate: SliverChildBuilderDelegate((context, index) => Shimmer.fromColors(baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!, child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)))), childCount: 12)))]); }
    if (errorMessage.isNotEmpty) return Center(child: Padding(padding: const EdgeInsets.all(32.0), child: Text(errorMessage, style: const TextStyle(color: Colors.red, fontSize: 18))));

    bool isSearching = _searchController.text.trim().isNotEmpty;

    // Grab all items on offer
    List<dynamic> offerMedicines = filteredMedicines.where((med) => med['is_on_offer'] == true).toList();

    return CustomScrollView(
      controller: _mainScrollController,
      slivers: [
        if (!isSearching) ...[
          // 1. Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                      child: TextField(
                        controller: _searchController, onChanged: _filterSearch,
                        decoration: InputDecoration(hintText: 'Search for Medicine and more...', hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14), prefixIcon: const Icon(Icons.search, color: Colors.grey), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(padding: const EdgeInsets.all(14), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.tune, color: Color(0xFF2C8C7C)))
                ],
              ),
            ),
          ),

          // 2. DYNAMIC BANNERS
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none, alignment: Alignment.bottomCenter,
              children: [
                SizedBox(
                  height: isDesktop ? 350 : 220, 
                  child: PageView.builder(
                    controller: _bannerController,
                    itemCount: promoBanners.length,
                    itemBuilder: (context, index) {
                      final banner = promoBanners[index];

                      int parseColor(dynamic c, int fallback) {
                        if (c == null) return fallback; if (c is int) return c; if (c is String && c.startsWith('0x')) return int.tryParse(c) ?? fallback; return fallback;
                      }
                      final color1 = Color(parseColor(banner['color1'], 0xFF2C8C7C));
                      final color2 = Color(parseColor(banner['color2'], 0xFF1E2826));
                      String? imgUrl = banner['image'] != null ? (banner['image'].toString().startsWith('http') ? banner['image'] : 'https://pharmastore-backend-jmcl.onrender.com${banner['image']}') : null;

                      return AnimatedBuilder(
                        animation: _bannerController,
                        builder: (context, child) {
                          double value = 1.0;
                          if (_bannerController.position.haveDimensions) { value = _bannerController.page! - index; value = (1 - (value.abs() * 0.2)).clamp(0.8, 1.0); }
                          return Center(child: SizedBox(height: Curves.easeOut.transform(value) * (isDesktop ? 350 : 220), width: Curves.easeOut.transform(value) * MediaQuery.of(context).size.width, child: child));
                        },
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 8, vertical: isDesktop ? 0 : 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(isDesktop ? 0 : 24), 
                            image: imgUrl != null ? DecorationImage(image: NetworkImage(imgUrl), fit: BoxFit.cover) : null,
                            gradient: imgUrl == null ? LinearGradient(colors: [color1, color2], begin: Alignment.topLeft, end: Alignment.bottomRight) : null, 
                            boxShadow: isDesktop ? [] : [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 8))],
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (imgUrl == null)
                                Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(banner['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.2)), const SizedBox(height: 12), Text(banner['subtitle'] ?? '', style: const TextStyle(color: Colors.yellow, fontSize: 16, fontWeight: FontWeight.bold))]),
                                ),
                              Positioned(top: 16, right: 16, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Text(banner['badge'] ?? 'PROMO', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black))))
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (isDesktop) 
                  Positioned(
                    bottom: -40, 
                    child: Container(
                      width: 600, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("What Are You Looking For?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PrescriptionUploadScreen())), icon: const Icon(Icons.receipt_long, color: Color(0xFF2C8C7C)), label: const Text("Order With Prescription", style: TextStyle(color: Color(0xFF2C8C7C))))
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _searchController, onChanged: _filterSearch, onSubmitted: (value) => _filterSearch(value), 
                            decoration: InputDecoration(hintText: 'Search for Medication & Products.', filled: true, fillColor: Colors.grey[100], suffixIcon: Container(margin: const EdgeInsets.all(4), decoration: BoxDecoration(color: const Color(0xFF2C8C7C), borderRadius: BorderRadius.circular(30)), child: IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () { _filterSearch(_searchController.text); FocusScope.of(context).unfocus(); })), border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          if (isDesktop) const SliverToBoxAdapter(child: SizedBox(height: 60)),
          if (!isDesktop) 
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PrescriptionUploadScreen())),
                  child: Container(
                    padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFE8F4F1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.receipt_long, color: Color(0xFF2C8C7C), size: 30)), const SizedBox(width: 16),
                        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Order via Prescription', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), SizedBox(height: 4), Text('Upload prescription & get medicines delivered by drone', style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.3))])), const SizedBox(width: 12),
                        Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Color(0xFF2C8C7C), shape: BoxShape.circle), child: const Icon(Icons.upload, color: Colors.white, size: 20))
                      ],
                    ),
                  ),
                ),
              )
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), TextButton(onPressed: (){}, child: const Text('View All', style: TextStyle(color: Color(0xFF2C8C7C), fontWeight: FontWeight.bold)))]),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index]; bool isSelected = _selectedCategory == cat['name'];
                  return GestureDetector(
                    onTap: () => _setCategory(cat['name']),
                    child: Container(margin: const EdgeInsets.symmetric(horizontal: 6), padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), border: Border.all(color: isSelected ? const Color(0xFF2C8C7C) : Colors.transparent, width: 1.5)), child: Row(children: [Icon(cat['icon'], color: cat['color'], size: 20), const SizedBox(width: 8), Text(cat['name'], style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF2C8C7C) : Colors.black87))])),
                  );
                }
              ),
            ),
          ),

          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 8), child: const Text('Nearby Smart Pharmacies', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: partnerPharmacies.length,
                itemBuilder: (context, index) {
                  final pharmacy = partnerPharmacies[index];
                  return Container(
                    width: 160, margin: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), image: DecorationImage(image: NetworkImage(pharmacy['image']), fit: BoxFit.cover)),
                    child: Stack(
                      children: [
                        Positioned(bottom: 0, left: 0, right: 0, child: Container(height: 80, decoration: BoxDecoration(borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)), gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.8), Colors.transparent])))),
                        Positioned(top: 12, right: 12, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Color(0xFF2C8C7C), shape: BoxShape.circle), child: const Icon(Icons.arrow_outward, color: Colors.white, size: 16))),
                        Positioned(bottom: 12, left: 12, right: 12, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(pharmacy['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), Text('${pharmacy['distance']} away', style: const TextStyle(color: Colors.white70, fontSize: 12))]))
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          
          // ADDED: Special Offers Section right before All Products
          if (offerMedicines.isNotEmpty) ...[
            const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 16.0), child: Text('Special Offers', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFE54A4A))))),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 180, 
                child: ListView.builder(
                  scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: offerMedicines.length,
                  itemBuilder: (context, index) {
                    final med = offerMedicines[index];
                    String? imageUrl = med['image'] != null ? (med['image'].toString().startsWith('http') ? med['image'] : 'https://pharmastore-backend-jmcl.onrender.com${med['image']}') : null;

                    return GestureDetector(
                      onTap: () => _showProductDetails(med, heroTag: 'med_offer_${med['id']}'), 
                      child: Container(
                        width: 140, margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE54A4A).withOpacity(0.3), width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 5))]),
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12.0), 
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start, 
                                children: [
                                  Expanded(flex: 3, child: Center(child: Hero(tag: 'med_offer_${med['id']}', child: imageUrl != null ? Image.network(imageUrl, fit: BoxFit.contain) : const Icon(Icons.medication, color: Colors.grey, size: 40)))), const SizedBox(height: 8), 
                                  Text(med['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis), const Spacer(), 
                                  Text('KES ${(double.parse(med['price'].toString()) * (1 + (med['discount_percentage'] / 100))).toStringAsFixed(2)}', style: TextStyle(fontSize: 10, decoration: TextDecoration.lineThrough, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
                                  Text('KES ${med['price']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFE54A4A))),
                                ]
                              )
                            ),
                            Positioned(top: 0, right: 0, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: const BoxDecoration(color: Color(0xFFE54A4A), borderRadius: BorderRadius.only(topRight: Radius.circular(20), bottomLeft: Radius.circular(12))), child: Text('-${med['discount_percentage']}%', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
          
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 16.0), child: Text('All Medical Products', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E2826))))),
        ] else ...[
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 8.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Search Results', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E2826))), Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF2C8C7C).withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text('${filteredMedicines.length} found', style: const TextStyle(color: Color(0xFF2C8C7C), fontWeight: FontWeight.bold, fontSize: 13)))]))),
        ],

        SliverPadding(
          padding: EdgeInsets.only(left: 24, right: 24, bottom: isDesktop ? 24 : 100), 
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, childAspectRatio: 0.75, crossAxisSpacing: 16, mainAxisSpacing: 20),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final med = filteredMedicines[index];
                String? imageUrl = med['image'] != null ? (med['image'].toString().startsWith('http') ? med['image'] : 'https://pharmastore-backend-jmcl.onrender.com${med['image']}') : null;

                return GestureDetector(
                  onTap: () => _showProductDetails(med, heroTag: 'med_image_all_${med['id']}'), 
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))]),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0), 
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, 
                            children: [
                              Expanded(flex: 4, child: Container(width: double.infinity, decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)), child: Center(child: Hero(tag: 'med_image_all_${med['id']}', child: imageUrl != null ? Image.network(imageUrl, fit: BoxFit.contain) : const Icon(Icons.medication, color: Colors.grey, size: 50))))), const SizedBox(height: 16), 
                              Text(med['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis), const Spacer(), 
                              if (med['is_on_offer'] == true) Text('KES ${(double.parse(med['price'].toString()) * (1 + (med['discount_percentage'] / 100))).toStringAsFixed(2)}', style: TextStyle(fontSize: 12, decoration: TextDecoration.lineThrough, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
                              Text('KES ${med['price']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF2C8C7C))), const SizedBox(height: 4), 
                            ]
                          )
                        ),
                        Positioned(bottom: 0, right: 0, child: GestureDetector(onTap: () => _addToCart(med, isPos: false), child: Container(decoration: const BoxDecoration(borderRadius: BorderRadius.only(topLeft: Radius.circular(24), bottomRight: Radius.circular(24)), color: Color(0xFF2C8C7C)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: const Icon(Icons.add, color: Colors.white, size: 22))))
                      ],
                    ),
                  ),
                );
              },
              childCount: filteredMedicines.length,
            ),
          ),
        ),
        
        if (isDesktop)
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF1E2826), padding: const EdgeInsets.all(40), 
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceAround, 
                children: [
                  const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Customer Service', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), SizedBox(height: 16), Text('Service and Warranty', style: TextStyle(color: Colors.white70)), SizedBox(height: 8), Text('Returns and Exchanges', style: TextStyle(color: Colors.white70)), SizedBox(height: 8), Text('Secured Online Payment', style: TextStyle(color: Colors.white70))]), 
                  const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('About PharmaStore', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), SizedBox(height: 16), Text('About Us', style: TextStyle(color: Colors.white70)), SizedBox(height: 8), Text('Pharmacy Locations', style: TextStyle(color: Colors.white70)), SizedBox(height: 8), Text('Health & Safety Policies', style: TextStyle(color: Colors.white70))]), 
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Need Help?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), SizedBox(height: 16), Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: const Color(0xFF2C8C7C), borderRadius: BorderRadius.circular(8)), child: const Row(children: [Icon(Icons.phone, color: Colors.white), SizedBox(width: 8), Text('0800 221 322', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))]))])
                ]
              )
            )
          ),
        if (isDesktop) SliverToBoxAdapter(child: Container(color: Colors.black87, padding: const EdgeInsets.all(16), child: const Center(child: Text('© 2026 PharmaStore Kenya. All rights reserved.', style: TextStyle(color: Colors.white54)))))
      ],
    );
  }

  Widget _buildCartBody() {
    if (cart.isEmpty) return const Center(child: Text('Your cart is empty!', style: TextStyle(fontSize: 18, color: Colors.grey)));
    double subTotal = 0; for (var item in cart) { subTotal += double.parse(item['price'].toString()) * item['cart_quantity']; }
    double distanceKm = 4.5; double deliveryFee = distanceKm * 30.0; double grandTotal = subTotal + deliveryFee;

    return Column(
      children: [
        const SizedBox(height: 40), const Text('Your Cart', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Expanded(child: ListView.builder(itemCount: cart.length, itemBuilder: (context, index) { final item = cart[index]; return ListTile(leading: const Icon(Icons.medication, color: Color(0xFF2C8C7C)), title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Qty: ${item['cart_quantity']}'), trailing: Text('KES ${double.parse(item['price'].toString()) * item['cart_quantity']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C8C7C)))); })),
        Container(padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).size.width > 850 ? 24 : 100), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))], borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal:', style: TextStyle(color: Colors.grey)), Text('KES $subTotal', style: const TextStyle(fontWeight: FontWeight.bold))]), const SizedBox(height: 8), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Delivery Fee:', style: const TextStyle(color: Colors.grey)), Text('KES $deliveryFee', style: const TextStyle(fontWeight: FontWeight.bold))]), const Divider(height: 24), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Grand Total:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text('KES $grandTotal', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2C8C7C)))]), const SizedBox(height: 16), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C8C7C)), onPressed: _showPaymentDialog, child: const Text('Checkout', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold))))]))
      ],
    );
  }

  // UPDATED: REAL TRACKING LOGIC
  Widget _buildTrackingBody() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Track Your Order', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E2826))),
              const SizedBox(height: 8),
              const Text('Enter your Order ID below to get live updates from the pharmacy.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                      child: TextField(
                        controller: _trackController, keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'Order ID (e.g., 12)', border: InputBorder.none, prefixIcon: Icon(Icons.search, color: Colors.grey), contentPadding: EdgeInsets.symmetric(vertical: 16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C8C7C), padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () {
                      setState(() {
                        _trackError = '';
                        try { _trackedOrder = orders.firstWhere((o) => o['id'].toString() == _trackController.text.trim()); } 
                        catch (e) { _trackedOrder = null; _trackError = 'Order not found. Please verify the ID.'; }
                      });
                    },
                    child: const Text('Track', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              if (_trackError.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_trackError, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        if (_trackedOrder != null)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('ID #${_trackedOrder!['id']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C8C7C))), Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text('${_trackedOrder!['status']}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)))]),
                    const SizedBox(height: 24),
                    
                    Builder(
                      builder: (context) {
                        String status = _trackedOrder!['status'] ?? 'Processed';
                        int step = 0; if (status == 'Dispatched') step = 1; if (status == 'Delivered') step = 2;
                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildTrackingStep(step >= 0, Icons.inventory, 'Processed', 'Pharmacy'),
                                Expanded(child: Container(height: 4, color: step >= 1 ? const Color(0xFF2C8C7C) : Colors.grey.shade300)),
                                _buildTrackingStep(step >= 1, Icons.motorcycle, 'Dispatched', 'Rider'),
                                Expanded(child: Container(height: 4, color: step >= 2 ? const Color(0xFF2C8C7C) : Colors.grey.shade300)),
                                _buildTrackingStep(step >= 2, Icons.home, 'Delivered', 'Your Location'),
                              ],
                            ),
                            const SizedBox(height: 32),
                            Container(
                              width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                children: [
                                  Icon(step == 0 ? Icons.info_outline : step == 1 ? Icons.motorcycle : Icons.celebration, color: const Color(0xFF2C8C7C)), const SizedBox(width: 12),
                                  Expanded(child: Text(step == 0 ? 'Your order is currently being packed by our pharmacists.' : step == 1 ? 'Your rider is on the way! Please keep your phone nearby.' : 'This order has been successfully delivered. Stay healthy!', style: const TextStyle(fontWeight: FontWeight.w500))),
                                ],
                              ),
                            )
                          ],
                        );
                      }
                    ),
                    const SizedBox(height: 24), const Divider(), const SizedBox(height: 16),
                    Row(children: [Expanded(child: _buildDetailCol('Payment', '${_trackedOrder!['payment_method']}')), Expanded(child: _buildDetailCol('Total Cost', 'KES ${_trackedOrder!['total_price']}'))]),
                    const SizedBox(height: 80), // Padding for nav bar
                  ],
                ),
              ),
            ),
          )
      ],
    );
  }

  Widget _buildTrackingStep(bool isActive, IconData icon, String title, String subtitle) {
    return Column(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isActive ? const Color(0xFF2C8C7C) : Colors.grey.shade200, shape: BoxShape.circle), child: Icon(icon, color: isActive ? Colors.white : Colors.grey, size: 20)), const SizedBox(height: 8), Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey))]);
  }

  Widget _buildDetailCol(String title, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))]);
  }

  Widget _buildDashboardBody() {
    double totalRevenue = 0; double pendingRevenue = 0; int deliveredCount = 0;
    List<dynamic> lowStockItems = medicines.where((med) => (med['stock_quantity'] ?? 0) < 10).toList();
    for (var order in orders) { 
      double price = double.parse(order['total_price'].toString()); totalRevenue += price; 
      if (order['payment_status'] == 'Pending' || order['payment_method'] == 'Credit' || order['payment_method'] == 'Pay on Delivery') pendingRevenue += price;
      if (order['status'] == 'Delivered') deliveredCount += 1;
    }
    final newOrders = orders.where((o) => o['status'] == 'Processed').toList().reversed.toList();
    final dispatchedOrders = orders.where((o) => o['status'] == 'Dispatched').toList().reversed.toList();
    final completedOrders = orders.where((o) => o['status'] == 'Delivered').toList().reversed.toList();
    
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Vendor Dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E2826))),
                Row(
                  children: [
                    if (hasPosAccess == true) ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C8C7C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: () => setState(() => _currentScreen = 'pos'), icon: const Icon(Icons.point_of_sale, color: Colors.white, size: 18), label: const Text('POS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    if (hasPosAccess == true) const SizedBox(width: 8), 
                    ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E2826), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: _generateAdminReport, icon: const Icon(Icons.download, color: Colors.white, size: 18), label: const Text('Export', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
                  ],
                )
              ],
            ),
          ),
          if (lowStockItems.isNotEmpty)
            Container(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), border: Border.all(color: Colors.red.withOpacity(0.5)), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Low Stock Alert', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)), Text('${lowStockItems.length} products need restocking.', style: const TextStyle(color: Colors.red, fontSize: 12))])), TextButton(onPressed: () { showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (context) => Container(padding: const EdgeInsets.all(24), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))), child: Column(children: [const Text('Inventory Alerts', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)), const SizedBox(height: 16), Expanded(child: ListView.builder(itemCount: lowStockItems.length, itemBuilder: (context, index) { final item = lowStockItems[index]; return ListTile(leading: const Icon(Icons.medication, color: Colors.grey), title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)), trailing: Text('${item['stock_quantity']} Left', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))); }))]))); }, child: const Text('View', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), 
            child: Row(
              children: [
                Expanded(flex: 2, child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2C8C7C), Color(0xFF1E2826)]), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Gross Revenue', style: TextStyle(color: Colors.white70, fontSize: 12)), const SizedBox(height: 4), Text('KES $totalRevenue', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))]))), const SizedBox(width: 8), 
                Expanded(flex: 1, child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withOpacity(0.3))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Pending', style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text('KES $pendingRevenue', style: const TextStyle(color: Colors.orange, fontSize: 14, fontWeight: FontWeight.bold))])) )
              ]
            )
          ),
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16), height: 45, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(25)),
            child: TabBar(indicatorSize: TabBarIndicatorSize.tab, indicator: BoxDecoration(color: const Color(0xFF2C8C7C), borderRadius: BorderRadius.circular(25)), labelColor: Colors.white, unselectedLabelColor: Colors.black54, labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), tabs: [Tab(text: 'New (${newOrders.length})'), Tab(text: 'Transit (${dispatchedOrders.length})'), Tab(text: 'Done (${completedOrders.length})')]),
          ),
          const SizedBox(height: 16),
          Expanded(child: TabBarView(children: [_buildOrderListView(newOrders, Icons.inventory, Colors.blue, 'Ready for Dispatch?'), _buildOrderListView(dispatchedOrders, Icons.motorcycle, Colors.orange, 'Currently with Rider'), _buildOrderListView(completedOrders, Icons.check_circle, Colors.green, 'Successfully Delivered')])),
        ],
      ),
    );
  }

  Widget _buildOrderListView(List<dynamic> tabOrders, IconData icon, Color badgeColor, String subtitleText) {
    if (tabOrders.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 60, color: Colors.grey[300]), const SizedBox(height: 16), const Text('No orders in this stage.', style: TextStyle(color: Colors.grey, fontSize: 16))]));
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).size.width > 850 ? 16 : 100), 
      itemCount: tabOrders.length, 
      itemBuilder: (context, index) { 
        final order = tabOrders[index]; final paymentMethod = order['payment_method'] ?? 'Cash'; 
        return InkWell(
          onTap: () => _showDispatchControlPanel(order),
          child: Card(elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(12)), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: badgeColor)), title: Text('Order #${order['id']} - ${order['quantity_sold']} Items', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Padding(padding: const EdgeInsets.only(top: 4.0), child: Text('KES ${order['total_price']} • $paymentMethod\n$subtitleText', style: const TextStyle(color: Colors.black54, height: 1.4))), trailing: IconButton(icon: const Icon(Icons.print, color: Color(0xFF2C8C7C)), tooltip: 'Print Dispatch Receipt', onPressed: () { _printReceipt(order); })))
        ); 
      }
    );
  }

  Widget _buildPOSBody() {
    double posTotal = 0; for (var item in posCart) { posTotal += double.parse(item['price'].toString()) * item['cart_quantity']; }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 16), 
          child: TextField(controller: _posSearchController, onChanged: _filterSearch, decoration: InputDecoration(hintText: 'Scan or search item...', filled: true, fillColor: Colors.white, prefixIcon: const Icon(Icons.qr_code_scanner, color: Color(0xFF2C8C7C)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))
        ),
        Expanded(
          flex: 2, 
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16), gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 150, childAspectRatio: 0.9, crossAxisSpacing: 8, mainAxisSpacing: 8), itemCount: filteredMedicines.length, 
            itemBuilder: (context, index) { 
              final med = filteredMedicines[index]; 
              return InkWell(
                onTap: () => _addToCart(med, isPos: true), 
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)), 
                  child: Padding(padding: const EdgeInsets.all(8.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.medication, color: Color(0xFF2C8C7C), size: 30), const SizedBox(height: 8), Text(med['name'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 2), const SizedBox(height: 4), Text('KES ${med['price']}', style: const TextStyle(color: Color(0xFF2C8C7C), fontWeight: FontWeight.bold))]))
                )
              ); 
            }
          )
        ),
        Expanded(
          flex: 1, 
          child: Container(
            color: Colors.grey[200], 
            child: posCart.isEmpty 
              ? const Center(child: Text('Register Empty', style: TextStyle(color: Colors.grey))) 
              : ListView.builder(itemCount: posCart.length, itemBuilder: (context, index) { final item = posCart[index]; return ListTile(title: Text(item['name'], style: const TextStyle(fontSize: 14)), trailing: Text('${item['cart_quantity']}x  |  KES ${double.parse(item['price'].toString()) * item['cart_quantity']}')); })
          )
        ),
        Container(
          width: double.infinity, height: 80, color: const Color(0xFF1E2826), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), 
          child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C8C7C)), onPressed: posCart.isEmpty ? null : () => _processCheckout(isPos: true), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('CASH SALE', style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)), Text('KES $posTotal', style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold))])) 
        )
      ],
    );
  }
}

// ==========================================
// 2. THE LOGIN SCREEN
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(Uri.parse('https://pharmastore-backend-jmcl.onrender.com/api/login/'), body: {'username': _phoneController.text, 'password': _passwordController.text});
      setState(() => _isLoading = false);
      if (response.statusCode == 200) {
        final data = json.decode(response.body); 
        bool posAccess = data['has_pos_access'] ?? false;
        
        // Return dynamic name and pic if your API provides it!
        String fetchedName = data['name'] ?? 'Vendor'; 
        String fetchedPic = data['profile_pic'] ?? '';

        Navigator.pop(context, {'loggedIn': true, 'posAccess': posAccess, 'name': fetchedName, 'pic': fetchedPic}); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vendor Access Granted!'), backgroundColor: Colors.green));
      } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid credentials or account not verified.'), backgroundColor: Colors.red)); }
    } catch (e) { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot connect to server.'), backgroundColor: Colors.red)); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, leading: const BackButton(color: Color(0xFF2C8C7C))),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400), padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storefront, size: 60, color: Color(0xFF2C8C7C)), const SizedBox(height: 16), const Text('Vendor Login', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2C8C7C))), const SizedBox(height: 32),
                  TextField(controller: _phoneController, decoration: InputDecoration(labelText: 'Phone Number', prefixIcon: const Icon(Icons.phone), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))), const SizedBox(height: 16),
                  TextField(controller: _passwordController, obscureText: true, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))), const SizedBox(height: 32),
                  SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C8C7C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), onPressed: _isLoading ? null : _login, child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Login', style: TextStyle(fontSize: 16, color: Colors.white)))), const SizedBox(height: 16),
                  TextButton(onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const RegistrationScreen())); }, child: const Text('New Vendor? Register Here', style: TextStyle(color: Color(0xFF2C8C7C), fontWeight: FontWeight.bold)))
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 3. THE REGISTRATION SCREEN
// ==========================================
class RegistrationScreen extends StatefulWidget { const RegistrationScreen({super.key}); @override State<RegistrationScreen> createState() => _RegistrationScreenState(); }
class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController(); final TextEditingController _emailController = TextEditingController(); final TextEditingController _phoneController = TextEditingController(); final TextEditingController _idController = TextEditingController(); final TextEditingController _ppbLicenseController = TextEditingController(); final TextEditingController _countyLicenseController = TextEditingController(); final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final response = await http.post(Uri.parse('https://pharmastore-backend-jmcl.onrender.com/api/register'), headers: {'Content-Type': 'application/json'}, body: json.encode({'pharmacy_name': _nameController.text, 'email': _emailController.text, 'phone_number': _phoneController.text, 'national_id': _idController.text, 'ppb_license': _ppbLicenseController.text, 'county_license': _countyLicenseController.text, 'password': _passwordController.text}));
      setState(() => _isLoading = false);
      if (response.statusCode == 201) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration Pending! We will email you once verified.'), backgroundColor: Colors.green)); Navigator.pop(context); } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration failed. Check details.'), backgroundColor: Colors.red)); }
    } catch (e) { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Server Error. Cannot connect to backend.'), backgroundColor: Colors.red)); }
  }

  Widget _buildTextField({required String label, required TextEditingController controller, required IconData icon, bool isPassword = false, TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(controller: controller, obscureText: isPassword, keyboardType: keyboardType, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: const Color(0xFF2C8C7C)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), validator: (value) => value!.isEmpty ? 'Required' : null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, leading: const BackButton(color: Color(0xFF2C8C7C)), elevation: 0),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500), padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.store, size: 60, color: Color(0xFF2C8C7C)), const SizedBox(height: 16), const Text('Vendor Registration', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2C8C7C))), const SizedBox(height: 8), const Text('We will email you once your licenses are verified.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)), const SizedBox(height: 32),
                  _buildTextField(label: 'Pharmacy Name', controller: _nameController, icon: Icons.local_pharmacy), const SizedBox(height: 16), _buildTextField(label: 'Email Address', controller: _emailController, icon: Icons.email, keyboardType: TextInputType.emailAddress), const SizedBox(height: 16), _buildTextField(label: 'Phone Number', controller: _phoneController, icon: Icons.phone, keyboardType: TextInputType.phone), const SizedBox(height: 16), _buildTextField(label: 'National ID', controller: _idController, icon: Icons.badge), const SizedBox(height: 16), _buildTextField(label: 'PPB License Number', controller: _ppbLicenseController, icon: Icons.medical_information), const SizedBox(height: 16), _buildTextField(label: 'County License Number', controller: _countyLicenseController, icon: Icons.account_balance), const SizedBox(height: 16), _buildTextField(label: 'Password', controller: _passwordController, icon: Icons.lock, isPassword: true), const SizedBox(height: 32),
                  SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C8C7C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), onPressed: _isLoading ? null : _submitRegistration, child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Application', style: TextStyle(color: Colors.white, fontSize: 16))))
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 4. PRESCRIPTION UPLOAD SCREEN
// ==========================================
class PrescriptionUploadScreen extends StatefulWidget { const PrescriptionUploadScreen({super.key}); @override State<PrescriptionUploadScreen> createState() => _PrescriptionUploadScreenState(); }
class _PrescriptionUploadScreenState extends State<PrescriptionUploadScreen> {
  final _formKey = GlobalKey<FormState>(); final TextEditingController _nameController = TextEditingController(); final TextEditingController _phoneController = TextEditingController(); final TextEditingController _addressController = TextEditingController(); XFile? _selectedImage; bool _isLoading = false; final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async { final XFile? image = await _picker.pickImage(source: ImageSource.gallery); if (image != null) { setState(() { _selectedImage = image; }); } }

  Future<void> _submitPrescription() async {
    if (!_formKey.currentState!.validate()) return; if (_selectedImage == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please attach a photo.'), backgroundColor: Colors.orange)); return; }
    setState(() => _isLoading = true);
    try {
      var request = http.MultipartRequest('POST', Uri.parse('https://pharmastore-backend-jmcl.onrender.com/api/prescriptions/upload'));
      request.fields['patient_name'] = _nameController.text; request.fields['phone_number'] = _phoneController.text; request.fields['delivery_address'] = _addressController.text;
      var imageBytes = await _selectedImage!.readAsBytes(); request.files.add(http.MultipartFile.fromBytes('prescription_image', imageBytes, filename: _selectedImage!.name));
      var response = await http.Response.fromStream(await request.send());
      setState(() => _isLoading = false);
      if (response.statusCode == 201) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prescription sent!'), backgroundColor: Colors.green)); Navigator.pop(context); } } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to upload.'), backgroundColor: Colors.red)); }
    } catch (e) { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection error.'), backgroundColor: Colors.red)); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Color(0xFF2C8C7C)), title: const Text('Upload Prescription', style: TextStyle(color: Color(0xFF2C8C7C), fontWeight: FontWeight.bold))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600), padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                children: [
                  Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withOpacity(0.3))), child: const Row(children: [Icon(Icons.security, color: Colors.blue), SizedBox(width: 12), Expanded(child: Text('Securely encrypted for pharmacist view only.', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)))])), const SizedBox(height: 32),
                  const Text('1. Patient Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C8C7C))), const SizedBox(height: 16),
                  TextFormField(controller: _nameController, decoration: InputDecoration(labelText: 'Full Name', prefixIcon: const Icon(Icons.person), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), validator: (value) => value!.isEmpty ? 'Required' : null), const SizedBox(height: 16),
                  TextFormField(controller: _phoneController, decoration: InputDecoration(labelText: 'Phone Number', prefixIcon: const Icon(Icons.phone), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), validator: (value) => value!.isEmpty ? 'Required' : null), const SizedBox(height: 16),
                  TextFormField(controller: _addressController, maxLines: 2, decoration: InputDecoration(labelText: 'Delivery Address', prefixIcon: const Icon(Icons.location_on), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), validator: (value) => value!.isEmpty ? 'Required' : null), const SizedBox(height: 32),
                  const Text('2. Attach Doctor\'s Note', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C8C7C))), const SizedBox(height: 16),
                  GestureDetector(onTap: _pickImage, child: Container(width: double.infinity, height: 150, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid, width: 2)), child: _selectedImage == null ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt, size: 40, color: Colors.grey), SizedBox(height: 8), Text('Tap to photo or gallery', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))]) : Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.check_circle, color: Colors.green, size: 30), const SizedBox(width: 12), Text('Image: ${_selectedImage!.name}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))]))), const SizedBox(height: 32),
                  SizedBox(width: double.infinity, height: 60, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C8C7C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), onPressed: _isLoading ? null : _submitPrescription, icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.send, color: Colors.white), label: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Securely Submit Prescription', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))))
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 5. M-PESA STK PUSH SIMULATOR
// ==========================================
class MpesaSimulationDialog extends StatefulWidget { final VoidCallback onComplete; const MpesaSimulationDialog({super.key, required this.onComplete}); @override State<MpesaSimulationDialog> createState() => _MpesaSimulationDialogState(); }
class _MpesaSimulationDialogState extends State<MpesaSimulationDialog> {
  String statusMessage = "Initiating Secure Connection..."; IconData currentIcon = Icons.security; bool isProcessing = true;
  @override void initState() { super.initState(); _runSimulation(); }
  Future<void> _runSimulation() async {
    await Future.delayed(const Duration(milliseconds: 1500)); if (mounted) setState(() { statusMessage = "Sending STK Push to phone..."; currentIcon = Icons.smartphone; });
    await Future.delayed(const Duration(milliseconds: 2000)); if (mounted) setState(() { statusMessage = "Please enter M-PESA PIN..."; currentIcon = Icons.dialpad; });
    await Future.delayed(const Duration(milliseconds: 3500)); if (mounted) setState(() { statusMessage = "Payment Received!"; currentIcon = Icons.check_circle; isProcessing = false; });
    await Future.delayed(const Duration(milliseconds: 1500)); if (mounted) { Navigator.pop(context); widget.onComplete(); }
  }
  @override Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), elevation: 20, backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(32), constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(duration: const Duration(milliseconds: 500), transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child), child: Container(key: ValueKey<IconData>(currentIcon), padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFF4CAF50).withOpacity(0.1), shape: BoxShape.circle), child: Icon(currentIcon, size: 60, color: const Color(0xFF4CAF50)))), const SizedBox(height: 24),
            const Text('M-PESA Express', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))), const SizedBox(height: 24),
            if (isProcessing) const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50))), if (isProcessing) const SizedBox(height: 24),
            Text(statusMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}