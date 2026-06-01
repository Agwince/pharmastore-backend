import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; 
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shimmer/shimmer.dart'; 
import 'package:fl_chart/fl_chart.dart'; 
import 'package:image_picker/image_picker.dart'; 

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
        primaryColor: const Color(0xFF003876),
        scaffoldBackgroundColor: const Color(0xFFF2F5F8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF003876),
          elevation: 0,
        ),
      ),
      home: const StorefrontScreen(), 
    );
  }
}

class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  const ResponsiveWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: child,
      ),
    );
  }
}

// ==========================================
// 1. THE MAIN APPLICATION
// ==========================================
class StorefrontScreen extends StatefulWidget {
  const StorefrontScreen({super.key});

  @override
  State<StorefrontScreen> createState() => _StorefrontScreenState();
}

class _StorefrontScreenState extends State<StorefrontScreen> {
  List<dynamic> medicines = [];
  List<dynamic> filteredMedicines = []; 
  List<dynamic> orders = []; 
  
  List<Map<String, dynamic>> cart = []; 
  List<Map<String, dynamic>> posCart = []; 
  
  List<dynamic> promoBanners = [];
  List<dynamic> wishlist = []; // Stores saved items

  bool isLoading = true;
  String errorMessage = '';
  String _currentScreen = 'shop'; 
  bool isLoggedIn = false; 
  
  String _selectedCategory = 'All';

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _posSearchController = TextEditingController();
  
  // Tracking Variables
  final TextEditingController _trackController = TextEditingController();
  Map<String, dynamic>? _trackedOrder;
  String _trackError = '';

  final PageController _bannerController = PageController(viewportFraction: 0.9);
  final ScrollController _mainScrollController = ScrollController(); // Controls scrolling
  Timer? _bannerTimer;
  int _currentBannerIndex = 0;

  final List<Map<String, dynamic>> categories = [
    {'name': 'All', 'icon': Icons.apps},
    {'name': 'Pain Relief', 'icon': Icons.medical_services},
    {'name': 'Vitamins', 'icon': Icons.medication_liquid},
    {'name': 'First Aid', 'icon': Icons.healing},
    {'name': 'Baby Care', 'icon': Icons.child_care},
    {'name': 'Supplements', 'icon': Icons.fitness_center},
    {'name': 'Personal Care', 'icon': Icons.clean_hands},
    {'name': 'Devices', 'icon': Icons.monitor_heart},
  ];

  @override
  void initState() {
    super.initState();
    fetchMedicines();
    fetchOrders(); 
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

  void _startBannerTimer() {
    if (promoBanners.isEmpty) return;
    _bannerTimer?.cancel(); 
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_bannerController.hasClients && promoBanners.isNotEmpty) {
        _currentBannerIndex++;
        if (_currentBannerIndex >= promoBanners.length) {
          _currentBannerIndex = 0;
          _bannerController.animateToPage(0, duration: const Duration(milliseconds: 800), curve: Curves.fastOutSlowIn);
        } else {
          _bannerController.animateToPage(_currentBannerIndex, duration: const Duration(milliseconds: 800), curve: Curves.fastOutSlowIn);
        }
      }
    });
  }

  Future<void> fetchBanners() async {
    try {
      final response = await http.get(Uri.parse('https://pharmastore-backend-jmcl.onrender.com/api/banners'));
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        setState(() {
          promoBanners = (decodedData is List) ? decodedData : decodedData['results'] ?? [];
        });
        _startBannerTimer(); 
      }
    } catch (e) {
      debugPrint("Could not fetch banners");
    }
  }

  Future<void> fetchMedicines() async {
    try {
      final response = await http.get(Uri.parse('https://pharmastore-backend-jmcl.onrender.com:8000/api/medicines'));
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        setState(() {
          medicines = (decodedData is List) ? decodedData : decodedData['results'] ?? [];
          _applyFilters(); 
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() { errorMessage = 'Failed to connect to database.'; isLoading = false; });
    }
  }

  Future<void> fetchOrders() async {
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8000/api/orders'));
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        setState(() => orders = (decodedData is List) ? decodedData : decodedData['results'] ?? []);
      }
    } catch (e) {
      debugPrint('Could not fetch orders: $e');
    }
  }

  void _applyFilters() {
    setState(() {
      filteredMedicines = medicines.where((med) {
        final matchesSearch = med['name'].toString().toLowerCase().contains(_searchController.text.toLowerCase());
        final matchesCategory = _selectedCategory == 'All' || med['category'] == _selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  void _filterSearch(String query) => _applyFilters();

  void _setCategory(String categoryName) {
    setState(() {
      _selectedCategory = categoryName;
    });
    _applyFilters();
  }

  void _showTopSnackbar(String message, {Color color = Colors.green}) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar(); 
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))),
          ],
        ),
        backgroundColor: color, behavior: SnackBarBehavior.floating, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height - 160, left: 24, right: 24),
        elevation: 10, duration: const Duration(seconds: 2),
      ),
    );
  }

  // Adds or removes items from the wishlist
  void _toggleWishlist(dynamic med) {
    setState(() {
      if (wishlist.any((item) => item['id'] == med['id'])) {
        wishlist.removeWhere((item) => item['id'] == med['id']);
        _showTopSnackbar('${med['name']} removed from Wishlist', color: Colors.orange);
      } else {
        wishlist.add(med);
        _showTopSnackbar('${med['name']} saved to Wishlist!', color: const Color(0xFFE91E63));
      }
    });
  }

  void _addToCart(dynamic med, {bool isPos = false, int qty = 1}) {
    setState(() {
      List<Map<String, dynamic>> activeCart = isPos ? posCart : cart;
      int existingIndex = activeCart.indexWhere((item) => item['id'] == med['id']);
      if (existingIndex >= 0) {
        activeCart[existingIndex]['cart_quantity'] += qty;
      } else {
        Map<String, dynamic> cartItem = Map.from(med);
        cartItem['cart_quantity'] = qty;
        activeCart.add(cartItem);
      }
    });
    if (!isPos) _showTopSnackbar('$qty x ${med['name']} added to cart!'); 
  }

  void _showProductDetails(dynamic med, {bool isPos = false, required String heroTag}) {
    int selectedQuantity = 1;
    String? imageUrl = med['image'] != null ? (med['image'].toString().startsWith('http') ? med['image'] : 'http://127.0.0.1:8000${med['image']}') : null;

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
                      Text('KES ${med['price']}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF003876))),
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
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
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

  // ==========================================
  // LOGISTICS: Update Order Status
  // ==========================================
  Future<void> _updateOrderStatus(int orderId, String newStatus) async {
    try {
      final response = await http.patch(
        Uri.parse('http://127.0.0.1:8000/api/orders/$orderId/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': newStatus}),
      );
      
      if (response.statusCode == 200) {
        _showTopSnackbar('Order #$orderId updated to $newStatus!', color: Colors.green);
        fetchOrders(); 
      } else {
        _showTopSnackbar('Failed to update order.', color: Colors.red);
      }
    } catch (e) {
      _showTopSnackbar('Server connection error.', color: Colors.red);
    }
  }

  void _showDispatchControlPanel(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 50, height: 6, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 24),
              Text('Update Order #${order['id']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF003876))),
              const SizedBox(height: 8),
              Text('Current Status: ${order['status']}', style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 24),
              
              _buildStatusButton(order['id'], 'Processed', Icons.inventory, Colors.blue),
              const SizedBox(height: 12),
              _buildStatusButton(order['id'], 'Dispatched', Icons.local_shipping, Colors.orange),
              const SizedBox(height: 12),
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
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
        ),
        onPressed: () {
          Navigator.pop(context); 
          _updateOrderStatus(orderId, statusName); 
        },
        icon: Icon(icon, color: color),
        label: Text('Mark as $statusName', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      )
    );
  }

  Future<void> _showPaymentDialog() async {
    if (!isLoggedIn) {
      _showTopSnackbar('Please log in to checkout!', color: Colors.orange);
      Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())).then((_) {
        setState(() => isLoggedIn = true);
        fetchOrders();
      });
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Select Payment Method', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF003876))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(leading: const Icon(Icons.money, color: Colors.green), title: const Text('Cash', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(context); _processCheckout(paymentMethod: 'Cash'); }),
              const Divider(),
              ListTile(leading: const Icon(Icons.phone_android, color: Colors.green), title: const Text('M-Pesa', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(context); _processCheckout(paymentMethod: 'M-Pesa'); }),
              const Divider(),
              ListTile(leading: const Icon(Icons.credit_card, color: Colors.orange), title: const Text('Credit Line (30 Days)', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(context); _processCheckout(paymentMethod: 'Credit'); }),
              const Divider(),
              ListTile(leading: const Icon(Icons.local_shipping, color: Colors.blue), title: const Text('Pay on Delivery', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(context); _processCheckout(paymentMethod: 'Pay on Delivery'); }),
            ],
          ),
        );
      },
    );
  }

  // Intercepts M-Pesa to show the simulator
  Future<void> _processCheckout({bool isPos = false, String paymentMethod = 'Cash'}) async {
    if (paymentMethod == 'M-Pesa') {
      // Show the beautiful simulator, then run the API call!
      showDialog(
        context: context,
        barrierDismissible: false, // Prevents user from clicking outside to cancel
        builder: (context) => MpesaSimulationDialog(
          onComplete: () => _finalizeCheckoutAPI(isPos: isPos, paymentMethod: paymentMethod),
        )
      );
    } else {
      // Normal flow for Cash, Credit, or Pay on Delivery
      _finalizeCheckoutAPI(isPos: isPos, paymentMethod: paymentMethod);
    }
  }

  // The actual Django API engine
  Future<void> _finalizeCheckoutAPI({required bool isPos, required String paymentMethod}) async {
    setState(() => isLoading = true);
    try {
      final itemsToProcess = isPos ? posCart : cart;
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/checkout'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'items': itemsToProcess, 'payment_method': paymentMethod}), 
      );
      if (response.statusCode == 201) {
        setState(() { if (isPos) posCart.clear(); else { cart.clear(); _currentScreen = 'dashboard'; } });
        _showTopSnackbar(isPos ? 'Cash Sale Complete! Stock updated.' : 'Order successfully sent to Dispatch!', color: Colors.green);
        fetchMedicines(); 
        fetchOrders(); 
      }
    } catch (e) {
      _showTopSnackbar('Checkout failed.', color: Colors.red);
    }
    setState(() => isLoading = false);
  }

  Future<void> _printReceipt(Map<String, dynamic> order) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a5, build: (pw.Context context) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Header(level: 0, child: pw.Text('PharmaStore Dispatch Receipt', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900))), 
        pw.SizedBox(height: 20), 
        pw.Text('Order Number: #${order['id']}', style: const pw.TextStyle(fontSize: 16)), 
        pw.Text('Date: ${DateTime.now().toString().split(' ')[0]}', style: const pw.TextStyle(fontSize: 16)), 
        pw.SizedBox(height: 20), 
        pw.Divider(), 
        pw.SizedBox(height: 10), 
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Items Processed:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text('${order['quantity_sold']} Units')]), 
        pw.SizedBox(height: 10), 
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Payment Method:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text('${order['payment_method'] ?? 'Cash'}')]), 
        pw.SizedBox(height: 10), 
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Dispatch Status:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text('${order['status'] ?? 'Processed'}')]), 
        pw.SizedBox(height: 10), 
        pw.Divider(), 
        pw.SizedBox(height: 10), 
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('TOTAL DUE', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)), pw.Text('KES ${order['total_price']}', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.green700))]), 
        pw.Spacer(), 
        pw.Center(child: pw.Text('Thank you for choosing PharmaStore!', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey)))
      ]);
    }));
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'PharmaStore_Receipt_${order['id']}');
  }

  // Admin PDF Business Report Generator
  Future<void> _generateAdminReport() async {
    // 1. Calculate the live stats
    double totalRev = 0, pendingRev = 0, cash = 0, mpesa = 0, credit = 0;
    int delivered = 0;
    for (var o in orders) {
      double price = double.parse(o['total_price'].toString());
      totalRev += price;
      if (o['status'] == 'Delivered') delivered++;
      if (o['payment_status'] == 'Pending' || o['payment_method'] == 'Credit' || o['payment_method'] == 'Pay on Delivery') pendingRev += price;
      if (o['payment_method'] == 'Cash') cash += price;
      if (o['payment_method'] == 'M-Pesa') mpesa += price;
      if (o['payment_method'] == 'Credit') credit += price;
    }

    // 2. Draw the PDF Document
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) => [
          pw.Header(level: 0, child: pw.Text('PharmaStore Live Business Report', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900))),
          pw.SizedBox(height: 10),
          pw.Text('Generated on: ${DateTime.now().toString().split('.')[0]}', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
          pw.SizedBox(height: 30),
          
          pw.Text('1. Revenue Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Divider(color: PdfColors.grey300),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Gross Revenue Volume:', style: const pw.TextStyle(fontSize: 16)), pw.Text('KES $totalRev', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green800))]),
          pw.SizedBox(height: 8),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Pending/Credit Receivables:'), pw.Text('KES $pendingRev', style: const pw.TextStyle(color: PdfColors.orange700))]),
          pw.SizedBox(height: 30),
          
          pw.Text('2. Payment Method Breakdown', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Divider(color: PdfColors.grey300),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Cash Sales:'), pw.Text('KES $cash')]),
          pw.SizedBox(height: 4),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('M-Pesa Sales:'), pw.Text('KES $mpesa')]),
          pw.SizedBox(height: 4),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Credit/Terms Sales:'), pw.Text('KES $credit')]),
          pw.SizedBox(height: 30),
          
          pw.Text('3. Logistics & Fulfillment', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Divider(color: PdfColors.grey300),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Total Orders Processed:'), pw.Text('${orders.length}')]),
          pw.SizedBox(height: 4),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Successfully Delivered:'), pw.Text('$delivered')]),
          pw.SizedBox(height: 40),
          
          pw.Center(child: pw.Text('-- Confidential: Internal Pharmacy Use Only --', style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10))),
        ]
      )
    );

    // 3. Trigger the device's print/save dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(), 
      name: 'PharmaStore_Report_${DateTime.now().millisecondsSinceEpoch}'
    );
  }

  @override
  Widget build(BuildContext context) {
    // Detect screen width to switch between Mobile and Web layouts
    bool isDesktop = MediaQuery.of(context).size.width > 850;

    Widget currentBody;
    switch (_currentScreen) {
      case 'dashboard': currentBody = _buildDashboardBody(); break;
      case 'cart': currentBody = _buildCartBody(); break;
      case 'pos': currentBody = _buildPOSBody(); break;
      case 'wishlist': currentBody = _buildWishlistBody(); break; 
      case 'track': currentBody = _buildTrackingBody(); break; 
      case 'shop':
      default: currentBody = _buildStoreBody(isDesktop); break; 
    }

    return Scaffold(
      // On Web, the AppBar is hidden. On Mobile, it shows the compact Mobile AppBar.
      appBar: isDesktop ? null : _buildMobileAppBar(),
      body: Column(
        children: [
          // On Web, draw custom Desktop Header at the top of the body
          if (isDesktop) _buildDesktopHeader(), 
          
          Expanded(
            child: ResponsiveWrapper(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) { return FadeTransition(opacity: animation, child: child); },
                child: KeyedSubtree(key: ValueKey<String>(_currentScreen), child: currentBody),
              ),
            ),
          ),
        ],
      ), 
      // Bottom Navigation ONLY shows on Mobile
      bottomNavigationBar: isDesktop ? null : _buildBottomNav(), 
    );
  }

  // ==========================================
  // Desktop-Specific Web Header
  // ==========================================
  Widget _buildDesktopHeader() {
    return Container(
      color: Colors.white,
      width: double.infinity,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // Top Pink Promo Bar
              Container(
                width: double.infinity, color: const Color(0xFFE91E63), padding: const EdgeInsets.symmetric(vertical: 6),
                child: const Text("Free Delivery for orders above KES 2,000 | T&Cs Apply", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              // Main Header Row (Logo, Delivery, Icons)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _currentScreen = 'shop'),
                      child: Row(
                        children: [
                          const Icon(Icons.local_pharmacy, color: Color(0xFFE91E63), size: 40),
                          const SizedBox(width: 8),
                          const Text('PharmaStore', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFE91E63))),
                        ]
                      ),
                    ),
                    Row(
                      children: [
                        // Fake Delivery Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Row(children: [Icon(Icons.flash_on, color: Colors.orange, size: 20), SizedBox(width: 8), Text("Express Delivery to\nNairobi", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]),
                        ),
                        const SizedBox(width: 32),
                        IconButton(
                          icon: Icon(isLoggedIn ? Icons.account_circle : Icons.person_outline, color: isLoggedIn ? Colors.green : Colors.black87, size: 28),
                          onPressed: () {
                            if (!isLoggedIn) {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())).then((_) {
                                setState(() => isLoggedIn = true); fetchOrders();
                              });
                            } else {
                              setState(() => _currentScreen = 'dashboard'); // Admin access
                            }
                          }
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF333333), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                          onPressed: () => setState(() => _currentScreen = 'cart'),
                          icon: const Icon(Icons.shopping_cart, size: 20),
                          label: Text(cart.length.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        )
                      ]
                    )
                  ]
                )
              ),
              const Divider(height: 1),
              // Navigation Links & Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Horizontal Web Links
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            if (_currentScreen != 'shop') setState(() => _currentScreen = 'shop');
                            // Scrolls down past the banner to the Categories section
                            Future.delayed(const Duration(milliseconds: 100), () => _mainScrollController.animateTo(450, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut));
                          }, 
                          child: const Text("Shop by Category", style: TextStyle(color: Colors.black87, fontSize: 15))
                        ),
                        const SizedBox(width: 16),
                        TextButton(
                          onPressed: () {
                            if (_currentScreen != 'shop') setState(() => _currentScreen = 'shop');
                            // Scrolls down to the All Products section
                            Future.delayed(const Duration(milliseconds: 100), () => _mainScrollController.animateTo(900, duration: const Duration(milliseconds: 800), curve: Curves.easeInOut));
                          }, 
                          child: const Text("All Products", style: TextStyle(color: Colors.black87, fontSize: 15))
                        ),
                        const SizedBox(width: 16),
                        TextButton(
                          onPressed: () {
                            _setCategory('All');
                            _showTopSnackbar('Showing all brands', color: Colors.green);
                          }, 
                          child: const Text("Shop by Brand", style: TextStyle(color: Colors.black87, fontSize: 15))
                        ),
                        const SizedBox(width: 16),
                        TextButton(
                          onPressed: () => setState(() => _currentScreen = 'track'), 
                          child: const Text("Track Order", style: TextStyle(color: Colors.black87, fontSize: 15))
                        ),
                      ]
                    ),
                    // Action Buttons
                    Row(
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF333333), foregroundColor: Colors.white, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                          onPressed: () => _showTopSnackbar('Telehealth coming soon!', color: Colors.blue), 
                          child: const Text("Speak to a Doctor", style: TextStyle(fontWeight: FontWeight.bold))
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF65B741), foregroundColor: Colors.white, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PrescriptionUploadScreen())), 
                          child: const Text("Upload a Prescription", style: TextStyle(fontWeight: FontWeight.bold))
                        ),
                      ]
                    )
                  ]
                )
              )
            ]
          )
        )
      )
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      toolbarHeight: 80,
      title: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => setState(() => _currentScreen = 'shop'),
                child: Row(
                  children: [
                    Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFFE91E63), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.local_pharmacy, color: Colors.white, size: 24)),
                    const SizedBox(width: 12), const Text('PharmaStore', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Color(0xFFE91E63))),
                  ],
                ),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      if (!isLoggedIn) {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())).then((_) {
                          setState(() => isLoggedIn = true); fetchOrders();
                        });
                      }
                    },
                    icon: Icon(isLoggedIn ? Icons.account_circle : Icons.person_outline, color: isLoggedIn ? Colors.green : const Color(0xFF003876)),
                    label: Text(isLoggedIn ? 'Admin' : 'Login', style: TextStyle(color: isLoggedIn ? Colors.green : const Color(0xFF003876), fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(width: 16),
                  TweenAnimationBuilder(
                    key: ValueKey(cart.length), tween: Tween<double>(begin: 0.7, end: 1.0), duration: const Duration(milliseconds: 500), curve: Curves.elasticOut, 
                    builder: (context, scale, child) { return Transform.scale(scale: scale, child: child); },
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF333333), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                      onPressed: () => setState(() => _currentScreen = 'cart'),
                      icon: const Icon(Icons.shopping_cart, color: Colors.white, size: 20),
                      label: Text(cart.length.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(70.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200), 
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: TextField(
                controller: _searchController, onChanged: _filterSearch,
                decoration: InputDecoration(hintText: 'Search 50,000+ medical items', filled: true, fillColor: Colors.grey[100], prefixIcon: const Icon(Icons.search, color: Colors.grey), contentPadding: const EdgeInsets.symmetric(vertical: 0), border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed, // Keeps all icons visible
          selectedItemColor: Colors.green, 
          unselectedItemColor: Colors.grey,
          currentIndex: 0, 
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: 'WishList'),
            BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_outlined), label: 'Cart'),
            BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Menu'),
          ],
          onTap: (index) {
            if (index == 0) setState(() => _currentScreen = 'shop');
            if (index == 1) setState(() => _currentScreen = 'wishlist');
            if (index == 2) setState(() => _currentScreen = 'cart');
            if (index == 3) {
              // If Admin, open dashboard. If Customer, open Tracker!
              setState(() => _currentScreen = isLoggedIn ? 'dashboard' : 'track'); 
            }
          },
        ),
      ),
    );
  }

  // ==========================================
  // The Wishlist Screen
  // ==========================================
  Widget _buildWishlistBody() {
    if (wishlist.isEmpty) {
      return const Center(child: Text('Your wishlist is empty!', style: TextStyle(fontSize: 18, color: Colors.grey)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, childAspectRatio: 0.75, crossAxisSpacing: 16, mainAxisSpacing: 16),
      itemCount: wishlist.length,
      itemBuilder: (context, index) {
        final med = wishlist[index];
        String? imageUrl = med['image'] != null ? (med['image'].toString().startsWith('http') ? med['image'] : 'http://127.0.0.1:8000${med['image']}') : null;

        return Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.pink[100]!)),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: Center(child: imageUrl != null ? Image.network(imageUrl, fit: BoxFit.contain) : const Icon(Icons.favorite, color: Colors.pink, size: 60))),
                    const SizedBox(height: 12), Text(med['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14), maxLines: 2),
                    const SizedBox(height: 8), Text('KES ${med['price']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ]
                )
              ),
              Positioned(top: 8, right: 8, child: GestureDetector(onTap: () => _toggleWishlist(med), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey[200]!)), child: const Icon(Icons.delete_outline, color: Colors.red, size: 20)))),
              Positioned(bottom: 12, right: 12, child: GestureDetector(onTap: () => _addToCart(med, isPos: false), child: Container(decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF65B741)), padding: const EdgeInsets.all(8.0), child: const Icon(Icons.shopping_cart, color: Colors.white, size: 20)))),
            ],
          ),
        );
      }
    );
  }

  // ==========================================
  // Live Order Tracking Screen
  // ==========================================
  Widget _buildTrackingBody() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Text('Track Your Delivery', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF003876))),
          const SizedBox(height: 8),
          const Text('Enter your Order ID to see live logistics updates.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 32),
          
          // The Search Bar
          Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _trackController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Enter Order ID (e.g. 12)', border: InputBorder.none, prefixIcon: Icon(Icons.search, color: Colors.grey)),
                  )
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF65B741), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () {
                    setState(() {
                      _trackError = '';
                      try {
                        _trackedOrder = orders.firstWhere((o) => o['id'].toString() == _trackController.text.trim());
                      } catch (e) {
                        _trackedOrder = null;
                        _trackError = 'Order not found. Please check your ID.';
                      }
                    });
                  },
                  child: const Text('Track', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                )
              ],
            ),
          ),
          
          if (_trackError.isNotEmpty) ...[const SizedBox(height: 24), Text(_trackError, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))],

          // The Live Visual Timeline!
          if (_trackedOrder != null) ...[
            const SizedBox(height: 48),
            Container(
              constraints: const BoxConstraints(maxWidth: 600),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.blue.withOpacity(0.2)), boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Order #${_trackedOrder!['id']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text('KES ${_trackedOrder!['total_price']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const Divider(height: 32),
                  
                  // The Logic to calculate the current step
                  Builder(
                    builder: (context) {
                      String status = _trackedOrder!['status'] ?? 'Processed';
                      int step = 0;
                      if (status == 'Dispatched') step = 1;
                      if (status == 'Delivered') step = 2;

                      return Column(
                        children: [
                          Row(
                            children: [
                              _buildTrackingNode(Icons.inventory, 'Processed', step >= 0, Colors.blue),
                              _buildTrackingLine(step >= 1),
                              _buildTrackingNode(Icons.local_shipping, 'Dispatched', step >= 1, Colors.orange),
                              _buildTrackingLine(step >= 2),
                              _buildTrackingNode(Icons.check_circle, 'Delivered', step >= 2, Colors.green),
                            ],
                          ),
                          const SizedBox(height: 32),
                          // Dynamic Status Message
                          Container(
                            width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                Icon(step == 0 ? Icons.info_outline : step == 1 ? Icons.motorcycle : Icons.celebration, color: const Color(0xFF003876)),
                                const SizedBox(width: 12),
                                Expanded(child: Text(
                                  step == 0 ? 'Your order has been received and is being packed by our pharmacists.' :
                                  step == 1 ? 'Your rider is on the way! Please keep your phone nearby.' :
                                  'This order has been successfully delivered. Stay healthy!',
                                  style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)
                                )),
                              ],
                            ),
                          )
                        ],
                      );
                    }
                  )
                ],
              ),
            )
          ]
        ],
      ),
    );
  }

  // Helper widget for the animated circles
  Widget _buildTrackingNode(IconData icon, String label, bool isActive, Color activeColor) {
    return Column(
      children: [
        AnimatedContainer(duration: const Duration(milliseconds: 500), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isActive ? activeColor : Colors.grey[200], shape: BoxShape.circle, boxShadow: isActive ? [BoxShadow(color: activeColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))] : []), child: Icon(icon, color: isActive ? Colors.white : Colors.grey, size: 28)),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? activeColor : Colors.grey)),
      ],
    );
  }

  // Helper widget for the connecting lines
  Widget _buildTrackingLine(bool isActive) {
    return Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 500), height: 4, margin: const EdgeInsets.only(bottom: 24), color: isActive ? Colors.green : Colors.grey[300]));
  }

  Widget _buildStoreBody(bool isDesktop) {
    if (isLoading) {
      return CustomScrollView(
        controller: _mainScrollController, 
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, childAspectRatio: 0.75, crossAxisSpacing: 16, mainAxisSpacing: 16),
              delegate: SliverChildBuilderDelegate(
                (context, index) => Shimmer.fromColors(baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!, child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)))), childCount: 12, 
              ),
            ),
          )
        ]
      );
    }
    
    if (errorMessage.isNotEmpty) return Center(child: Text(errorMessage, style: const TextStyle(color: Colors.red)));

    return CustomScrollView(
      controller: _mainScrollController,
      slivers: [
        // Dynamic Banners with Floating Search Card (Web)
        SliverToBoxAdapter(
          child: Stack(
            clipBehavior: Clip.none, 
            alignment: Alignment.bottomCenter,
            children: [
              SizedBox(
                height: isDesktop ? 350 : 220, 
                child: promoBanners.isEmpty 
                  ? const Center(child: Text('No active promos', style: TextStyle(color: Colors.grey)))
                  : PageView.builder(
                      controller: _bannerController,
                      itemCount: promoBanners.length,
                      itemBuilder: (context, index) {
                        final banner = promoBanners[index];
                        
                        int parseColor(dynamic c, int fallback) {
                          if (c == null) return fallback;
                          if (c is int) return c;
                          if (c is String && c.startsWith('0x')) return int.tryParse(c) ?? fallback;
                          return fallback;
                        }
                        
                        final color1 = Color(parseColor(banner['color1'], 0xFF003876));
                        final color2 = Color(parseColor(banner['color2'], 0xFF0056b3));
                        
                        String? bannerImageUrl = banner['image'] != null ? (banner['image'].toString().startsWith('http') ? banner['image'] : 'http://127.0.0.1:8000${banner['image']}') : null;

                        return AnimatedBuilder(
                          animation: _bannerController,
                          builder: (context, child) {
                            double value = 1.0;
                            if (_bannerController.position.haveDimensions) {
                              value = _bannerController.page! - index;
                              value = (1 - (value.abs() * 0.2)).clamp(0.8, 1.0); 
                            }
                            return Center(
                              child: SizedBox(
                                height: Curves.easeOut.transform(value) * (isDesktop ? 350 : 220), 
                                width: Curves.easeOut.transform(value) * (isDesktop ? 1200 : 800), 
                                child: child
                              ),
                            );
                          },
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 8, vertical: isDesktop ? 0 : 16),
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(isDesktop ? 0 : 20), 
                              image: bannerImageUrl != null ? DecorationImage(image: NetworkImage(bannerImageUrl), fit: BoxFit.cover) : null,
                              gradient: bannerImageUrl == null ? LinearGradient(colors: [color1, color2], begin: Alignment.topLeft, end: Alignment.bottomRight) : null, 
                              boxShadow: isDesktop ? [] : [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
                              color: const Color(0xFFFFC0CB), 
                            ),
                            child: bannerImageUrl == null ? Stack(children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(banner['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, height: 1.2)), const SizedBox(height: 12), Text(banner['subtitle'] ?? '', style: const TextStyle(color: Colors.yellow, fontSize: 20, fontWeight: FontWeight.bold))]),
                              Positioned(top: 0, right: 0, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Text(banner['badge'] ?? 'PROMO', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black))))
                            ]) : const SizedBox.shrink(), 
                          ),
                        );
                      },
                    ),
              ),
              
              // Floating Search Box ONLY for Desktop Web
              if (isDesktop)
                Positioned(
                  bottom: -40, 
                  child: Container(
                    width: 600,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("What Are You Looking For?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            TextButton.icon(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PrescriptionUploadScreen())), 
                              icon: const Icon(Icons.receipt_long, color: Colors.green), 
                              label: const Text("Order With Prescription", style: TextStyle(color: Colors.green))
                            )
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _searchController, 
                          onChanged: _filterSearch, 
                          onSubmitted: (value) => _filterSearch(value), 
                          decoration: InputDecoration(
                            hintText: 'Search for Medication & Products.', 
                            filled: true, 
                            fillColor: Colors.grey[100], 
                            suffixIcon: Container(
                              margin: const EdgeInsets.all(4), 
                              decoration: BoxDecoration(color: const Color(0xFFE91E63), borderRadius: BorderRadius.circular(30)), 
                              child: IconButton(
                                icon: const Icon(Icons.search, color: Colors.white), 
                                onPressed: () {
                                  _filterSearch(_searchController.text);
                                  _showTopSnackbar('Searching...', color: Colors.green);
                                }
                              )
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none)
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        // Adds a spacer to make room for the floating box on web
        if (isDesktop) const SliverToBoxAdapter(child: SizedBox(height: 60)),
        
        // Hide the Mobile Action Buttons if on Desktop (since they are in the header now)
        if (!isDesktop) 
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF333333), foregroundColor: Colors.white, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: () => _showTopSnackbar('Telehealth coming soon!', color: Colors.blue), 
                      child: const Text("Speak to Doctor", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))
                    )
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF65B741), foregroundColor: Colors.white, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PrescriptionUploadScreen())), 
                      child: const Text("Upload Rx", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))
                    )
                  ),
                ]
              )
            )
          ),

        const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0), child: Text('Top Categories', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                bool isSelected = _selectedCategory == cat['name'];
                
                return GestureDetector(
                  onTap: () => _setCategory(cat['name']), 
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: SizedBox(
                      width: 90, 
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 80, height: 80, 
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFE91E63) : Colors.white, 
                              borderRadius: BorderRadius.circular(16), 
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
                            ), 
                            child: Icon(cat['icon'], color: isSelected ? Colors.white : const Color(0xFFE91E63), size: 40)
                          ),
                          const SizedBox(height: 8), 
                          Text(cat['name'], textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: const Color(0xFF003876))),
                        ]
                      )
                    ),
                  ),
                );
              }
            ),
          ),
        ),
        const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 16.0), child: Text('Health Bundles & Offers', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
        SliverToBoxAdapter(
          child: Container(
            height: 280, color: const Color(0xFF90B4CE).withOpacity(0.2), 
            child: ListView.builder(
              scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(24), itemCount: filteredMedicines.length > 5 ? 5 : filteredMedicines.length,
              itemBuilder: (context, index) {
                final med = filteredMedicines[index];
                String? imageUrl = med['image'] != null ? (med['image'].toString().startsWith('http') ? med['image'] : 'http://127.0.0.1:8000${med['image']}') : null;

                return GestureDetector(
                  onTap: () => _showProductDetails(med, heroTag: 'med_image_${med['id']}'), 
                  child: Container(
                    width: 180, margin: const EdgeInsets.only(right: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
                    child: Stack(children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0), 
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            Expanded(flex: 3, child: Center(child: Hero(tag: 'med_image_${med['id']}', child: imageUrl != null ? Image.network(imageUrl, fit: BoxFit.contain) : const Icon(Icons.medication, color: Colors.grey, size: 60)))),
                            const SizedBox(height: 12), Text(med['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 8), 
                            if (med['is_on_offer'] == true) 
                              Text('KES ${(double.parse(med['price'].toString()) * (1 + (med['discount_percentage'] / 100))).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, decoration: TextDecoration.lineThrough, color: Colors.grey)),
                            Text('KES ${med['price']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          ]
                        )
                      ),
                      Positioned(
                        top: 8, right: 8, 
                        child: GestureDetector(
                          onTap: () => _toggleWishlist(med), 
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey[200]!)),
                            child: Icon(
                              wishlist.any((item) => item['id'] == med['id']) ? Icons.favorite : Icons.favorite_border, 
                              color: const Color(0xFFE91E63), size: 20
                            )
                          )
                        )
                      ),
                      if (med['is_on_offer'] == true && med['discount_percentage'] != null && med['discount_percentage'] > 0)
                        Positioned(
                          top: 0, left: 0, 
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                            decoration: const BoxDecoration(color: Colors.red, borderRadius: BorderRadius.only(topLeft: Radius.circular(12), bottomRight: Radius.circular(12))), 
                            child: Text('${med['discount_percentage']}% OFF', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))
                          )
                        ),
                      Positioned(
                        bottom: 12, right: 12, 
                        child: GestureDetector(
                          onTap: () => _addToCart(med, isPos: false), 
                          child: Container(
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF003876)), 
                            padding: const EdgeInsets.all(8.0), 
                            child: const Icon(Icons.add, color: Colors.white, size: 24)
                          )
                        )
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ),
        const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 16.0), child: Text('All Medical Products', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, childAspectRatio: 0.75, crossAxisSpacing: 16, mainAxisSpacing: 16),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final med = filteredMedicines[index];
                String? imageUrl = med['image'] != null ? (med['image'].toString().startsWith('http') ? med['image'] : 'http://127.0.0.1:8000${med['image']}') : null;

                return GestureDetector(
                  onTap: () => _showProductDetails(med, heroTag: 'med_image_all_${med['id']}'), 
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0), 
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, 
                            children: [
                              Expanded(flex: 3, child: Center(child: Hero(tag: 'med_image_all_${med['id']}', child: imageUrl != null ? Image.network(imageUrl, fit: BoxFit.contain) : const Icon(Icons.medication, color: Colors.grey, size: 60)))),
                              const SizedBox(height: 12), Text(med['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14), maxLines: 2),
                              const SizedBox(height: 8), 
                              if (med['is_on_offer'] == true) 
                                Text('KES ${(double.parse(med['price'].toString()) * (1 + (med['discount_percentage'] / 100))).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, decoration: TextDecoration.lineThrough, color: Colors.grey)),
                              Text('KES ${med['price']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            ]
                          )
                        ),
                        Positioned(
                          top: 8, right: 8, 
                          child: GestureDetector(
                            onTap: () => _toggleWishlist(med), 
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey[200]!)),
                              child: Icon(
                                wishlist.any((item) => item['id'] == med['id']) ? Icons.favorite : Icons.favorite_border, 
                                color: const Color(0xFFE91E63), size: 20
                              )
                            )
                          )
                        ),
                        if (med['is_on_offer'] == true && med['discount_percentage'] != null && med['discount_percentage'] > 0)
                          Positioned(
                            top: 0, left: 0, 
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                              decoration: const BoxDecoration(color: Colors.red, borderRadius: BorderRadius.only(topLeft: Radius.circular(12), bottomRight: Radius.circular(12))), 
                              child: Text('${med['discount_percentage']}% OFF', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))
                            )
                          ),
                        Positioned(
                          bottom: 12, right: 12, 
                          child: GestureDetector(
                            onTap: () => _addToCart(med, isPos: false), 
                            child: Container(
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF003876)), 
                              padding: const EdgeInsets.all(8.0), 
                              child: const Icon(Icons.add, color: Colors.white, size: 24)
                            )
                          )
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: filteredMedicines.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
        SliverToBoxAdapter(
          child: Container(
            color: const Color(0xFF0056b3), padding: const EdgeInsets.all(40), 
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceAround, 
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    Text('Customer Service', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), 
                    SizedBox(height: 16), 
                    Text('Service and Warranty', style: TextStyle(color: Colors.white70)), 
                    SizedBox(height: 8), 
                    Text('Returns and Exchanges', style: TextStyle(color: Colors.white70)), 
                    SizedBox(height: 8), 
                    Text('Secured Online Payment', style: TextStyle(color: Colors.white70))
                  ]
                ), 
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    Text('About PharmaStore', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), 
                    SizedBox(height: 16), 
                    Text('About Us', style: TextStyle(color: Colors.white70)), 
                    SizedBox(height: 8), 
                    Text('Pharmacy Locations', style: TextStyle(color: Colors.white70)), 
                    SizedBox(height: 8), 
                    Text('Health & Safety Policies', style: TextStyle(color: Colors.white70))
                  ]
                ), 
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    const Text('Need Help?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), 
                    SizedBox(height: 16), 
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
                      decoration: BoxDecoration(color: const Color(0xFF003876), borderRadius: BorderRadius.circular(8)), 
                      child: const Row(
                        children: [
                          Icon(Icons.phone, color: Colors.white), 
                          SizedBox(width: 8), 
                          Text('0800 221 322', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))
                        ]
                      )
                    )
                  ]
                )
              ]
            )
          )
        ),
        SliverToBoxAdapter(
          child: Container(
            color: const Color(0xFF003876), padding: const EdgeInsets.all(16), 
            child: const Center(
              child: Text('© 2026 PharmaStore Kenya. All rights reserved.', style: TextStyle(color: Colors.white54))
            )
          )
        )
      ],
    );
  }

  Widget _buildCartBody() {
    if (cart.isEmpty) return const Center(child: Text('Your cart is empty!', style: TextStyle(fontSize: 18, color: Colors.grey)));
    double total = 0;
    for (var item in cart) { total += double.parse(item['price'].toString()) * item['cart_quantity']; }
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: cart.length, 
            itemBuilder: (context, index) { 
              final item = cart[index]; 
              return ListTile(
                leading: const Icon(Icons.medication, color: Color(0xFF003876)), 
                title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)), 
                subtitle: Text('Qty: ${item['cart_quantity']}'), 
                trailing: Text('KES ${double.parse(item['price'].toString()) * item['cart_quantity']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))
              ); 
            }
          )
        ),
        Container(
          padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]), 
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                children: [
                  const Text('Total:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), 
                  Text('KES $total', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF003876)))
                ]
              ), 
              const SizedBox(height: 16), 
              SizedBox(
                width: double.infinity, height: 50, 
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green), 
                  onPressed: _showPaymentDialog, 
                  child: const Text('Checkout & Dispatch Order', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold))
                )
              )
            ]
          )
        )
      ],
    );
  }

  Widget _buildDashboardBody() {
    double totalRevenue = 0; 
    double pendingRevenue = 0; 
    int deliveredCount = 0;
    
    double cashRevenue = 0;
    double mpesaRevenue = 0;
    double creditRevenue = 0;

    List<dynamic> lowStockItems = medicines.where((med) => (med['stock_quantity'] ?? 0) < 10).toList();

    for (var order in orders) { 
      double price = double.parse(order['total_price'].toString()); 
      totalRevenue += price; 
      
      if (order['payment_status'] == 'Pending' || order['payment_method'] == 'Credit' || order['payment_method'] == 'Pay on Delivery') {
        pendingRevenue += price;
      }
      if (order['status'] == 'Delivered') {
        deliveredCount += 1;
      }

      if (order['payment_method'] == 'Cash') cashRevenue += price;
      if (order['payment_method'] == 'M-Pesa') mpesaRevenue += price;
      if (order['payment_method'] == 'Credit') creditRevenue += price;
    }
    
    return Column(
      children: [
        // Dashboard Header with PDF Download Button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Admin Overview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF003876))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003876), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: _generateAdminReport,
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                label: const Text('Download PDF Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),

        if (lowStockItems.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              border: Border.all(color: Colors.red.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CRITICAL: Low Stock Alert', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${lowStockItems.length} items are running dangerously low.', style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (context) => Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
                        child: Column(
                          children: [
                            const Text('Restock Required', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
                            const SizedBox(height: 16),
                            Expanded(
                              child: ListView.builder(
                                itemCount: lowStockItems.length,
                                itemBuilder: (context, index) {
                                  final item = lowStockItems[index];
                                  return ListTile(
                                    leading: const Icon(Icons.medication, color: Colors.grey),
                                    title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                    trailing: Text('${item['stock_quantity']} Left', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                                  );
                                },
                              ),
                            )
                          ],
                        ),
                      )
                    );
                  },
                  child: const Text('View List'),
                )
              ],
            ),
          ),
          
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(24), 
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF003876), Color(0xFF0056b3)]), 
                    borderRadius: BorderRadius.circular(16), 
                    boxShadow: [BoxShadow(color: const Color(0xFF003876).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]
                  ), 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      const Text('Gross Revenue Volume', style: TextStyle(color: Colors.white70, fontSize: 16)), 
                      const SizedBox(height: 8), 
                      Text('KES $totalRevenue', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))
                    ]
                  )
                ),
              ),
              const SizedBox(width: 16),
              if (totalRevenue > 0)
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 120,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white, 
                      borderRadius: BorderRadius.circular(16), 
                      border: Border.all(color: Colors.grey[200]!)
                    ),
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2, 
                        centerSpaceRadius: 20,
                        sections: [
                          if (cashRevenue > 0) 
                            PieChartSectionData(color: Colors.green, value: cashRevenue, title: 'Cash\n${((cashRevenue/totalRevenue)*100).toInt()}%', radius: 40, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                          if (mpesaRevenue > 0) 
                            PieChartSectionData(color: Colors.blue, value: mpesaRevenue, title: 'M-Pesa\n${((mpesaRevenue/totalRevenue)*100).toInt()}%', radius: 40, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                          if (creditRevenue > 0) 
                            PieChartSectionData(color: Colors.orange, value: creditRevenue, title: 'Credit\n${((creditRevenue/totalRevenue)*100).toInt()}%', radius: 40, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                        ]
                      )
                    )
                  )
                )
            ],
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0), 
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16), 
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withOpacity(0.3))), 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      const Icon(Icons.pending_actions, color: Colors.orange), 
                      const SizedBox(height: 8), 
                      const Text('Pending Cash', style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)), 
                      Text('KES $pendingRevenue', style: const TextStyle(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.bold))
                    ]
                  )
                )
              ), 
              const SizedBox(width: 12), 
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16), 
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.3))), 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green), 
                      const SizedBox(height: 8), 
                      const Text('Delivered', style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)), 
                      Text('$deliveredCount Orders', style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold))
                    ]
                  )
                )
              )
            ]
          )
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0), 
          child: Align(
            alignment: Alignment.centerLeft, 
            child: Text('Live Dispatch Tracker', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
          )
        ),
        Expanded(
          child: orders.isEmpty 
            ? const Center(child: Text('No orders yet.', style: TextStyle(color: Colors.grey))) 
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16), 
                itemCount: orders.length, 
                itemBuilder: (context, index) { 
                  final order = orders[orders.length - 1 - index]; 
                  final status = order['status'] ?? 'Processed'; 
                  final paymentMethod = order['payment_method'] ?? 'Cash'; 
                  
                  Color badgeColor = Colors.blue; 
                  if (status == 'Dispatched') badgeColor = Colors.orange; 
                  if (status == 'Delivered') badgeColor = Colors.green; 
                  
                  return InkWell(
                    onTap: () => _showDispatchControlPanel(order),
                    child: Card(
                      elevation: 0, 
                      margin: const EdgeInsets.only(bottom: 12), 
                      shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(12)), 
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16), 
                        leading: Container(
                          padding: const EdgeInsets.all(12), 
                          decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), shape: BoxShape.circle), 
                          child: Icon(Icons.local_shipping, color: badgeColor)
                        ), 
                        title: Text('Order #${order['id']} - ${order['quantity_sold']} Items', style: const TextStyle(fontWeight: FontWeight.bold)), 
                        subtitle: Text('KES ${order['total_price']} • $paymentMethod\nTap to update status', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w500)), 
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min, 
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                              decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: badgeColor)), 
                              child: Text(status, style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12))
                            ), 
                            const SizedBox(width: 8), 
                            IconButton(
                              icon: const Icon(Icons.print, color: Color(0xFF003876)), 
                              tooltip: 'Print Dispatch Receipt', 
                              onPressed: () => _printReceipt(order)
                            )
                          ]
                        )
                      )
                    )
                  ); 
                }
              )
        ),
      ],
    );
  }

  Widget _buildPOSBody() {
    double posTotal = 0;
    for (var item in posCart) { posTotal += double.parse(item['price'].toString()) * item['cart_quantity']; }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0), 
          child: TextField(
            controller: _posSearchController, 
            onChanged: _filterSearch, 
            decoration: InputDecoration(
              hintText: 'Scan or search item...', 
              filled: true, 
              fillColor: Colors.white, 
              prefixIcon: const Icon(Icons.qr_code_scanner, color: Color(0xFF003876)), 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))
            )
          )
        ),
        Expanded(
          flex: 2, 
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16), 
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 150, childAspectRatio: 0.9, crossAxisSpacing: 8, mainAxisSpacing: 8), 
            itemCount: filteredMedicines.length, 
            itemBuilder: (context, index) { 
              final med = filteredMedicines[index]; 
              return InkWell(
                onTap: () => _addToCart(med, isPos: true), 
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)), 
                  child: Padding(
                    padding: const EdgeInsets.all(8.0), 
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center, 
                      children: [
                        const Icon(Icons.medication, color: Color(0xFF003876), size: 30), 
                        const SizedBox(height: 8), 
                        Text(med['name'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 2), 
                        const SizedBox(height: 4), 
                        Text('KES ${med['price']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                      ]
                    )
                  )
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
              : ListView.builder(
                  itemCount: posCart.length, 
                  itemBuilder: (context, index) { 
                    final item = posCart[index]; 
                    return ListTile(
                      title: Text(item['name'], style: const TextStyle(fontSize: 14)), 
                      trailing: Text('${item['cart_quantity']}x  |  KES ${double.parse(item['price'].toString()) * item['cart_quantity']}')
                    ); 
                  }
                )
          )
        ),
        Container(
          width: double.infinity, height: 80, color: Colors.black87, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), 
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green), 
            onPressed: posCart.isEmpty ? null : () => _processCheckout(isPos: true), 
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
              children: [
                const Text('CASH SALE', style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)), 
                Text('KES $posTotal', style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold))
              ]
            )
          ) 
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
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/login/'), 
        body: {'username': _phoneController.text, 'password': _passwordController.text}
      );
      setState(() => _isLoading = false);
      if (response.statusCode == 200) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin Access Granted!'), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid credentials.'), backgroundColor: Colors.red));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot connect to server.'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, leading: const BackButton(color: Color(0xFF003876))),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(16), 
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.admin_panel_settings, size: 60, color: Color(0xFF003876)),
                  const SizedBox(height: 16),
                  const Text('Admin Login', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF003876))),
                  const SizedBox(height: 32),
                  
                  TextField(
                    controller: _phoneController, 
                    decoration: InputDecoration(labelText: 'Phone Number', prefixIcon: const Icon(Icons.phone), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController, 
                    obscureText: true, 
                    decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))
                  ),
                  const SizedBox(height: 32),
                  
                  SizedBox(
                    width: double.infinity, height: 50, 
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF003876), 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))
                      ), 
                      onPressed: _isLoading ? null : _login, 
                      child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Login', style: TextStyle(fontSize: 16, color: Colors.white))
                    )
                  ),
                  const SizedBox(height: 16),
                  
                  TextButton(
                    onPressed: () { 
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const RegistrationScreen())); 
                    }, 
                    child: const Text('New Vendor? Register Here', style: TextStyle(color: Color(0xFF003876), fontWeight: FontWeight.bold))
                  )
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
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _ppbLicenseController = TextEditingController();
  final TextEditingController _countyLicenseController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'pharmacy_name': _nameController.text,
          'phone_number': _phoneController.text,
          'national_id': _idController.text,
          'ppb_license': _ppbLicenseController.text,
          'county_license': _countyLicenseController.text,
          'password': _passwordController.text,
        }),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration Pending Approval!'), backgroundColor: Colors.green));
        Navigator.pop(context); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration failed. Check details.'), backgroundColor: Colors.red));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Server Error. Cannot connect to Django.'), backgroundColor: Colors.red));
    }
  }

  Widget _buildTextField({required String label, required TextEditingController controller, required IconData icon, bool isPassword = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF003876)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (value) => value!.isEmpty ? 'Required' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        leading: const BackButton(color: Color(0xFF003876)),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.store, size: 60, color: Color(0xFF003876)),
                  const SizedBox(height: 16),
                  const Text('Vendor Registration', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF003876))),
                  const SizedBox(height: 32),
                  
                  _buildTextField(label: 'Pharmacy Name', controller: _nameController, icon: Icons.local_pharmacy),
                  const SizedBox(height: 16),
                  _buildTextField(label: 'Phone Number', controller: _phoneController, icon: Icons.phone),
                  const SizedBox(height: 16),
                  _buildTextField(label: 'National ID', controller: _idController, icon: Icons.badge),
                  const SizedBox(height: 16),
                  _buildTextField(label: 'PPB License', controller: _ppbLicenseController, icon: Icons.medical_information),
                  const SizedBox(height: 16),
                  _buildTextField(label: 'County License', controller: _countyLicenseController, icon: Icons.account_balance),
                  const SizedBox(height: 16),
                  _buildTextField(label: 'Password', controller: _passwordController, icon: Icons.lock, isPassword: true),
                  
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003876), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
                      onPressed: _isLoading ? null : _submitRegistration,
                      child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Application', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  )
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
class PrescriptionUploadScreen extends StatefulWidget {
  const PrescriptionUploadScreen({super.key});

  @override
  State<PrescriptionUploadScreen> createState() => _PrescriptionUploadScreenState();
}

class _PrescriptionUploadScreenState extends State<PrescriptionUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  
  XFile? _selectedImage;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  Future<void> _submitPrescription() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please attach a photo of your prescription.'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Because we are sending an Image AND Text, we use a MultipartRequest
      var request = http.MultipartRequest('POST', Uri.parse('http://127.0.0.1:8000/api/prescriptions/upload'));
      
      // Attach the text data
      request.fields['patient_name'] = _nameController.text;
      request.fields['phone_number'] = _phoneController.text;
      request.fields['delivery_address'] = _addressController.text;

      // Attach the image file safely for both Web and Mobile
      var imageBytes = await _selectedImage!.readAsBytes();
      var multipartFile = http.MultipartFile.fromBytes('prescription_image', imageBytes, filename: _selectedImage!.name);
      request.files.add(multipartFile);

      // Send to Django
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      setState(() => _isLoading = false);

      if (response.statusCode == 201) {
        // Success! Go back to the shop
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prescription securely sent to our Pharmacists!'), backgroundColor: Colors.green));
          Navigator.pop(context); 
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to upload. Please try again.'), backgroundColor: Colors.red));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection error.'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        leading: const BackButton(color: Color(0xFF003876)),
        title: const Text('Upload Prescription', style: TextStyle(color: Color(0xFF003876), fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withOpacity(0.3))),
                    child: const Row(
                      children: [
                        Icon(Icons.security, color: Colors.blue),
                        SizedBox(width: 12),
                        Expanded(child: Text('Your prescription is securely encrypted and will only be viewed by a licensed pharmacist.', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  const Text('1. Patient Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF003876))),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController, decoration: InputDecoration(labelText: 'Full Name', prefixIcon: const Icon(Icons.person), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                    validator: (value) => value!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController, decoration: InputDecoration(labelText: 'Phone Number', prefixIcon: const Icon(Icons.phone), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                    validator: (value) => value!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController, maxLines: 2, decoration: InputDecoration(labelText: 'Delivery Address', prefixIcon: const Icon(Icons.location_on), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                    validator: (value) => value!.isEmpty ? 'Required' : null,
                  ),
                  
                  const SizedBox(height: 32),
                  const Text('2. Attach Doctor\'s Note', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF003876))),
                  const SizedBox(height: 16),
                  
                  // Image Picker Box
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: double.infinity, height: 150,
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid, width: 2)),
                      child: _selectedImage == null 
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, size: 40, color: Colors.grey), SizedBox(height: 8),
                              Text('Tap to take a photo or select from gallery', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
                            ]
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 30), const SizedBox(width: 12),
                              Text('Image Selected: ${_selectedImage!.name}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity, height: 60,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF65B741), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                      onPressed: _isLoading ? null : _submitPrescription,
                      icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.send, color: Colors.white),
                      label: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Securely Submit Prescription', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  )
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
class MpesaSimulationDialog extends StatefulWidget {
  final VoidCallback onComplete;
  const MpesaSimulationDialog({super.key, required this.onComplete});

  @override
  State<MpesaSimulationDialog> createState() => _MpesaSimulationDialogState();
}

class _MpesaSimulationDialogState extends State<MpesaSimulationDialog> {
  String statusMessage = "Initiating Secure Connection...";
  IconData currentIcon = Icons.security;
  bool isProcessing = true;

  @override
  void initState() {
    super.initState();
    _runSimulation();
  }

  Future<void> _runSimulation() async {
    // Step 1: Connecting
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() {
      statusMessage = "Sending STK Push to your phone...";
      currentIcon = Icons.smartphone;
    });

    // Step 2: Waiting for User PIN
    await Future.delayed(const Duration(milliseconds: 2000));
    if (mounted) setState(() {
      statusMessage = "Please enter your M-PESA PIN...";
      currentIcon = Icons.dialpad;
    });

    // Step 3: Payment Confirmed!
    await Future.delayed(const Duration(milliseconds: 3500));
    if (mounted) setState(() {
      statusMessage = "Payment Received Successfully!";
      currentIcon = Icons.check_circle;
      isProcessing = false;
    });

    // Step 4: Close the dialog and trigger the Django API
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      Navigator.pop(context); 
      widget.onComplete(); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 20,
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bouncing/Changing M-Pesa Icon
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: Container(
                key: ValueKey<IconData>(currentIcon),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: const Color(0xFF4CAF50).withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(currentIcon, size: 60, color: const Color(0xFF4CAF50)),
              ),
            ),
            const SizedBox(height: 24),
            const Text('M-PESA Express', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))),
            const SizedBox(height: 24),
            
            // Loading Spinner (Hides when done)
            if (isProcessing) const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50))),
            if (isProcessing) const SizedBox(height: 24),
            
            // Dynamic Status Text
            Text(statusMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}