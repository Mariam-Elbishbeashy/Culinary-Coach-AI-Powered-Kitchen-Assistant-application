import 'package:flutter/material.dart';
import 'package:culinary_coach_app/features/filter/data/models/ingredient_model.dart';
import 'package:culinary_coach_app/features/filter/widgets/custom_image_cache.dart';

class IngredientDetailScreen extends StatefulWidget {
  final IngredientModel ingredient;
  final Function(IngredientModel, double quantity) onAddToCart;

  const IngredientDetailScreen({
    super.key,
    required this.ingredient,
    required this.onAddToCart,
  });

  @override
  State<IngredientDetailScreen> createState() => _IngredientDetailScreenState();
}

class _IngredientDetailScreenState extends State<IngredientDetailScreen> {
  double _quantity = 1.0;
  String _selectedDelivery = 'Standard';
  int _selectedQuantityIndex = 0;

  final List<double> _quantityOptions = [0.5, 1.0, 1.5, 2.0];
  final List<String> _quantityLabels = ['0.5 kg', '1 kg', '1.5 kg', '2 kg'];

  final Map<String, Map<String, dynamic>> _deliveryOptions = {
    'Standard': {'price': 2.49, 'time': '2-3 business days'},
    'Express': {'price': 4.99, 'time': 'Same day delivery'},
  };

  static const Color _orangeDark = Color(0xFFB87313);
  static const Color _orange = Color(0xFFD99622);
  static const Color _brown = Color(0xFF3A2214);
  static const Color _mutedBrown = Color(0xFF8B7355);
  static const Color _green = Color(0xFF2E7D32);
  static const Color _lightGreen = Color(0xFF5C8E3E);
  static const Color _cream = Color(0xFFFCF7E8);
  static const Color _starColor = Color(0xFFFFB800);

  String _getPriceDisplay() {
    final price = widget.ingredient.price ?? 0.0;
    final unit = widget.ingredient.unit ?? 'kg';
    return '\$${price.toStringAsFixed(2)} / $unit';
  }

  double get _totalPrice {
    final price = widget.ingredient.price ?? 0.0;
    return price * _quantity;
  }

  double get _deliveryPrice {
    return _deliveryOptions[_selectedDelivery]?['price'] ?? 0.0;
  }

  double get _grandTotal {
    return _totalPrice + _deliveryPrice;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFAF4),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: _brown),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.favorite_border, color: _brown),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.share, color: _brown),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image
                  Center(
                    child: Container(
                      height: 250,
                      width: 250,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CustomCachedImage(
                        imageUrl: widget.ingredient.imageUrl,
                        width: 200,
                        height: 200,
                        fit: BoxFit.contain,
                        placeholder: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(_orangeDark),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Product Info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _cream,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _orangeDark.withOpacity(0.3)),
                          ),
                          child: Text(
                            widget.ingredient.category.toUpperCase(),
                            style: const TextStyle(
                              color: _orangeDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Product Name
                        Text(
                          widget.ingredient.name,
                          style: const TextStyle(
                            color: _brown,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Rating Row
                        Row(
                          children: [
                            Row(
                              children: List.generate(5, (index) {
                                return const Icon(
                                  Icons.star,
                                  color: _starColor,
                                  size: 18,
                                );
                              }),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '4.8',
                              style: TextStyle(
                                color: _brown,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(512 reviews)',
                              style: TextStyle(
                                color: _mutedBrown,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Price
                        Text(
                          _getPriceDisplay(),
                          style: const TextStyle(
                            color: _green,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Description
                        const Text(
                          'Crisp, sweet and juicy apples directly from the garden. Great for a snack, salads, or baking.',
                          style: TextStyle(
                            color: _mutedBrown,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Quantity Selector
                        const Text(
                          'Select Quantity',
                          style: TextStyle(
                            color: _brown,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 48,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _quantityOptions.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final isSelected = _selectedQuantityIndex == index;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedQuantityIndex = index;
                                    _quantity = _quantityOptions[index];
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  decoration: BoxDecoration(
                                    color: isSelected ? _orangeDark : Colors.white,
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: isSelected ? _orangeDark : const Color(0xFFE2C9A4),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _quantityLabels[index],
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : _brown,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Delivery Options Header
                        const Text(
                          'Delivery Options',
                          style: TextStyle(
                            color: _brown,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Delivery Options Cards
                        ..._deliveryOptions.keys.map((option) {
                          final isSelected = _selectedDelivery == option;
                          final optionData = _deliveryOptions[option]!;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedDelivery = option;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected ? _cream : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? _orangeDark : const Color(0xFFE2C9A4),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: _orangeDark.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      option == 'Standard'
                                          ? Icons.local_shipping
                                          : Icons.flash_on,
                                      color: _orangeDark,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          option == 'Standard'
                                              ? 'Standard Delivery'
                                              : 'Express Delivery',
                                          style: const TextStyle(
                                            color: _brown,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          optionData['time'],
                                          style: TextStyle(
                                            color: _mutedBrown,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '\$${optionData['price'].toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: _green,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (isSelected)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Icon(
                                        Icons.check_circle,
                                        color: _orangeDark,
                                        size: 22,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // Bottom Bar
          Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Price Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total Price',
                        style: TextStyle(
                          color: _mutedBrown,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '\$${_grandTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: _orangeDark,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_deliveryPrice > 0)
                        Text(
                          'incl. \$${_deliveryPrice.toStringAsFixed(2)} delivery',
                          style: TextStyle(
                            color: _mutedBrown,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
                // Add to Cart Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onAddToCart(widget.ingredient, _quantity);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${widget.ingredient.name} added to cart',
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: _green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orangeDark,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Add to Cart',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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