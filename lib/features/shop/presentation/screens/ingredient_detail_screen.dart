import 'package:flutter/material.dart';
import 'package:culinary_coach_app/features/filter/data/models/ingredient_model.dart';
import 'package:culinary_coach_app/features/filter/widgets/custom_image_cache.dart';

class IngredientDetailScreen extends StatefulWidget {
  final IngredientModel ingredient;
  final double initialQuantity;
  final bool isInCart;
  final Future<void> Function(IngredientModel ingredient, double quantity) onAddToCart;

  const IngredientDetailScreen({
    super.key,
    required this.ingredient,
    this.initialQuantity = 1.0,
    this.isInCart = false,
    required this.onAddToCart,
  });

  @override
  State<IngredientDetailScreen> createState() => _IngredientDetailScreenState();
}

class _IngredientDetailScreenState extends State<IngredientDetailScreen> {
  double _quantity = 1.0;
  bool _isSaving = false;
  late bool _isInCart;
  late final TextEditingController _quantityController;

  static const Color _orangeDark = Color(0xFFB87313);
  static const Color _brown = Color(0xFF3A2214);
  static const Color _mutedBrown = Color(0xFF8B7355);
  static const Color _green = Color(0xFF2E7D32);
  static const Color _cream = Color(0xFFFCF7E8);

  @override
  void initState() {
    super.initState();
    _isInCart = widget.isInCart;
    _quantity = widget.initialQuantity.clamp(0.1, 100.0).toDouble();
    _quantityController = TextEditingController(text: _formatQuantity(_quantity));
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  bool get _isBreadIngredient {
    final category = widget.ingredient.category.toLowerCase().trim();
    final name = widget.ingredient.name.toLowerCase().trim();

    return category == 'breads' ||
        category == 'bread' ||
        name.contains('bread') ||
        name.contains('toast') ||
        name.contains('bun') ||
        name.contains('bagel') ||
        name.contains('loaf') ||
        name.contains('pita') ||
        name.contains('croissant');
  }

  bool get _usesLiquidUnit {
    if (_isBreadIngredient) return false;

    final unit = (widget.ingredient.unit ?? '').toLowerCase().trim();
    final name = widget.ingredient.name.toLowerCase();

    final liquidUnits = <String>{
      'l',
      'liter',
      'liters',
      'litre',
      'litres',
      'ml',
      'milliliter',
      'milliliters',
      'millilitre',
      'millilitres',
    };

    if (liquidUnits.contains(unit)) return true;

    return RegExp(r'\b(milk|oil|juice|water|soda|drink|beverage|vinegar|syrup|sauce)\b')
        .hasMatch(name);
  }

  String get _largeUnitLabel {
    if (_isBreadIngredient) return 'quantity';
    return _usesLiquidUnit ? 'L' : 'KG';
  }

  String get _smallUnitLabel => _usesLiquidUnit ? 'ml' : 'g';

  String _getPriceDisplay() {
    final price = widget.ingredient.price ?? 0.0;
    if (_isBreadIngredient) return '${price.toStringAsFixed(2)} EGP / quantity';
    return '${price.toStringAsFixed(2)} EGP / $_largeUnitLabel';
  }

  double get _totalPrice {
    final price = widget.ingredient.price ?? 0.0;
    return price * (_isInCart ? _quantity : 1.0);
  }

  String _formatNumber(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }

  String _formatQuantity(double value) {
    if (_isBreadIngredient) return _formatNumber(value);

    if (value < 1) {
      final smallValue = value * 1000;
      return smallValue % 1 == 0 ? smallValue.toInt().toString() : smallValue.toStringAsFixed(1);
    }
    return _formatNumber(value);
  }

  String get _currentUnitLabel {
    if (_isBreadIngredient) return '';
    return _quantity < 1 ? _smallUnitLabel : _largeUnitLabel;
  }

  String _formatReadableQuantity(double value) {
    if (_isBreadIngredient) return _formatNumber(value);
    if (value < 1) return '${_formatQuantity(value)} $_smallUnitLabel';
    return '${_formatNumber(value)} $_largeUnitLabel';
  }

  double _quantityFromTypedValue(String rawValue) {
    final typed = double.tryParse(rawValue.trim());
    if (typed == null || typed <= 0) return _quantity;
    return _currentUnitLabel == _smallUnitLabel ? typed / 1000 : typed;
  }

  Future<void> _setQuantity(double newQuantity, {bool saveToDatabase = true}) async {
    if (!_isInCart) return;

    final oldQuantity = _quantity;
    final safeQuantity = newQuantity.clamp(0.1, 100.0).toDouble();

    setState(() {
      _quantity = safeQuantity;
      _quantityController.text = _formatQuantity(safeQuantity);
      _isSaving = saveToDatabase;
    });

    if (!saveToDatabase) return;

    try {
      await widget.onAddToCart(widget.ingredient, safeQuantity);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _quantity = oldQuantity;
        _quantityController.text = _formatQuantity(oldQuantity);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update cart quantity.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _applyTypedQuantity() async {
    final typedQuantity = _quantityFromTypedValue(_quantityController.text);
    if (typedQuantity <= 0) {
      _quantityController.text = _formatQuantity(_quantity);
      return;
    }
    await _setQuantity(typedQuantity);
  }

  Future<void> _addCurrentQuantityToCart() async {
    final wasInCart = _isInCart;
    setState(() => _isSaving = true);
    try {
      final quantityToSave = _isInCart ? _quantity : 1.0;
      await widget.onAddToCart(widget.ingredient, quantityToSave);
      if (!mounted) return;

      setState(() {
        _isInCart = true;
        _quantity = quantityToSave;
        _quantityController.text = _formatQuantity(quantityToSave);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.ingredient.name} ${wasInCart ? 'updated in cart' : 'added to cart'}',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: _green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update cart.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }


  Widget _quantityButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: _orangeDark,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
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
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        Text(
                          widget.ingredient.name,
                          style: const TextStyle(
                            color: _brown,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _getPriceDisplay(),
                          style: const TextStyle(color: _green, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Fresh, high-quality ingredient selected for your kitchen. Great for everyday meals and recipe planning.',
                          style: TextStyle(color: _mutedBrown, fontSize: 14, height: 1.4),
                        ),
                        const SizedBox(height: 24),
                        if (_isInCart) ...[
                          const Text(
                            'Quantity',
                            style: TextStyle(color: _brown, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFE2C9A4), width: 1.4),
                            ),
                            child: Row(
                              children: [
                                _quantityButton(Icons.remove, () {
                                  if (!_isSaving) _setQuantity(_quantity - (_isBreadIngredient ? 1.0 : 0.5));
                                }),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _quantityController,
                                    textAlign: TextAlign.center,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    onSubmitted: (_) => _applyTypedQuantity(),
                                    onEditingComplete: _applyTypedQuantity,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      suffixText: _currentUnitLabel.isEmpty ? null : _currentUnitLabel,
                                      border: InputBorder.none,
                                    ),
                                    style: const TextStyle(
                                      color: _brown,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _quantityButton(Icons.add, () {
                                  if (!_isSaving) _setQuantity(_quantity + (_isBreadIngredient ? 1.0 : 0.5));
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isBreadIngredient
                                ? 'Current quantity: ${_formatReadableQuantity(_quantity)}. Edit it here to update your cart.'
                                : 'Current quantity: ${_formatReadableQuantity(_quantity)}. Use + / - or type a quantity here to update your cart.',
                            style: const TextStyle(color: _mutedBrown, fontSize: 12),
                          ),
                        ] else ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2C9A4)),
                            ),
                            child: const Text(
                              'Add this ingredient first, then you can edit its quantity here.',
                              style: TextStyle(color: _mutedBrown, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_isInCart ? 'Total Price' : 'Unit Price', style: const TextStyle(color: _mutedBrown, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(
                        '${_totalPrice.toStringAsFixed(2)} EGP',
                        style: const TextStyle(
                          color: _orangeDark,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _addCurrentQuantityToCart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orangeDark,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : Text(
                      _isInCart ? 'Update Cart' : 'Add to Cart',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
