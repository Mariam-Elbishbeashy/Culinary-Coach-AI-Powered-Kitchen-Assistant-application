import 'package:culinary_coach_app/features/shop/presentation/screens/track_order.dart';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../../filter/widgets/custom_image_cache.dart';

class _MapZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFFF4A32D), size: 22),
      ),
    );
  }
}

class CheckoutScreen extends StatefulWidget {
  final double subtotal;
  final int itemCount;
  final List<Map<String, dynamic>> cartItems;
  final String? checkoutCartId;

  const CheckoutScreen({
    super.key,
    required this.subtotal,
    required this.itemCount,
    required this.cartItems,
    this.checkoutCartId,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  int currentStep = 0;
  bool isPlacingOrder = false;
  String selectedDelivery = 'express';
  String selectedPaymentMethod = 'card';

  DeliveryAddress selectedAddress = const DeliveryAddress(
    title: 'Home',
    address: '123 Green St, Cairo, Egypt',
    latitude: 30.0444,
    longitude: 31.2357,
  );

  final TextEditingController cardNumberController = TextEditingController();
  final TextEditingController cardholderNameController = TextEditingController();
  final TextEditingController expiryController = TextEditingController();
  final TextEditingController cvvController = TextEditingController();

  // Same marketplace location used by Checkout and Track Order.
  // Change these values only here if your real marketplace/warehouse changes.
  static const String _marketName = 'Culinary Market';
  static const LatLng _marketLocation = LatLng(30.0444, 31.2357);

  double get deliveryDistanceKm {
    final distance = const Distance();
    return distance.as(
      LengthUnit.Kilometer,
      _marketLocation,
      LatLng(selectedAddress.latitude, selectedAddress.longitude),
    );
  }

  List<DeliveryOption> get deliveryOptions {
    final km = deliveryDistanceKm;

    final standardFee = (15 + (km * 4)).clamp(20.0, 80.0).toDouble();
    final expressFee = (25 + (km * 6)).clamp(35.0, 130.0).toDouble();

    return [
      DeliveryOption(
        id: 'standard',
        title: 'Standard Delivery',
        time: km <= 5 ? '35-60 min' : '60-90 min',
        fee: standardFee,
      ),
      DeliveryOption(
        id: 'express',
        title: 'Express Delivery',
        time: km <= 5 ? '15-30 min' : '30-50 min',
        fee: expressFee,
      ),
    ];
  }

  DeliveryOption get selectedDeliveryOption {
    return deliveryOptions.firstWhere(
          (option) => option.id == selectedDelivery,
      orElse: () => deliveryOptions.first,
    );
  }

  double get deliveryFee => selectedDeliveryOption.fee;
  String get estimatedDeliveryTime => selectedDeliveryOption.time;

  int _maxMinutesFromDeliveryTime(String value) {
    final numbers = RegExp(r'\d+').allMatches(value).map((m) => int.tryParse(m.group(0) ?? '') ?? 0).where((n) => n > 0).toList();
    if (numbers.isEmpty) return selectedDelivery == 'express' ? 30 : 60;
    return numbers.reduce(math.max);
  }

  String _formatClockTime(DateTime time) {
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }

  String get estimatedArrivalTime {
    final arrival = DateTime.now().add(Duration(minutes: _maxMinutesFromDeliveryTime(estimatedDeliveryTime)));
    return _formatClockTime(arrival);
  }

  // Egyptian Pound prices (EGP)
  double get discount => 20.0;
  double get total => widget.subtotal + deliveryFee - discount;

  Future<void> nextStep() async {
    if (isPlacingOrder) return;

    if (currentStep < 2) {
      setState(() => currentStep++);
      return;
    }

    if (_validatePayment()) {
      await _placeOrderAndSaveToFirestore();
    }
  }

  bool _validatePayment() {
    FocusScope.of(context).unfocus();

    if (selectedPaymentMethod == 'cash') {
      return true;
    }

    if (selectedPaymentMethod == 'wallet') {
      return true;
    }

    final cardNumber = cardNumberController.text.replaceAll(RegExp(r'\D'), '');
    final cardholderName = cardholderNameController.text.trim();
    final expiry = expiryController.text.trim();
    final cvv = cvvController.text.trim();

    if (cardNumber.isEmpty) {
      _showValidationMessage('Please enter the card number.');
      return false;
    }

    if (cardNumber.length < 13 || cardNumber.length > 19 || !_passesLuhnCheck(cardNumber)) {
      _showValidationMessage('Please enter a valid card number.');
      return false;
    }

    if (cardholderName.isEmpty) {
      _showValidationMessage('Please enter the cardholder name.');
      return false;
    }

    if (!RegExp(r"^[A-Za-z][A-Za-z .'-]{2,}$").hasMatch(cardholderName)) {
      _showValidationMessage('Please enter a valid cardholder name.');
      return false;
    }

    if (!_isValidExpiryDate(expiry)) {
      _showValidationMessage('Please enter a valid future expiry date.');
      return false;
    }

    if (!RegExp(r'^\d{3,4}$').hasMatch(cvv)) {
      _showValidationMessage('Please enter a valid CVV.');
      return false;
    }

    return true;
  }

  bool _passesLuhnCheck(String number) {
    int sum = 0;
    bool shouldDouble = false;

    for (int i = number.length - 1; i >= 0; i--) {
      int digit = int.parse(number[i]);
      if (shouldDouble) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      shouldDouble = !shouldDouble;
    }

    return sum % 10 == 0;
  }

  bool _isValidExpiryDate(String value) {
    final match = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(value);
    if (match == null) return false;

    final month = int.tryParse(match.group(1)!);
    final year = int.tryParse(match.group(2)!);
    if (month == null || year == null || month < 1 || month > 12) {
      return false;
    }

    final fullYear = 2000 + year;
    final lastDayOfExpiryMonth = DateTime(fullYear, month + 1, 0, 23, 59, 59);
    return lastDayOfExpiryMonth.isAfter(DateTime.now());
  }

  void _showValidationMessage(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFF4A32D),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    cardNumberController.dispose();
    cardholderNameController.dispose();
    expiryController.dispose();
    cvvController.dispose();
    super.dispose();
  }

  void prevStep() {
    if (currentStep > 0) {
      setState(() => currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Map<String, dynamic> _safePaymentInfo() {
    if (selectedPaymentMethod == 'card') {
      final digitsOnly = cardNumberController.text.replaceAll(RegExp(r'\D'), '');
      return {
        'method': 'card',
        'status': 'validated_only',
        'cardLast4': digitsOnly.length >= 4 ? digitsOnly.substring(digitsOnly.length - 4) : '',
        'cardholderName': cardholderNameController.text.trim(),
        'expiry': expiryController.text.trim(),
      };
    }

    return {
      'method': selectedPaymentMethod,
      'status': selectedPaymentMethod == 'cash' ? 'cash_on_delivery' : 'selected',
    };
  }


  static const List<String> _driverNames = [
    'Michael Johnson',
    'Omar Hassan',
    'Ahmed Samir',
    'Youssef Ali',
    'Karim Mostafa',
    'Hassan Adel',
    'Mina Nabil',
    'Ibrahim Tarek',
  ];

  String _driverNameForOrder(String orderId) {
    final clean = orderId.replaceAll(RegExp(r'[^0-9]'), '');
    final number = int.tryParse(clean);
    if (number == null) return _driverNames.first;
    return _driverNames[number % _driverNames.length];
  }

  Future<void> _placeOrderAndSaveToFirestore() async {
    final userId = _currentUserId;
    if (userId == null) {
      _showValidationMessage('Please sign in before placing your order.');
      return;
    }

    if (widget.cartItems.isEmpty) {
      _showValidationMessage('Your cart is empty.');
      return;
    }

    setState(() => isPlacingOrder = true);

    final now = DateTime.now();
    final orderId = '#ORD${now.millisecondsSinceEpoch.toString().substring(7, 13)}';
    final orderCreatedAtMillis = now.millisecondsSinceEpoch;
    final driverName = _driverNameForOrder(orderId);

    final orderData = {
      'orderId': orderId,
      'userId': userId,
      'checkoutCartId': widget.checkoutCartId,
      'items': widget.cartItems,
      'itemCount': widget.itemCount,
      'subtotal': widget.subtotal,
      'discount': discount,
      'deliveryFee': deliveryFee,
      'total': total,
      'currency': 'EGP',
      'payment': _safePaymentInfo(),
      'delivery': {
        'addressTitle': selectedAddress.title,
        'address': selectedAddress.address,
        'latitude': selectedAddress.latitude,
        'longitude': selectedAddress.longitude,
        'optionId': selectedDelivery,
        'optionTitle': selectedDeliveryOption.title,
        'estimatedDelivery': estimatedDeliveryTime,
        'estimatedArrivalClock': estimatedArrivalTime,
        'distanceKm': deliveryDistanceKm,
      },
      'market': {
        'name': _marketName,
        'latitude': _marketLocation.latitude,
        'longitude': _marketLocation.longitude,
      },
      'driver': {
        'name': driverName,
        'rating': 4.9,
      },
      'status': 'confirmed',
      'orderCreatedAtMillis': orderCreatedAtMillis,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      final userOrderRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('shop_orders')
          .doc(orderId.replaceAll('#', ''));

      final globalOrderRef = FirebaseFirestore.instance
          .collection('shop_orders')
          .doc(orderId.replaceAll('#', ''));

      final activeCartSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('shop_cart_items')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      batch.set(userOrderRef, orderData);
      batch.set(globalOrderRef, orderData);

      // After the order is saved, the active cart must become empty so the
      // next checkout starts a new order. The old cart is already copied
      // inside the saved order document as `items`.
      for (final cartDoc in activeCartSnapshot.docs) {
        batch.delete(cartDoc.reference);
      }

      if (widget.checkoutCartId != null && widget.checkoutCartId!.isNotEmpty) {
        final cartRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('checkout_carts')
            .doc(widget.checkoutCartId);
        batch.set(cartRef, {
          'status': 'ordered',
          'orderId': orderId,
          'orderedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();

      if (!mounted) return;
      _showOrderSuccess(
        orderId: orderId,
        orderCreatedAtMillis: orderCreatedAtMillis,
        driverName: driverName,
      );
    } catch (e) {
      debugPrint('Error saving order: $e');
      if (!mounted) return;
      _showValidationMessage('Could not save your order. Please try again.');
    } finally {
      if (mounted) setState(() => isPlacingOrder = false);
    }
  }

  void _showOrderSuccess({
    required String orderId,
    required int orderCreatedAtMillis,
    required String driverName,
  }) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => OrderSuccessScreen(
          orderId: orderId,
          deliveryAddress: selectedAddress,
          estimatedDelivery: estimatedDeliveryTime,
          estimatedArrivalClock: estimatedArrivalTime,
          orderCreatedAtMillis: orderCreatedAtMillis,
          selectedDeliveryTitle: selectedDeliveryOption.title,
          deliveryFee: deliveryFee,
          deliveryDistanceKm: deliveryDistanceKm,
          marketName: _marketName,
          marketLatitude: _marketLocation.latitude,
          marketLongitude: _marketLocation.longitude,
          driverName: driverName,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: prevStep,
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2C1810), size: 20),
        ),
        title: const Text(
          'Checkout',
          style: TextStyle(
            color: Color(0xFF2C1810),
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Step Indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                _buildStep(0, Icons.shopping_cart_outlined, 'Cart'),
                _buildLine(0),
                _buildStep(1, Icons.location_on_outlined, 'Address'),
                _buildLine(1),
                _buildStep(2, Icons.payment_outlined, 'Payment'),
              ],
            ),
          ),

          // Steps Content
          Expanded(
            child: IndexedStack(
              index: currentStep,
              children: [
                CartStep(
                  cartItems: widget.cartItems,
                  subtotal: widget.subtotal,
                  itemCount: widget.itemCount,
                  deliveryFee: deliveryFee,
                  discount: discount,
                  total: total,
                ),
                AddressDeliveryStep(
                  selectedDelivery: selectedDelivery,
                  selectedAddress: selectedAddress,
                  deliveryOptions: deliveryOptions,
                  distanceKm: deliveryDistanceKm,
                  deliveryFee: deliveryFee,
                  onDeliveryChanged: (value) {
                    setState(() {
                      selectedDelivery = value;
                    });
                  },
                  onAddressChanged: (address) {
                    setState(() {
                      selectedAddress = address;
                    });
                  },
                ),
                PaymentStep(
                  selectedPaymentMethod: selectedPaymentMethod,
                  onPaymentMethodChanged: (value) {
                    setState(() {
                      selectedPaymentMethod = value;
                    });
                  },
                  cardNumberController: cardNumberController,
                  cardholderNameController: cardholderNameController,
                  expiryController: expiryController,
                  cvvController: cvvController,
                  total: total,
                ),
              ],
            ),
          ),

          // Bottom Button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            child: ElevatedButton(
              onPressed: isPlacingOrder ? null : nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF4A32D),
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: isPlacingOrder
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Text(
                currentStep == 2 ? 'Place Order' : 'Continue',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int stepIndex, IconData icon, String label) {
    final isCompleted = currentStep > stepIndex;
    final isCurrent = currentStep == stepIndex;

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? const Color(0xFF4CAF50)
                : (isCurrent
                ? const Color(0xFFF4A32D)
                : const Color(0xFFE0E0E0)),
          ),
          child: isCompleted
              ? const Icon(Icons.check, size: 18, color: Colors.white)
              : Icon(
            icon,
            size: 16,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isCompleted
                ? const Color(0xFF4CAF50)
                : (isCurrent
                ? const Color(0xFFF4A32D)
                : const Color(0xFFBDBDBD)),
            fontWeight: (isCompleted || isCurrent)
                ? FontWeight.w600
                : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildLine(int stepIndex) {
    final isCompleted = currentStep > stepIndex;

    return Expanded(
      child: Container(
        height: 1.5,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: isCompleted ? const Color(0xFF4CAF50) : const Color(0xFFE0E0E0),
      ),
    );
  }
}

class CartStep extends StatelessWidget {
  final List<Map<String, dynamic>> cartItems;
  final double subtotal;
  final int itemCount;
  final double deliveryFee;
  final double discount;
  final double total;

  const CartStep({
    super.key,
    required this.cartItems,
    required this.subtotal,
    required this.itemCount,
    required this.deliveryFee,
    required this.discount,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final items = cartItems ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cart Items
          if (items.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  'Your cart is empty',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF8B7355),
                  ),
                ),
              ),
            )
          else
            ...items.map((item) => _buildCartItem(item)),

          if (items.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildOrderSummary(),
          ],
        ],
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item) {
    final String name = item['name']?.toString() ?? 'Unknown Item';
    final int quantity = item['quantity'] is int ? item['quantity'] : (item['quantity']?.toInt() ?? 1);
    final double price = (item['price'] is num) ? (item['price'] as num).toDouble() : 0.0;
    final String imageUrl = item['image']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: imageUrl.isNotEmpty
                ? CustomCachedImage(
              imageUrl: imageUrl,
              width: 70,
              height: 70,
              fit: BoxFit.cover,
              placeholder: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4A32D)),
                  ),
                ),
              ),
              errorWidget: const Icon(Icons.shopping_bag, color: Color(0xFFC0A080), size: 35),
            )
                : const Icon(Icons.shopping_bag, color: Color(0xFFC0A080), size: 35),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Color(0xFF2C1810),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Quantity: $quantity',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8B7355),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${(price * quantity).toStringAsFixed(2)} EGP',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Color(0xFFF4A32D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C1810),
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Subtotal ($itemCount items)', '${subtotal.toStringAsFixed(2)} EGP'),
          const SizedBox(height: 12),
          _buildSummaryRow('Discount', '-${discount.toStringAsFixed(2)} EGP', isDiscount: true),
          const Divider(height: 24, color: Color(0xFFE8E8E8), thickness: 1),
          _buildSummaryRow('Total', '${total.toStringAsFixed(2)} EGP', isTotal: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isDiscount = false, bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 15 : 14,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            color: isTotal ? const Color(0xFF2C1810) : const Color(0xFF8B7355),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.normal,
            color: isDiscount
                ? const Color(0xFF4CAF50)
                : (isTotal ? const Color(0xFFF4A32D) : const Color(0xFF2C1810)),
          ),
        ),
      ],
    );
  }
}

class DeliveryAddress {
  final String title;
  final String address;
  final double latitude;
  final double longitude;

  const DeliveryAddress({
    required this.title,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

class DeliveryOption {
  final String id;
  final String title;
  final String time;
  final double fee;

  const DeliveryOption({
    required this.id,
    required this.title,
    required this.time,
    required this.fee,
  });
}

class AddressDeliveryStep extends StatelessWidget {
  final String selectedDelivery;
  final DeliveryAddress selectedAddress;
  final List<DeliveryOption> deliveryOptions;
  final double distanceKm;
  final double deliveryFee;
  final ValueChanged<String> onDeliveryChanged;
  final ValueChanged<DeliveryAddress> onAddressChanged;

  const AddressDeliveryStep({
    super.key,
    required this.selectedDelivery,
    required this.selectedAddress,
    required this.deliveryOptions,
    required this.distanceKm,
    required this.deliveryFee,
    required this.onDeliveryChanged,
    required this.onAddressChanged,
  });

  Future<void> _openAddressPicker(BuildContext context) async {
    final result = await Navigator.push<DeliveryAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressPickerScreen(initialAddress: selectedAddress),
      ),
    );

    if (result != null) {
      onAddressChanged(result);
    }
  }

  String _formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()} m away';
    return '${km.toStringAsFixed(1)} km away';
  }

  String _formatFee(double fee) => '${fee.toStringAsFixed(2)} EGP';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Address',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C1810),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4A32D).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFFF4A32D),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedAddress.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C1810),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedAddress.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8B7355),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _openAddressPicker(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFF4A32D),
                  ),
                  child: const Text('Change'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF4A32D).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF4A32D).withOpacity(0.18)),
            ),
            child: Row(
              children: [
                const Icon(Icons.route_outlined, color: Color(0xFFF4A32D), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Delivery fee is calculated after your address: ${_formatDistance(distanceKm)}.',
                    style: const TextStyle(
                      color: Color(0xFF2C1810),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Choose Delivery Option',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C1810),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                for (int i = 0; i < deliveryOptions.length; i++) ...[
                  RadioListTile<String>(
                    value: deliveryOptions[i].id,
                    groupValue: selectedDelivery,
                    onChanged: (value) {
                      if (value != null) onDeliveryChanged(value);
                    },
                    title: Text(
                      '${deliveryOptions[i].title} (${deliveryOptions[i].time})',
                      style: const TextStyle(color: Color(0xFF2C1810), fontSize: 14),
                    ),
                    subtitle: Text(
                      distanceKm <= 3
                          ? 'Near address fee'
                          : distanceKm <= 8
                          ? 'Medium distance fee'
                          : 'Far address fee',
                      style: const TextStyle(color: Color(0xFF8B7355), fontSize: 12),
                    ),
                    secondary: Text(
                      _formatFee(deliveryOptions[i].fee),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: deliveryOptions[i].id == selectedDelivery
                            ? const Color(0xFFF4A32D)
                            : const Color(0xFF2C1810),
                      ),
                    ),
                    activeColor: const Color(0xFFF4A32D),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  if (i != deliveryOptions.length - 1)
                    const Divider(height: 1, color: Color(0xFFE8E8E8)),
                ],
              ],
            ),
          ),

          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8DCCF)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Selected Delivery Fee',
                  style: TextStyle(
                    color: Color(0xFF8B7355),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatFee(deliveryFee),
                  style: const TextStyle(
                    color: Color(0xFFF4A32D),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AddressPickerScreen extends StatefulWidget {
  final DeliveryAddress initialAddress;

  const AddressPickerScreen({
    super.key,
    required this.initialAddress,
  });

  @override
  State<AddressPickerScreen> createState() => _AddressPickerScreenState();
}

class _AddressPickerScreenState extends State<AddressPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  LatLng? selectedPoint;
  String selectedAddressText = '';
  bool isLoadingLocation = false;
  bool isSearching = false;
  bool isReverseGeocoding = false;

  static const Color orange = Color(0xFFF4A32D);
  static const Color brown = Color(0xFF2C1810);
  static const Color mutedBrown = Color(0xFF8B7355);
  static const Color background = Color(0xFFFFFAF4);

  @override
  void initState() {
    super.initState();
    selectedPoint = LatLng(
      widget.initialAddress.latitude,
      widget.initialAddress.longitude,
    );
    selectedAddressText = widget.initialAddress.address;
    _searchController.text = widget.initialAddress.address;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => isLoadingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('Please enable location services.');
        setState(() => isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('Location permission denied.');
        setState(() => isLoadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final point = LatLng(position.latitude, position.longitude);
      setState(() {
        selectedPoint = point;
        selectedAddressText = 'Loading address...';
      });

      _mapController.move(point, 16);
      await _reverseGeocode(point);
    } catch (_) {
      _showMessage('Could not get your current location.');
    }

    if (mounted) {
      setState(() => isLoadingLocation = false);
    }
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => isSearching = true);

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
            '?q=${Uri.encodeComponent(query)}'
            '&format=json'
            '&limit=5'
            '&addressdetails=1'
            '&accept-language=en',
      );

      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'culinary_coach_app/1.0',
          'Accept': 'application/json',
          'Accept-Language': 'en',
        },
      );

      if (response.statusCode != 200) {
        _showMessage('Search failed. Try again.');
        setState(() => isSearching = false);
        return;
      }

      final List data = jsonDecode(response.body);
      if (data.isEmpty) {
        _showMessage('No address found. Try a more specific address.');
        setState(() => isSearching = false);
        return;
      }

      if (data.length == 1) {
        _selectSearchResult(data.first);
      } else {
        _showSearchResultsSheet(data);
      }
    } catch (_) {
      _showMessage('Could not search address. Check your internet connection.');
    }

    if (mounted) {
      setState(() => isSearching = false);
    }
  }

  void _showSearchResultsSheet(List results) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose Address',
                  style: TextStyle(
                    color: brown,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = results[index];
                      final displayName = item['display_name']?.toString() ?? 'Unknown address';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.location_on_outlined, color: orange),
                        title: Text(
                          displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: brown,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _selectSearchResult(item);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectSearchResult(dynamic item) {
    final lat = double.tryParse(item['lat']?.toString() ?? '');
    final lon = double.tryParse(item['lon']?.toString() ?? '');
    final displayName = item['display_name']?.toString();

    if (lat == null || lon == null || displayName == null) {
      _showMessage('Invalid address result.');
      return;
    }

    final point = LatLng(lat, lon);

    setState(() {
      selectedPoint = point;
      selectedAddressText = displayName;
      _searchController.text = displayName;
    });

    _mapController.move(point, 16);
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => isReverseGeocoding = true);

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
            '?lat=${point.latitude}'
            '&lon=${point.longitude}'
            '&format=json'
            '&addressdetails=1'
            '&accept-language=en',
      );

      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'culinary_coach_app/1.0',
          'Accept': 'application/json',
          'Accept-Language': 'en',
        },
      );

      if (response.statusCode != 200) {
        _setCoordinateAddress(point);
        return;
      }

      final data = jsonDecode(response.body);
      final displayName = data['display_name']?.toString();

      if (displayName == null || displayName.isEmpty) {
        _setCoordinateAddress(point);
        return;
      }

      setState(() {
        selectedAddressText = displayName;
        _searchController.text = displayName;
      });
    } catch (_) {
      _setCoordinateAddress(point);
    }

    if (mounted) {
      setState(() => isReverseGeocoding = false);
    }
  }

  void _setCoordinateAddress(LatLng point) {
    setState(() {
      selectedAddressText =
      '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
      _searchController.text = selectedAddressText;
    });
  }

  void _confirmAddress() {
    final point = selectedPoint;
    if (point == null) {
      _showMessage('Please select a location first.');
      return;
    }

    Navigator.pop(
      context,
      DeliveryAddress(
        title: 'Selected Location',
        address: selectedAddressText,
        latitude: point.latitude,
        longitude: point.longitude,
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: orange,
      ),
    );
  }

  void _zoomMap(double delta) {
    final currentZoom = _mapController.camera.zoom;
    final nextZoom = (currentZoom + delta).clamp(3.0, 18.0).toDouble();
    _mapController.move(_mapController.camera.center, nextZoom);
  }

  @override
  Widget build(BuildContext context) {
    final point = selectedPoint ?? const LatLng(30.0444, 31.2357);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: brown, size: 20),
        ),
        title: const Text(
          'Choose Address',
          style: TextStyle(
            color: brown,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchAddress(),
                    decoration: InputDecoration(
                      hintText: 'Search for your address',
                      prefixIcon: const Icon(Icons.search, color: orange),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: isSearching ? null : _searchAddress,
                  child: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: orange,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: isSearching
                        ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.arrow_forward, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: point,
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                    onTap: (tapPosition, latLng) async {
                      setState(() {
                        selectedPoint = latLng;
                        selectedAddressText = 'Loading address...';
                      });
                      await _reverseGeocode(latLng);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                      userAgentPackageName: 'com.culinary_coach.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 52,
                          height: 52,
                          child: const Icon(
                            Icons.location_pin,
                            color: orange,
                            size: 52,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 16,
                  top: 70,
                  child: Column(
                    children: [
                      _MapZoomButton(
                        icon: Icons.add,
                        onTap: () => _zoomMap(1),
                      ),
                      const SizedBox(height: 8),
                      _MapZoomButton(
                        icon: Icons.remove,
                        onTap: () => _zoomMap(-1),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 120,
                  child: FloatingActionButton(
                    heroTag: null,
                    backgroundColor: Colors.white,
                    onPressed: isLoadingLocation ? null : _useCurrentLocation,
                    child: isLoadingLocation
                        ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: orange,
                      ),
                    )
                        : const Icon(Icons.my_location, color: orange),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.touch_app_outlined, color: orange, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tap the map, search, or use your current location.',
                            style: TextStyle(
                              color: brown,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Selected Address',
                        style: TextStyle(
                          color: brown,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isReverseGeocoding)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: orange,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  selectedAddressText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: mutedBrown,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: selectedAddressText == 'Loading address...'
                        ? null
                        : _confirmAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: orange,
                      disabledBackgroundColor: orange.withOpacity(0.4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Confirm Address',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PAYMENT STEP WITH IMAGE ASSETS
// ============================================================
class PaymentStep extends StatelessWidget {
  final String selectedPaymentMethod;
  final Function(String) onPaymentMethodChanged;
  final TextEditingController cardNumberController;
  final TextEditingController cardholderNameController;
  final TextEditingController expiryController;
  final TextEditingController cvvController;
  final double total;

  const PaymentStep({
    super.key,
    required this.selectedPaymentMethod,
    required this.onPaymentMethodChanged,
    required this.cardNumberController,
    required this.cardholderNameController,
    required this.expiryController,
    required this.cvvController,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment Methods Title
          const Text(
            'Payment Method',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C1810),
            ),
          ),
          const SizedBox(height: 12),

          // Credit / Debit Card
          _buildPaymentMethodWithImage(
            title: 'Credit / Debit Card',
            subtitle: 'Visa, Mastercard, Amex',
            imagePath: 'assets/images/mastercard.jpg',
            value: 'card',
          ),
          const SizedBox(height: 10),

          // Digital Wallet
          _buildPaymentMethodWithImage(
            title: 'Digital Wallet',
            subtitle: 'Apple Pay / Google Pay',
            imagePath: 'assets/images/digital_wallet.png',
            value: 'wallet',
          ),
          const SizedBox(height: 10),

          // Cash on Delivery
          _buildPaymentMethodWithImage(
            title: 'Cash on Delivery',
            subtitle: 'Pay when you receive',
            imagePath: 'assets/images/cash_on_delivery.png',
            value: 'cash',
          ),

          // Card Details (only show if card is selected)
          if (selectedPaymentMethod == 'card') ...[
            const SizedBox(height: 24),
            const Text(
              'Card Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C1810),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildCardField(
                    controller: cardNumberController,
                    label: 'Card Number',
                    hint: 'Card number',
                    icon: Icons.credit_card_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildCardField(
                    controller: cardholderNameController,
                    label: 'Cardholder Name',
                    hint: 'Name on card',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCardField(
                          controller: expiryController,
                          label: 'Expiry Date',
                          hint: 'MM/YY',
                          icon: Icons.calendar_today_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCardField(
                          controller: cvvController,
                          label: 'CVV',
                          hint: 'CVV',
                          icon: Icons.lock_outline,
                          obscureText: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Digital Wallet Icons Row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8DCCF)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Image.asset(
                  'assets/images/visa.png',
                  height: 30,
                  width: 50,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.credit_card,
                    color: Color(0xFFF4A32D),
                    size: 30,
                  ),
                ),
                Image.asset(
                  'assets/images/mastercard.png',
                  height: 30,
                  width: 50,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.credit_card,
                    color: Color(0xFFF4A32D),
                    size: 30,
                  ),
                ),
                Image.asset(
                  'assets/images/apple_pay.png',
                  height: 30,
                  width: 50,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.apple,
                    color: Color(0xFFF4A32D),
                    size: 30,
                  ),
                ),
                Image.asset(
                  'assets/images/google_pay.png',
                  height: 30,
                  width: 50,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.payment,
                    color: Color(0xFFF4A32D),
                    size: 30,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Secure Payment
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4A32D).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, color: Color(0xFFF4A32D), size: 18),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Your payment information is encrypted and secure.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFF4A32D),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Total Amount
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C1810),
                  ),
                ),
                Text(
                  '${total.toStringAsFixed(2)} EGP',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF4A32D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodWithImage({
    required String title,
    required String subtitle,
    required String imagePath,
    required String value,
  }) {
    final isSelected = selectedPaymentMethod == value;

    return GestureDetector(
      onTap: () => onPaymentMethodChanged(value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFFF4A32D) : const Color(0xFFE8DCCF),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Image instead of Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF4A32D).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  imagePath,
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback icons if images don't exist
                    if (value == 'card') {
                      return const Icon(Icons.credit_card, color: Color(0xFFF4A32D), size: 24);
                    } else if (value == 'wallet') {
                      return const Icon(Icons.wallet, color: Color(0xFFF4A32D), size: 24);
                    } else {
                      return const Icon(Icons.money, color: Color(0xFFF4A32D), size: 24);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF2C1810),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8B7355),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFFF4A32D), size: 20),
          ],
        ),
      ),
    );
  }

  List<TextInputFormatter> _inputFormattersFor(String label) {
    if (label == 'Card Number') {
      return [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(19),
      ];
    }

    if (label == 'Expiry Date') {
      return [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
        _ExpiryDateInputFormatter(),
      ];
    }

    if (label == 'CVV') {
      return [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ];
    }

    return [
      FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z .'-]")),
      LengthLimitingTextInputFormatter(40),
    ];
  }

  Widget _buildCardField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C1810),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: label == 'Card Number' || label == 'CVV'
              ? TextInputType.number
              : TextInputType.text,
          textCapitalization: label == 'Cardholder Name'
              ? TextCapitalization.words
              : TextCapitalization.none,
          inputFormatters: _inputFormattersFor(label),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFC0A080), fontSize: 13),
            prefixIcon: icon != null
                ? Icon(icon, color: const Color(0xFFF4A32D), size: 20)
                : null,
            filled: true,
            fillColor: const Color(0xFFF9F9F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF4A32D), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    String formatted = digits;

    if (digits.length > 2) {
      formatted = '${digits.substring(0, 2)}/${digits.substring(2)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class OrderSuccessScreen extends StatelessWidget {
  final String orderId;
  final DeliveryAddress deliveryAddress;
  final String estimatedDelivery;
  final String estimatedArrivalClock;
  final int orderCreatedAtMillis;
  final String selectedDeliveryTitle;
  final double deliveryFee;
  final double deliveryDistanceKm;
  final String marketName;
  final double marketLatitude;
  final double marketLongitude;
  final String driverName;

  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    required this.deliveryAddress,
    required this.estimatedDelivery,
    required this.estimatedArrivalClock,
    required this.orderCreatedAtMillis,
    required this.selectedDeliveryTitle,
    required this.deliveryFee,
    required this.deliveryDistanceKm,
    required this.marketName,
    required this.marketLatitude,
    required this.marketLongitude,
    required this.driverName,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;

    // Responsive breakpoints
    final isSmallScreen = screenWidth < 400;
    final isMediumScreen = screenWidth >= 400 && screenWidth < 600;

    // Responsive values
    final iconContainerSize = isSmallScreen ? 150.0 : (isMediumScreen ? 180.0 : 200.0);
    final iconSize = isSmallScreen ? 60.0 : (isMediumScreen ? 70.0 : 80.0);
    final titleSize = isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0);
    final bodySize = isSmallScreen ? 12.0 : (isMediumScreen ? 13.0 : 14.0);
    final buttonHeight = screenHeight < 600 ? 44.0 : 50.0;
    final buttonTextSize = isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0);
    final horizontalPadding = screenWidth * 0.06;
    final spacing = screenHeight * 0.03;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF4),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Container(
            height: screenHeight - mediaQuery.padding.top - mediaQuery.padding.bottom,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Success Icon
                Container(
                  width: iconContainerSize,
                  height: iconContainerSize,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4A32D).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(iconContainerSize / 2),
                    child: Image.asset(
                      'assets/images/bag-food-items.PNG',
                      width: iconSize,
                      height: iconSize,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SizedBox(height: spacing),

                // Success Message
                Text(
                  'Order Placed Successfully!🎉',
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C1810),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: spacing * 0.5),
                Text(
                  'Thank you for shopping with us.\nYour order has been received.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: bodySize,
                    color: const Color(0xFF8B7355),
                    height: 1.5,
                  ),
                ),
                SizedBox(height: spacing * 1.5),

                // Order Details Card
                Container(
                  padding: EdgeInsets.all(horizontalPadding),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow('Order ID', orderId, bodySize),
                      const SizedBox(height: 14),
                      _buildInfoRow('Marketplace', marketName, bodySize),
                      const SizedBox(height: 14),
                      _buildInfoRow('Delivery Option', selectedDeliveryTitle, bodySize),
                      const SizedBox(height: 14),
                      _buildInfoRow('Delivery Fee', '${deliveryFee.toStringAsFixed(2)} EGP', bodySize),
                      const SizedBox(height: 14),
                      _buildInfoRow('Driver', driverName, bodySize),
                      const SizedBox(height: 20),
                      Container(height: 1, color: const Color(0xFFE8DCCF)),
                      const SizedBox(height: 20),
                      _buildInfoRow('Estimated Delivery', estimatedDelivery, bodySize,
                          valueColor: const Color(0xFF4CAF50)),
                      const SizedBox(height: 14),
                      _buildInfoRow('Arrives At', estimatedArrivalClock, bodySize,
                          valueColor: const Color(0xFF4CAF50)),
                    ],
                  ),
                ),

                SizedBox(height: spacing),

                // Track Your Order Button
                _buildResponsiveButton(
                  text: 'Track Your Order',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TrackOrderScreen(
                          orderId: orderId,
                          estimatedDelivery: estimatedDelivery,
                          orderCreatedAtMillis: orderCreatedAtMillis,
                          deliveryLatitude: deliveryAddress.latitude,
                          deliveryLongitude: deliveryAddress.longitude,
                          deliveryAddressText: deliveryAddress.address,
                          deliveryOptionTitle: selectedDeliveryTitle,
                          deliveryFee: deliveryFee,
                          checkoutDistanceKm: deliveryDistanceKm,
                          marketName: marketName,
                          marketLatitude: marketLatitude,
                          marketLongitude: marketLongitude,
                          driverName: driverName,
                        ),
                      ),
                    );
                  },
                  height: buttonHeight,
                  fontSize: buttonTextSize,
                  isOutlined: false,
                ),

                SizedBox(height: spacing * 0.5),

                // Continue Shopping Button
                _buildResponsiveButton(
                  text: 'Continue Shopping',
                  onPressed: () {
                    // Go back to the shop screen. The cart has already been
                    // cleared in Firestore after the order was saved, so the
                    // user can start a fresh order.
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  height: buttonHeight,
                  fontSize: buttonTextSize,
                  isOutlined: true,
                ),

                SizedBox(height: spacing),

                // Footer Message
                Text(
                  "We'll send you an SMS/email with order updates.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: bodySize * 0.85,
                    color: const Color(0xFFA08F7E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, double fontSize, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            color: const Color(0xFF8B7355),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: valueColor ?? const Color(0xFF2C1810),
          ),
        ),
      ],
    );
  }

  Widget _buildResponsiveButton({
    required String text,
    required VoidCallback onPressed,
    required double height,
    required double fontSize,
    required bool isOutlined,
  }) {
    if (isOutlined) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF4CAF50),
            side: const BorderSide(color: Color(0xFF4CAF50)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  static const Color _orange = Color(0xFFF4A32D);
  static const Color _brown = Color(0xFF2C1810);
  static const Color _muted = Color(0xFF8B7355);
  static const Color _green = Color(0xFF4CAF50);
  static const Color _background = Color(0xFFFFFAF4);

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  String _formatMoney(dynamic value) {
    final amount = value is num ? value.toDouble() : 0.0;
    return '${amount.toStringAsFixed(2)} EGP';
  }

  String _formatOrderDate(Map<String, dynamic> data) {
    final millis = data['orderCreatedAtMillis'];
    DateTime date;
    if (millis is int) {
      date = DateTime.fromMillisecondsSinceEpoch(millis);
    } else {
      final createdAt = data['createdAt'];
      date = createdAt is Timestamp ? createdAt.toDate() : DateTime.now();
    }

    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day}/${date.month}/${date.year} • $hour12:$minute $period';
  }


  int _maxMinutesFromDeliveryTime(String value) {
    final numbers = RegExp(r'\d+')
        .allMatches(value)
        .map((m) => int.tryParse(m.group(0) ?? '') ?? 0)
        .where((n) => n > 0)
        .toList();
    if (numbers.isEmpty) return 30;
    return numbers.reduce(math.max);
  }

  bool _isOrderArrived(Map<String, dynamic> data) {
    final delivery = Map<String, dynamic>.from(data['delivery'] as Map? ?? {});
    final estimatedDelivery = delivery['estimatedDelivery']?.toString() ?? '10 - 30 min';
    final targetArrival = DateTime.fromMillisecondsSinceEpoch(_orderMillis(data)).add(
      Duration(minutes: _maxMinutesFromDeliveryTime(estimatedDelivery)),
    );
    return DateTime.now().isAtSameMomentAs(targetArrival) || DateTime.now().isAfter(targetArrival);
  }

  int _orderMillis(Map<String, dynamic> data) {
    final millis = data['orderCreatedAtMillis'];
    if (millis is int) return millis;
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) return createdAt.toDate().millisecondsSinceEpoch;
    return DateTime.now().millisecondsSinceEpoch;
  }

  void _openTracking(BuildContext context, Map<String, dynamic> data) {
    final delivery = Map<String, dynamic>.from(data['delivery'] as Map? ?? {});
    final market = Map<String, dynamic>.from(data['market'] as Map? ?? {});
    final driver = Map<String, dynamic>.from(data['driver'] as Map? ?? {});

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrackOrderScreen(
          orderId: data['orderId']?.toString() ?? '',
          estimatedDelivery: delivery['estimatedDelivery']?.toString() ?? '10 - 30 min',
          orderCreatedAtMillis: _orderMillis(data),
          deliveryLatitude: (delivery['latitude'] as num?)?.toDouble(),
          deliveryLongitude: (delivery['longitude'] as num?)?.toDouble(),
          deliveryAddressText: delivery['address']?.toString(),
          deliveryOptionTitle: delivery['optionTitle']?.toString() ?? 'Express Delivery',
          deliveryFee: (data['deliveryFee'] as num?)?.toDouble() ?? 0.0,
          checkoutDistanceKm: (delivery['distanceKm'] as num?)?.toDouble(),
          marketName: market['name']?.toString() ?? 'Culinary Market',
          marketLatitude: (market['latitude'] as num?)?.toDouble() ?? 30.0444,
          marketLongitude: (market['longitude'] as num?)?.toDouble() ?? 31.2357,
          driverName: driver['name']?.toString() ?? 'Michael Johnson',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = _currentUserId;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: _brown, size: 20),
        ),
        title: const Text(
          'My Orders',
          style: TextStyle(
            color: _brown,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: userId == null
          ? const Center(
        child: Text(
          'Please sign in to view your orders.',
          style: TextStyle(color: _muted, fontSize: 15),
        ),
      )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('shop_orders')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_orange),
              ),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Could not load your orders. Please try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted),
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No orders yet. Your completed orders will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 15),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final delivery = Map<String, dynamic>.from(data['delivery'] as Map? ?? {});
              final items = data['items'] is List ? data['items'] as List : const [];
              final status = _isOrderArrived(data)
                  ? 'arrived'
                  : (data['status']?.toString() ?? 'confirmed');

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data['orderId']?.toString() ?? docs[index].id,
                            style: const TextStyle(
                              color: _brown,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: const TextStyle(
                              color: _green,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatOrderDate(data),
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.shopping_bag_outlined, size: 18, color: _orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${items.length} items • ${_formatMoney(data['total'])}',
                            style: const TextStyle(
                              color: _brown,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 18, color: _orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            delivery['address']?.toString() ?? 'Saved delivery address',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openTracking(context, data),
                        icon: const Icon(Icons.local_shipping_outlined, color: Colors.white, size: 18),
                        label: const Text(
                          'Track Order',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _orange,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
