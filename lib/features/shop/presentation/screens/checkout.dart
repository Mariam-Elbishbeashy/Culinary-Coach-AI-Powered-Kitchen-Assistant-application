import 'package:culinary_coach_app/features/shop/presentation/screens/track_order.dart';
import 'package:flutter/material.dart';
import '../../../filter/widgets/custom_image_cache.dart';

class CheckoutScreen extends StatefulWidget {
  final double subtotal;
  final int itemCount;
  final List<Map<String, dynamic>> cartItems;

  const CheckoutScreen({
    super.key,
    required this.subtotal,
    required this.itemCount,
    required this.cartItems,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  int currentStep = 0;
  String selectedDelivery = 'express';
  String selectedPaymentMethod = 'card';

  final TextEditingController cardNumberController = TextEditingController();
  final TextEditingController cardholderNameController = TextEditingController();
  final TextEditingController expiryController = TextEditingController();
  final TextEditingController cvvController = TextEditingController();

  // Egyptian Pound prices (EGP)
  double get deliveryFee => selectedDelivery == 'express' ? 45.0 : 0.0;
  double get discount => 20.0;
  double get total => widget.subtotal + deliveryFee - discount;

  void nextStep() {
    if (currentStep < 2) {
      setState(() => currentStep++);
    } else {
      _showOrderSuccess();
    }
  }

  void prevStep() {
    if (currentStep > 0) {
      setState(() => currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  void _showOrderSuccess() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => OrderSuccessScreen(
          orderId: '#ORD${DateTime.now().millisecondsSinceEpoch.toString().substring(7, 13)}',
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
                const AddressDeliveryStep(),
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
              onPressed: nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF4A32D),
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
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

// ============================================================
// CART STEP
// ============================================================
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
          _buildSummaryRow('Delivery Fee', deliveryFee == 0 ? 'Free' : '${deliveryFee.toStringAsFixed(2)} EGP'),
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

// ============================================================
// ADDRESS & DELIVERY STEP
// ============================================================
class AddressDeliveryStep extends StatefulWidget {
  const AddressDeliveryStep({super.key});

  @override
  State<AddressDeliveryStep> createState() => _AddressDeliveryStepState();
}

class _AddressDeliveryStepState extends State<AddressDeliveryStep> {
  String selectedDelivery = 'express';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Delivery Address
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
                  child: const Icon(Icons.home_outlined, color: Color(0xFFF4A32D), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Home',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C1810),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '123 Green St, Cairo, Egypt',
                        style: TextStyle(
                          color: Color(0xFF8B7355),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFF4A32D),
                  ),
                  child: const Text('Change'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Delivery Time
          const Text(
            'Delivery Time',
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
                RadioListTile<String>(
                  value: 'express',
                  groupValue: selectedDelivery,
                  onChanged: (value) {
                    setState(() {
                      selectedDelivery = value!;
                    });
                    final parentState = context.findAncestorStateOfType<_CheckoutScreenState>();
                    if (parentState != null) {
                      parentState.setState(() {
                        parentState.selectedDelivery = value!;
                      });
                    }
                  },
                  title: const Text(
                    'Express Delivery (10-30 min)',
                    style: TextStyle(color: Color(0xFF2C1810), fontSize: 14),
                  ),
                  secondary: const Text(
                    '45 EGP',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF4A32D),
                    ),
                  ),
                  activeColor: const Color(0xFFF4A32D),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                RadioListTile<String>(
                  value: 'standard',
                  groupValue: selectedDelivery,
                  onChanged: (value) {
                    setState(() {
                      selectedDelivery = value!;
                    });
                    final parentState = context.findAncestorStateOfType<_CheckoutScreenState>();
                    if (parentState != null) {
                      parentState.setState(() {
                        parentState.selectedDelivery = value!;
                      });
                    }
                  },
                  title: const Text(
                    'Standard Delivery (30-60 min)',
                    style: TextStyle(color: Color(0xFF2C1810), fontSize: 14),
                  ),
                  secondary: const Text(
                    'Free',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                  activeColor: const Color(0xFFF4A32D),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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
                    hint: '1234 5678 9012 3456',
                    icon: Icons.credit_card_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildCardField(
                    controller: cardholderNameController,
                    label: 'Cardholder Name',
                    hint: 'John Doe',
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
                          hint: '123',
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

// ============================================================
// RESPONSIVE ORDER SUCCESS SCREEN
// ============================================================
class OrderSuccessScreen extends StatelessWidget {
  final String orderId;

  const OrderSuccessScreen({super.key, required this.orderId});

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
                      const SizedBox(height: 20),
                      Container(height: 1, color: const Color(0xFFE8DCCF)),
                      const SizedBox(height: 20),
                      _buildInfoRow('Estimated Delivery', '10 - 30 min', bodySize,
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
                          estimatedDelivery: '10 - 30 min',
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
                    Navigator.pop(context);
                    Navigator.pop(context);

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