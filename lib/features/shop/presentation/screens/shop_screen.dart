import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/features/filter/data/models/ingredient_model.dart';
import 'package:culinary_coach_app/features/filter/data/services/ingredient_service.dart';
import 'package:culinary_coach_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:culinary_coach_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:culinary_coach_app/features/filter/widgets/custom_image_cache.dart';
import 'package:culinary_coach_app/features/shop/presentation/screens/checkout.dart';
import 'ingredient_detail_screen.dart';
import '../../../filter/presentation/screens/filter_screen.dart';
import '../../../filter/presentation/screens/voice.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final IngredientService _ingredientService = IngredientService();
  final TextEditingController _searchController = TextEditingController();

  // SHOP CART ONLY. This is saved under users/{uid}/shop_cart_items.
  // It is intentionally separate from the filter pantry collection: users/{uid}/selected_ingredients.
  Map<String, SelectedIngredientData> selectedIngredientsMap = {};

  // Keeps the first tap visible while Firestore confirms the write.
  // Without this, the StreamBuilder can briefly rebuild from an older snapshot
  // and make the cart quantity look like it did not update.
  final Map<String, double> _pendingCartQuantities = {};

  // Prevents old Firestore snapshots from re-adding an item immediately after
  // the user unselects it or taps delete in Your Cart.
  final Set<String> _pendingRemovedCartIds = {};

  // Prevents double taps from sending conflicting add/remove operations.
  final Set<String> _cartActionInProgress = {};

  // Cache the user-name future so every setState/stream rebuild does not start
  // a new Firestore read. This reduces skipped frames on the shop screen.
  Future<String?>? _cachedFirstNameFuture;
  String? _cachedFirstNameUid;

  String selectedCategory = 'All';
  List<String> categories = ['All'];
  bool isLoading = true;
  String searchQuery = '';
  bool showAllCategories = false;
  bool isCategoryOpened = false;

  // Best sellers data
  List<IngredientModel> bestSellers = [];
  bool isLoadingBestSellers = true;

  // Stores how many separate orders contain each best seller.
  // Example: if eggs appear in 6 different orders, their count is 6 even
  // if each order only contains 1 egg item. Key = ingredient id.
  Map<String, int> _bestSellerOrderCounts = {};
  bool _bestSellersLoadedFromOrders = false;

  static const Color _orangeDark = Color(0xFFB87313);
  static const Color _orange = Color(0xFFD99622);
  static const Color _orangeLight = Color(0xFFF2B13E);
  static const Color _cream = Color(0xFFF7F1DE);
  static const Color _cardCream = Color(0xFFFCF7E8);
  static const Color _brown = Color(0xFF3A2214);
  static const Color _mutedBrown = Color(0xFF8B7355);
  static const Color _border = Color(0xFFE2C9A4);
  static const Color _green = Color(0xFF5C8E3E);
  static const Color background = Color(0xFFFFFAF4);

  int get selectedCount => selectedIngredientsMap.values.where((item) => item.isChecked).length;

  @override
  void initState() {
    super.initState();
    _initializeIngredients();
    _loadBestSellers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalizeBestSellerKey(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _bestSellerKeyFromOrderItem(Map<String, dynamic> item) {
    final ingredientId = item['ingredientId']?.toString().trim();
    if (ingredientId != null && ingredientId.isNotEmpty) return ingredientId;

    final id = item['id']?.toString().trim();
    if (id != null && id.isNotEmpty) return id;

    final name = item['name']?.toString().trim() ?? '';
    return _normalizeBestSellerKey(name);
  }


  List<IngredientModel> _staticBestSellerFallback(List<IngredientModel> allIngredients) {
    final targetNames = [
      'Apple',
      'Banana',
      'Beef',
      'Avocado',
      'Chicken',
      'Milk',
      'Eggs',
      'Bread',
    ];

    final filteredBestSellers = allIngredients.where((ingredient) {
      return targetNames.any(
            (target) => ingredient.name.toLowerCase().contains(target.toLowerCase()),
      );
    }).toList();

    return filteredBestSellers.isNotEmpty
        ? filteredBestSellers.take(8).toList()
        : allIngredients.take(8).toList();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _loadOrderSnapshot() async {
    // First use the global collection saved by Checkout:
    // shop_orders/{orderId}
    final globalOrders = await FirebaseFirestore.instance
        .collection('shop_orders')
        .limit(500)
        .get();

    if (globalOrders.docs.isNotEmpty) return globalOrders;

    // Fallback for projects that only have per-user orders:
    // users/{uid}/shop_orders/{orderId}
    return FirebaseFirestore.instance
        .collectionGroup('shop_orders')
        .limit(500)
        .get();
  }

  Future<void> _loadBestSellers() async {
    if (mounted) setState(() => isLoadingBestSellers = true);

    try {
      final allIngredients = await _ingredientService.getAllIngredients().first;

      final ingredientsById = <String, IngredientModel>{
        for (final ingredient in allIngredients) ingredient.id: ingredient,
      };

      final ingredientsByName = <String, IngredientModel>{
        for (final ingredient in allIngredients)
          _normalizeBestSellerKey(ingredient.name): ingredient,
      };

      // Count how many separate orders contain each ingredient.
      // If eggs appear in 6 different orders, eggs get count 6.
      // If eggs appear twice inside the same order, it still counts as 1 order.
      final orderCountByIngredientId = <String, int>{};
      final orderSnapshot = await _loadOrderSnapshot();

      for (final orderDoc in orderSnapshot.docs) {
        final data = orderDoc.data();
        final rawItems = data['items'];
        if (rawItems is! List) continue;

        final ingredientIdsInThisOrder = <String>{};

        for (final rawItem in rawItems) {
          if (rawItem is! Map) continue;
          final item = Map<String, dynamic>.from(rawItem as Map);
          final key = _bestSellerKeyFromOrderItem(item);
          if (key.isEmpty) continue;

          IngredientModel? ingredient = ingredientsById[key];
          ingredient ??= ingredientsByName[_normalizeBestSellerKey(key)];

          // If the order item does not match an ingredient in full_ingredients,
          // skip it so Best Sellers always opens a valid ingredient detail page.
          if (ingredient == null) continue;

          ingredientIdsInThisOrder.add(ingredient.id);
        }

        for (final ingredientId in ingredientIdsInThisOrder) {
          orderCountByIngredientId[ingredientId] =
              (orderCountByIngredientId[ingredientId] ?? 0) + 1;
        }
      }

      final rankedIngredientIds = orderCountByIngredientId.keys.toList()
        ..sort((a, b) {
          final countCompare = (orderCountByIngredientId[b] ?? 0)
              .compareTo(orderCountByIngredientId[a] ?? 0);
          if (countCompare != 0) return countCompare;

          final aName = ingredientsById[a]?.name.toLowerCase() ?? a;
          final bName = ingredientsById[b]?.name.toLowerCase() ?? b;
          return aName.compareTo(bName);
        });

      final rankedIngredients = <IngredientModel>[];
      final rankedOrderCounts = <String, int>{};

      for (final ingredientId in rankedIngredientIds) {
        final ingredient = ingredientsById[ingredientId];
        if (ingredient == null) continue;

        rankedIngredients.add(ingredient);
        rankedOrderCounts[ingredient.id] = orderCountByIngredientId[ingredientId] ?? 0;

        if (rankedIngredients.length >= 8) break;
      }

      if (!mounted) return;

      if (rankedIngredients.isNotEmpty) {
        setState(() {
          bestSellers = rankedIngredients;
          _bestSellerOrderCounts = rankedOrderCounts;
          _bestSellersLoadedFromOrders = true;
          isLoadingBestSellers = false;
        });
      } else {
        setState(() {
          bestSellers = _staticBestSellerFallback(allIngredients);
          _bestSellerOrderCounts = {};
          _bestSellersLoadedFromOrders = false;
          isLoadingBestSellers = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading order-count best sellers: $e');

      try {
        final allIngredients = await _ingredientService.getAllIngredients().first;
        if (!mounted) return;
        setState(() {
          bestSellers = _staticBestSellerFallback(allIngredients);
          _bestSellerOrderCounts = {};
          _bestSellersLoadedFromOrders = false;
          isLoadingBestSellers = false;
        });
      } catch (fallbackError) {
        debugPrint('Error loading static best sellers fallback: $fallbackError');
        if (!mounted) return;
        setState(() {
          bestSellers = [];
          _bestSellerOrderCounts = {};
          _bestSellersLoadedFromOrders = false;
          isLoadingBestSellers = false;
        });
      }
    }
  }

  Future<void> _initializeIngredients() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final loadedCategories = await _ingredientService.getAllCategories();
      if (!mounted) return;
      setState(() {
        categories = loadedCategories.contains('All') ? loadedCategories : ['All', ...loadedCategories];
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      debugPrint('Error loading categories: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading categories: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  void _showAuthRequiredMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please sign in to add items to cart.'),
        backgroundColor: _orangeDark,
        duration: Duration(seconds: 2),
      ),
    );
  }

  CollectionReference<Map<String, dynamic>> _userShopCartRef(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('shop_cart_items');
  }

  Stream<List<SavedIngredientSelection>> _streamUserShopCart(String userId) {
    // IMPORTANT PERFORMANCE FIX:
    // Do not call Firestore again for every cart item inside the stream.
    // The cart document already stores the ingredient fields when we save it,
    // so reading directly from cartDoc prevents skipped frames and button glitches.
    return _userShopCartRef(userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((cartSnapshot) {
      final selections = <SavedIngredientSelection>[];

      for (final cartDoc in cartSnapshot.docs) {
        try {
          final data = cartDoc.data();
          final quantityValue = data['quantity'];
          final quantity = quantityValue is num ? quantityValue.toDouble() : 1.0;

          selections.add(
            SavedIngredientSelection(
              ingredient: IngredientModel.fromFirestore(cartDoc),
              quantity: quantity,
            ),
          );
        } catch (e) {
          debugPrint('Skipping invalid cart item ${cartDoc.id}: $e');
        }
      }

      selections.sort((a, b) => a.ingredient.name.compareTo(b.ingredient.name));
      return selections;
    });
  }

  Future<void> _saveCartIngredient({
    required IngredientModel ingredient,
    required double quantity,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      _showAuthRequiredMessage();
      return;
    }

    final safeQuantity = quantity.clamp(0.1, 100.0).toDouble();

    await _userShopCartRef(userId).doc(ingredient.id).set({
      ...ingredient.toFirestore(),
      'ingredientId': ingredient.id,
      'quantity': safeQuantity,
      'userId': userId,
      'source': 'shop_cart',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _updateCartQuantity({
    required String ingredientId,
    required double quantity,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      _showAuthRequiredMessage();
      return;
    }

    final safeQuantity = quantity.clamp(0.1, 100.0).toDouble();

    await _userShopCartRef(userId).doc(ingredientId).set({
      'ingredientId': ingredientId,
      'quantity': safeQuantity,
      'userId': userId,
      'source': 'shop_cart',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _deleteCartIngredient(String ingredientId) async {
    final userId = _currentUserId;
    if (userId == null) {
      _showAuthRequiredMessage();
      return;
    }

    await _userShopCartRef(userId).doc(ingredientId).delete();
  }

  Future<void> _clearUserShopCart() async {
    final userId = _currentUserId;
    if (userId == null) {
      _showAuthRequiredMessage();
      return;
    }

    final snapshot = await _userShopCartRef(userId).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Voice search method
  Future<void> _openVoiceSearch() async {
    final spokenIngredient = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const VoiceSearchScreen()),
    );

    final value = spokenIngredient?.trim();
    if (value == null || value.isEmpty) return;

    _searchController.text = value;
    _handleSearchChanged(value);
  }

  Future<void> toggleIngredient(IngredientModel ingredient) async {
    final userId = _currentUserId;
    if (userId == null) {
      _showAuthRequiredMessage();
      return;
    }

    if (_cartActionInProgress.contains(ingredient.id)) return;
    _cartActionInProgress.add(ingredient.id);

    final isAlreadySelected =
        selectedIngredientsMap.containsKey(ingredient.id) &&
            selectedIngredientsMap[ingredient.id]!.isChecked;

    final previousItem = selectedIngredientsMap[ingredient.id];

    if (isAlreadySelected) {
      _pendingRemovedCartIds.add(ingredient.id);
      _pendingCartQuantities.remove(ingredient.id);
      setState(() => selectedIngredientsMap.remove(ingredient.id));

      try {
        await _deleteCartIngredient(ingredient.id);
      } catch (e) {
        debugPrint('Error removing shop cart ingredient: $e');
        _pendingRemovedCartIds.remove(ingredient.id);
        if (!mounted) return;
        if (previousItem != null) {
          setState(() => selectedIngredientsMap[ingredient.id] = previousItem);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not remove ${ingredient.name} from your cart. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        _cartActionInProgress.remove(ingredient.id);
      }
      return;
    }

    _pendingRemovedCartIds.remove(ingredient.id);
    _pendingCartQuantities[ingredient.id] = 1.0;

    setState(() {
      selectedIngredientsMap[ingredient.id] = SelectedIngredientData(
        ingredient: ingredient,
        quantity: 1.0,
        isChecked: true,
      );
    });

    try {
      await _saveCartIngredient(ingredient: ingredient, quantity: 1.0);
      _pendingCartQuantities.remove(ingredient.id);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error adding shop cart ingredient: $e');
      _pendingCartQuantities.remove(ingredient.id);
      if (!mounted) return;
      setState(() {
        if (previousItem == null) {
          selectedIngredientsMap.remove(ingredient.id);
        } else {
          selectedIngredientsMap[ingredient.id] = previousItem;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not add ${ingredient.name} to your cart. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _cartActionInProgress.remove(ingredient.id);
    }
  }

  List<String> _getDisplayCategories(List<String> allCategories) {
    final cleaned = allCategories.where((category) => category.trim().isNotEmpty).toList();
    if (showAllCategories) {
      return cleaned;
    }
    return cleaned.take(12).toList();
  }

  String _normalizeSearchText(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s,/-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _extractSearchTerms(String value) {
    final normalized = _normalizeSearchText(value);
    if (normalized.isEmpty) return [];

    final stopWords = <String>{
      'and', 'or', 'with', 'for', 'the', 'a', 'an', 'of', 'to', 'in',
      'please', 'search', 'ingredient', 'ingredients', 'shop', 'buy', 'grocery',
    };

    if (normalized.contains(',')) {
      return normalized
          .split(',')
          .map((term) => term.trim())
          .where((term) => term.isNotEmpty && !stopWords.contains(term))
          .toSet()
          .toList();
    }

    return normalized
        .split(RegExp(r'\s+'))
        .map((term) => term.trim())
        .where((term) => term.length > 1 && !stopWords.contains(term))
        .toSet()
        .toList();
  }

  bool _ingredientMatchesAnySearchTerm({
    required IngredientModel ingredient,
    required List<String> terms,
  }) {
    if (terms.isEmpty) return true;

    final ingredientName = _normalizeSearchText(ingredient.name);
    final ingredientCategory = _normalizeSearchText(ingredient.category);

    for (final term in terms) {
      final normalizedTerm = _normalizeSearchText(term);
      if (normalizedTerm.isEmpty) continue;

      if (selectedCategory != 'All') {
        if (ingredientName.contains(normalizedTerm)) return true;
        continue;
      }

      if (ingredientName.contains(normalizedTerm) || ingredientCategory.contains(normalizedTerm)) {
        return true;
      }
    }

    return false;
  }

  List<IngredientModel> _applySearch(List<IngredientModel> ingredients) {
    final terms = _extractSearchTerms(searchQuery);
    if (terms.isEmpty) return ingredients;

    return ingredients.where((ingredient) {
      return _ingredientMatchesAnySearchTerm(ingredient: ingredient, terms: terms);
    }).toList();
  }

  String _openedTitle(List<IngredientModel> filteredIngredients) {
    if (selectedCategory != 'All') return selectedCategory;

    final terms = _extractSearchTerms(searchQuery);
    if (terms.length > 1) return 'Search Results';

    final query = searchQuery.trim().toLowerCase();
    if (query.isNotEmpty && filteredIngredients.isNotEmpty) {
      IngredientModel bestMatch = filteredIngredients.first;
      for (final ingredient in filteredIngredients) {
        final name = ingredient.name.toLowerCase();
        if (name == query || name.startsWith(query)) {
          bestMatch = ingredient;
          break;
        }
      }
      return bestMatch.category;
    }

    return 'All Ingredients';
  }

  void _handleSearchChanged(String value) {
    final query = value.trim();

    setState(() {
      searchQuery = value;

      if (query.isNotEmpty && !isCategoryOpened) {
        isCategoryOpened = true;
        selectedCategory = 'All';
      }

      if (query.isEmpty && selectedCategory == 'All' && isCategoryOpened) {
        isCategoryOpened = false;
      }
    });
  }

  String _categoryIconPath(String category) {
    final key = category.toLowerCase().trim();
    final map = <String, String>{
      'all': 'assets/images/bag-food-items.PNG',
      'asian': 'assets/images/asian2.png',
      'baking': 'assets/images/baking.png',
      'breads': 'assets/images/breadd.png',
      'breakfast': 'assets/images/break.png',
      'broths': 'assets/images/broth.png',
      'canned goods': 'assets/images/cane.png',
      'dairy': 'assets/images/milk.png',
      'beverages': 'assets/images/beveragess.png',
      'frozen foods': 'assets/images/frozen.png',
      'fruits': 'assets/images/fruits.png',
      'herbs': 'assets/images/herb.png',
      'grains': 'assets/images/grain.png',
      'legumes': 'assets/images/legume.png',
      'beans': 'assets/images/legumess.png',
      'meat': 'assets/images/meatss.png',
      'middle eastern': 'assets/images/middleeasterns.png',
      'nuts': 'assets/images/nutss.png',
      'oils': 'assets/images/oilss.png',
      'sauces': 'assets/images/saucess.png',
      'seafood': 'assets/images/seafoods.png',
      'seeds': 'assets/images/seedss.png',
      'snacks': 'assets/images/snackss.png',
      'spices': 'assets/images/spiceblends.png',
      'spice blends': 'assets/images/spicess.png',
      'sweeteners': 'assets/images/sweetenerss.png',
      'vegetables': 'assets/images/vegetables.png',
    };
    return map[key] ?? '';
  }

  double _getIngredientPrice(IngredientModel ingredient) {
    return ingredient.price ?? 0.0;
  }

  String _getFormattedPrice(IngredientModel ingredient) {
    if (ingredient.formattedPrice != null && ingredient.formattedPrice!.isNotEmpty) {
      return ingredient.formattedPrice!;
    }
    if (ingredient.price != null) {
      return '${ingredient.price!.toStringAsFixed(2)} ${ingredient.currency ?? 'EGP'}';
    }
    return 'Price unavailable';
  }


  Future<void> _openIngredientDetail(IngredientModel ingredient) async {
    final currentQuantity = selectedIngredientsMap[ingredient.id]?.quantity ?? 1.0;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IngredientDetailScreen(
          ingredient: ingredient,
          initialQuantity: currentQuantity > 0 ? currentQuantity : 1.0,
          isInCart: selectedIngredientsMap.containsKey(ingredient.id) &&
              selectedIngredientsMap[ingredient.id]!.isChecked,
          onAddToCart: (cartIngredient, quantity) async {
            final safeQuantity = quantity.clamp(0.1, 100.0).toDouble();

            _pendingRemovedCartIds.remove(cartIngredient.id);
            _pendingCartQuantities[cartIngredient.id] = safeQuantity;

            if (mounted) {
              setState(() {
                selectedIngredientsMap[cartIngredient.id] = SelectedIngredientData(
                  ingredient: cartIngredient,
                  quantity: safeQuantity,
                  isChecked: true,
                );
              });
            }

            await _saveCartIngredient(
              ingredient: cartIngredient,
              quantity: safeQuantity,
            );
            _pendingCartQuantities.remove(cartIngredient.id);
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  String _getFormattedLinePrice(IngredientModel ingredient, double quantity) {
    final price = ingredient.price ?? 0.0;
    return '${(price * quantity).toStringAsFixed(2)} ${ingredient.currency ?? 'EGP'}';
  }

  String _getFormattedUnitPrice(IngredientModel ingredient) {
    final price = ingredient.price ?? 0.0;
    final unit = _getUnitText(ingredient);
    return '${price.toStringAsFixed(2)} ${ingredient.currency ?? 'EGP'} / $unit';
  }

  bool _isBreadIngredient(IngredientModel ingredient) {
    final category = ingredient.category.toLowerCase().trim();
    final name = ingredient.name.toLowerCase().trim();

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

  String _getUnitText(IngredientModel ingredient) {
    // Bread items must never appear as liquid units. Some data sources store
    // bread units like "loaf", and the old check treated any unit containing
    // the letter "l" as liquid, so breads became L/ml by mistake.
    if (_isBreadIngredient(ingredient)) return 'quantity';

    return _usesLiquidUnit(ingredient) ? 'L' : 'KG';
  }

  bool _usesLiquidUnit(IngredientModel ingredient) {
    if (_isBreadIngredient(ingredient)) return false;

    final unit = (ingredient.unit ?? '').toLowerCase().trim();
    final name = ingredient.name.toLowerCase();

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

  String _largeUnitLabel(IngredientModel ingredient) => _usesLiquidUnit(ingredient) ? 'L' : 'KG';

  String _smallUnitLabel(IngredientModel ingredient) => _usesLiquidUnit(ingredient) ? 'ml' : 'g';

  String _formatQuantityNumber(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }

  String _formatCartQuantity(IngredientModel ingredient, double quantity) {
    // Bread should be displayed as a plain quantity, not KG/L.
    if (_isBreadIngredient(ingredient)) {
      return _formatQuantityNumber(quantity);
    }

    if (quantity < 1) {
      final smallValue = quantity * 1000;
      final smallText = smallValue % 1 == 0 ? smallValue.toInt().toString() : smallValue.toStringAsFixed(1);
      return '$smallText ${_smallUnitLabel(ingredient)}';
    }
    return '${_formatQuantityNumber(quantity)} ${_largeUnitLabel(ingredient)}';
  }

  double _getTotalPrice() {
    double total = 0;
    for (final item in selectedIngredientsMap.values) {
      if (item.isChecked && item.ingredient.price != null) {
        total += item.ingredient.price! * item.quantity;
      }
    }
    return total;
  }

  void _showCartPopup() {
    final selectedItems = selectedIngredientsMap.values.where((item) => item.isChecked).toList();

    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your cart is empty'),
          backgroundColor: _orangeDark,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: _cardCream,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final currentItems = selectedIngredientsMap.values.where((item) => item.isChecked).toList();
            final currentItemIds = selectedIngredientsMap.entries
                .where((entry) => entry.value.isChecked)
                .map((entry) => entry.key)
                .toList();
            final total = _getTotalPrice();

            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Your Cart',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _brown),
                        ),
                      ),
                      Text(
                        '${currentItems.length} items',
                        style: const TextStyle(color: _mutedBrown, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: currentItemIds.length,
                      itemBuilder: (context, index) {
                        final ingredientId = currentItemIds[index];
                        final latestItem = selectedIngredientsMap[ingredientId];
                        if (latestItem == null || !latestItem.isChecked) {
                          return const SizedBox.shrink();
                        }

                        final ingredient = latestItem.ingredient;
                        final latestQuantity = latestItem.quantity;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _border),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: _buildIngredientImage(ingredient, 50),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ingredient.name,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _brown),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      ingredient.category,
                                      style: const TextStyle(fontSize: 12, color: _mutedBrown),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _getFormattedLinePrice(ingredient, latestQuantity),
                                    style: const TextStyle(color: _green, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    _getFormattedUnitPrice(ingredient),
                                    style: const TextStyle(color: _mutedBrown, fontSize: 10),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: () async {
                                          final updateFuture = _updateQuantityLocal(ingredient.id, latestQuantity - 0.5);
                                          setSheetState(() {});
                                          await updateFuture;
                                          if (context.mounted) setSheetState(() {});
                                        },
                                        icon: const Icon(Icons.remove, size: 16),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                      ),
                                      Text(
                                        _formatCartQuantity(ingredient, latestQuantity),
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                      ),
                                      IconButton(
                                        onPressed: () async {
                                          final updateFuture = _updateQuantityLocal(ingredient.id, latestQuantity + 0.5);
                                          setSheetState(() {});
                                          await updateFuture;
                                          if (context.mounted) setSheetState(() {});
                                        },
                                        icon: const Icon(Icons.add, size: 16),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                      ),
                                    ],
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      final removed = await _removeIngredientLocal(ingredient.id);
                                      if (!context.mounted) return;

                                      final isCartEmpty = selectedIngredientsMap.values
                                          .where((i) => i.isChecked)
                                          .isEmpty;

                                      if (removed && isCartEmpty) {
                                        Navigator.pop(context);
                                        return;
                                      }

                                      setSheetState(() {});
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal', style: TextStyle(color: _mutedBrown)),
                            Text('${_getFormattedTotal(total)}', style: const TextStyle(color: _brown, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Delivery', style: TextStyle(color: _mutedBrown)),
                            const Text('-', style: TextStyle(color: _mutedBrown)),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _brown)),
                            Text(_getFormattedTotal(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _orangeDark)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showCheckoutDialog();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _orangeDark,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Checkout', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getFormattedTotal(double total) {
    return '${total.toStringAsFixed(2)} EGP';
  }

  Future<void> _updateQuantityLocal(String ingredientId, double newQuantity) async {
    if (!selectedIngredientsMap.containsKey(ingredientId)) return;

    final current = selectedIngredientsMap[ingredientId]!;
    final previousQuantity = current.quantity;
    final safeQuantity = newQuantity.clamp(0.1, 100.0).toDouble();

    _pendingCartQuantities[ingredientId] = safeQuantity;

    setState(() {
      selectedIngredientsMap[ingredientId] = SelectedIngredientData(
        ingredient: current.ingredient,
        quantity: safeQuantity,
        isChecked: current.isChecked,
      );
    });

    try {
      await _updateCartQuantity(ingredientId: ingredientId, quantity: safeQuantity);
      _pendingCartQuantities.remove(ingredientId);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error updating cart quantity: $e');
      _pendingCartQuantities.remove(ingredientId);
      if (!mounted || !selectedIngredientsMap.containsKey(ingredientId)) return;
      setState(() {
        selectedIngredientsMap[ingredientId] = SelectedIngredientData(
          ingredient: current.ingredient,
          quantity: previousQuantity,
          isChecked: current.isChecked,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update cart quantity.'), backgroundColor: Colors.red),
      );
    }
  }

  Future<String?> _saveCheckoutCartSnapshot({
    required List<Map<String, dynamic>> cartItems,
    required double subtotal,
    required int itemCount,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      _showAuthRequiredMessage();
      return null;
    }

    final cartRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('checkout_carts')
        .doc();

    await cartRef.set({
      'checkoutCartId': cartRef.id,
      'userId': userId,
      'items': cartItems,
      'itemCount': itemCount,
      'subtotal': subtotal,
      'currency': 'EGP',
      'status': 'checkout_started',
      'source': 'your_cart_checkout_button',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return cartRef.id;
  }

  Future<void> _showCheckoutDialog() async {
    final total = _getTotalPrice();
    final itemCount = selectedCount;
    final selectedItems = selectedIngredientsMap.values.where((item) => item.isChecked).toList();

    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your cart is empty'),
          backgroundColor: _orangeDark,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final cartItems = selectedItems
        .map((item) => {
      'ingredientId': item.ingredient.id,
      'name': item.ingredient.name,
      'category': item.ingredient.category,
      'price': item.ingredient.price ?? 0.0,
      'quantity': item.quantity,
      'image': item.ingredient.imageUrl,
      'unit': item.ingredient.unit ?? 'kg',
      'currency': item.ingredient.currency ?? 'EGP',
      'lineTotal': (item.ingredient.price ?? 0.0) * item.quantity,
    })
        .toList();

    String? checkoutCartId;
    try {
      checkoutCartId = await _saveCheckoutCartSnapshot(
        cartItems: cartItems,
        subtotal: total,
        itemCount: itemCount,
      );
    } catch (e) {
      debugPrint('Error saving checkout cart snapshot: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your cart for checkout. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted || checkoutCartId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          subtotal: total,
          itemCount: itemCount,
          cartItems: cartItems,
          checkoutCartId: checkoutCartId,
        ),
      ),
    );
  }

  Future<bool> _removeIngredientLocal(String ingredientId) async {
    if (_cartActionInProgress.contains(ingredientId)) return false;

    final previousItem = selectedIngredientsMap[ingredientId];
    if (previousItem == null) return false;

    _cartActionInProgress.add(ingredientId);
    _pendingRemovedCartIds.add(ingredientId);
    _pendingCartQuantities.remove(ingredientId);

    setState(() => selectedIngredientsMap.remove(ingredientId));

    try {
      await _deleteCartIngredient(ingredientId);
      return true;
    } catch (e) {
      debugPrint('Error removing cart ingredient: $e');
      _pendingRemovedCartIds.remove(ingredientId);
      if (!mounted) return false;
      setState(() => selectedIngredientsMap[ingredientId] = previousItem);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove item from cart.'), backgroundColor: Colors.red),
      );
      return false;
    } finally {
      _cartActionInProgress.remove(ingredientId);
    }
  }

  Future<void> _clearCartLocal() async {
    final previousItems = Map<String, SelectedIngredientData>.from(selectedIngredientsMap);
    _pendingRemovedCartIds.addAll(previousItems.keys);
    _pendingCartQuantities.clear();
    setState(() => selectedIngredientsMap.clear());

    try {
      await _clearUserShopCart();
    } catch (e) {
      debugPrint('Error clearing shop cart: $e');
      _pendingRemovedCartIds.removeAll(previousItems.keys);
      if (!mounted) return;
      setState(() => selectedIngredientsMap = previousItems);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not clear cart.'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildIngredientImage(IngredientModel ingredient, double size) {
    return CustomCachedImage(
      imageUrl: ingredient.imageUrl,
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholder: Center(
        child: SizedBox(
          width: size * 0.35,
          height: size * 0.35,
          child: const CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(_orangeDark)),
        ),
      ),
      errorWidget: Icon(Icons.restaurant, size: size * 0.55, color: _orangeDark.withOpacity(0.7)),
    );
  }

  Future<String?> _getFirestoreFirstName(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final firstName = (doc.data()?['firstName'] as String?)?.trim();
      if (firstName != null && firstName.isNotEmpty) return firstName;
    } catch (_) {}
    return null;
  }

  String? _extractFirstName(String? displayName) {
    final value = (displayName ?? '').trim();
    if (value.isEmpty) return null;
    return value.split(RegExp(r'\s+')).first;
  }

  Future<String?> _getCachedFirstNameFuture(User user) {
    if (_cachedFirstNameUid != user.uid || _cachedFirstNameFuture == null) {
      _cachedFirstNameUid = user.uid;
      _cachedFirstNameFuture = _getFirestoreFirstName(user.uid);
    }
    return _cachedFirstNameFuture!;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final fallbackName = _extractFirstName(currentUser?.displayName) ?? 'Chef';
    final bottomSafePadding = MediaQuery.of(context).padding.bottom + 60.0;

    if (isLoading) {
      return const Scaffold(
        backgroundColor: background,
        body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_orangeDark))),
      );
    }

    if (currentUser == null) {
      selectedIngredientsMap = {};
      return _buildShopScaffold(
        currentUser: currentUser,
        fallbackName: fallbackName,
        bottomSafePadding: bottomSafePadding,
      );
    }

    return StreamBuilder<List<SavedIngredientSelection>>(
      stream: _streamUserShopCart(currentUser.uid),
      builder: (context, cartSnapshot) {
        if (cartSnapshot.hasData) {
          final streamIds = cartSnapshot.data!
              .map((selection) => selection.ingredient.id)
              .toSet();

          // Once Firestore confirms an item is gone, stop guarding it.
          _pendingRemovedCartIds.removeWhere((id) => !streamIds.contains(id));

          final streamedCartMap = <String, SelectedIngredientData>{
            for (final selection in cartSnapshot.data!)
              if (!_pendingRemovedCartIds.contains(selection.ingredient.id))
                selection.ingredient.id: SelectedIngredientData(
                  ingredient: selection.ingredient,
                  quantity: _pendingCartQuantities[selection.ingredient.id] ?? selection.quantity,
                  isChecked: true,
                ),
          };

          // Keep locally changed items visible while their Firestore write is pending.
          for (final entry in _pendingCartQuantities.entries) {
            if (_pendingRemovedCartIds.contains(entry.key)) continue;
            final localItem = selectedIngredientsMap[entry.key];
            if (localItem != null) {
              streamedCartMap[entry.key] = SelectedIngredientData(
                ingredient: localItem.ingredient,
                quantity: entry.value,
                isChecked: true,
              );
            }
          }

          selectedIngredientsMap = streamedCartMap;
        }

        return _buildShopScaffold(
          currentUser: currentUser,
          fallbackName: fallbackName,
          bottomSafePadding: bottomSafePadding,
        );
      },
    );
  }

  Widget _buildShopScaffold({
    required User? currentUser,
    required String fallbackName,
    required double bottomSafePadding,
  }) {
    return Scaffold(
      backgroundColor: background,
      body: Column(
        children: [
          FutureBuilder<String?>(
            future: currentUser == null ? Future<String?>.value(null) : _getCachedFirstNameFuture(currentUser),
            builder: (context, nameSnapshot) {
              final resolvedName = (nameSnapshot.data != null && nameSnapshot.data!.isNotEmpty) ? nameSnapshot.data! : fallbackName;
              return _ShopTopHeader(
                displayName: resolvedName,
                cartCount: selectedCount,
                searchController: _searchController,
                onSearchChanged: _handleSearchChanged,
                onVoiceTap: _openVoiceSearch,
                onCartTap: _showCartPopup,
                onOrdersTap: currentUser == null
                    ? null
                    : () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
                ),
                onProfileTap: currentUser == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
                onSettingsTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
              );
            },
          ),
          Expanded(
            child: StreamBuilder<List<IngredientModel>>(
              stream: selectedCategory == 'All'
                  ? _ingredientService.getAllIngredients()
                  : _ingredientService.getIngredientsByCategoryStream(selectedCategory),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            _initializeIngredients();
                            _loadBestSellers();
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: _orangeDark),
                          child: const Text('Retry', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_orangeDark)));
                }

                final ingredients = _applySearch(snapshot.data!);
                final displayCategories = _getDisplayCategories(categories);

                return CustomScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    if (!isCategoryOpened) ...[
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: GroceryHeader(),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Shop by Category',
                                style: TextStyle(color: _brown, fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                              if (categories.length > 12)
                                GestureDetector(
                                  onTap: () => setState(() => showAllCategories = !showAllCategories),
                                  child: Text(
                                    showAllCategories ? 'See less' : 'See all',
                                    style: const TextStyle(
                                      color: _orangeDark,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      // Replace the existing SliverGrid in the build method (around line 470)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.88,  // Changed to 0.68 for taller tiles (accommodates larger images)
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 16,
                          ),
                          delegate: SliverChildBuilderDelegate(
                                (context, index) {
                              final category = displayCategories[index];
                              return _CategoryTile(
                                title: category,
                                imagePath: _categoryIconPath(category),
                                icon: null,
                                isSelected: false,
                                onTap: () => setState(() {
                                  selectedCategory = category;
                                  isCategoryOpened = true;
                                  searchQuery = '';
                                  _searchController.clear();
                                }),
                              );
                            },
                            childCount: displayCategories.length,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(18, 24, 18, 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '🔥 Best Sellers',
                                style: TextStyle(color: _brown, fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isLoadingBestSellers)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(_orangeDark)),
                            ),
                          ),
                        )
                      else
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 210,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              itemCount: bestSellers.length,
                              itemBuilder: (context, index) {
                                final ingredient = bestSellers[index];
                                final isSelected = selectedIngredientsMap.containsKey(ingredient.id) && selectedIngredientsMap[ingredient.id]!.isChecked;
                                final price = _getIngredientPrice(ingredient);
                                final rank = index + 1;

                                return Container(
                                  width: 150,
                                  margin: const EdgeInsets.only(right: 12),
                                  child: _BestSellerCard(
                                    ingredient: ingredient,
                                    isSelected: isSelected,
                                    price: price,
                                    rank: rank,
                                    formattedPrice: _getFormattedPrice(ingredient),
                                    orderCount: _bestSellersLoadedFromOrders
                                        ? _bestSellerOrderCounts[ingredient.id]
                                        : null,
                                    onTap: () => _openIngredientDetail(ingredient),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      SliverToBoxAdapter(child: SizedBox(height: bottomSafePadding)),
                    ] else ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => setState(() {
                                  isCategoryOpened = false;
                                  selectedCategory = 'All';
                                  searchQuery = '';
                                  _searchController.clear();
                                }),
                                child: Container(
                                  height: 38,
                                  width: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: _border),
                                  ),
                                  child: const Icon(Icons.arrow_back_rounded, color: _orangeDark, size: 22),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _openedTitle(ingredients),
                                      style: const TextStyle(color: _brown, fontSize: 20, fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      searchQuery.trim().isEmpty
                                          ? '${ingredients.length} ${ingredients.length == 1 ? 'item' : 'items'} available'
                                          : '${ingredients.length} ${ingredients.length == 1 ? 'result' : 'results'} found',
                                      style: const TextStyle(color: _mutedBrown, fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              if (selectedCount > 0)
                                GestureDetector(
                                  onTap: _showCartPopup,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(color: _orangeDark, borderRadius: BorderRadius.circular(18)),
                                    child: Text(
                                      '$selectedCount in cart',
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (ingredients.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off, size: 54, color: _orangeDark),
                                SizedBox(height: 12),
                                Text('No ingredients found', style: TextStyle(color: _brown, fontSize: 16, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(18, 0, 18, bottomSafePadding),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                final ingredient = ingredients[index];
                                final isSelected = selectedIngredientsMap.containsKey(ingredient.id) &&
                                    selectedIngredientsMap[ingredient.id]!.isChecked;
                                final price = _getIngredientPrice(ingredient);

                                return _ShopIngredientCard(
                                  ingredient: ingredient,
                                  isSelected: isSelected,
                                  price: price,
                                  formattedPrice: _getFormattedPrice(ingredient),
                                  unit: _getUnitText(ingredient),
                                  currentQuantity: selectedIngredientsMap[ingredient.id]?.quantity ?? 0.0,
                                  onAddToCart: () => toggleIngredient(ingredient),
                                  onQuantityChanged: (quantity) async {
                                    if (quantity > 0) {
                                      final safeQuantity = quantity.clamp(0.1, 100.0).toDouble();

                                      // Update the parent UI first so the first tap is visible immediately.
                                      _pendingRemovedCartIds.remove(ingredient.id);
                                      _pendingCartQuantities[ingredient.id] = safeQuantity;
                                      if (mounted) {
                                        setState(() {
                                          selectedIngredientsMap[ingredient.id] = SelectedIngredientData(
                                            ingredient: ingredient,
                                            quantity: safeQuantity,
                                            isChecked: true,
                                          );
                                        });
                                      }

                                      try {
                                        await _saveCartIngredient(ingredient: ingredient, quantity: safeQuantity);
                                        _pendingCartQuantities.remove(ingredient.id);
                                        if (mounted) setState(() {});
                                      } catch (e) {
                                        _pendingCartQuantities.remove(ingredient.id);
                                        debugPrint('Error saving cart quantity: $e');
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Could not update cart.'), backgroundColor: Colors.red),
                                        );
                                      }
                                    } else {
                                      await _removeIngredientLocal(ingredient.id);
                                    }
                                  },
                                );
                              },
                              childCount: ingredients.length,
                            ),
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        backgroundColor: _orangeDark,
        onPressed: _showCartPopup,
        child: Stack(
          children: [
            const Icon(Icons.shopping_cart, color: Colors.white),
            if (selectedCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    selectedCount > 9 ? '9+' : '$selectedCount',
                    style: const TextStyle(color: _orangeDark, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class GroceryHeader extends StatelessWidget {
  const GroceryHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFD6A5),
                  Color(0xFFFFF0E0),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD6A5).withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "FRESH & QUALITY",
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFFB87313),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Fresh ingredients,\ndelivered fast 🚀",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3A2214),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Get market-fresh groceries\nat your door in 30 mins.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8B7355),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/pngtree-grocery-bag.png',
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
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

class _ShopTopHeader extends StatelessWidget {
  const _ShopTopHeader({
    required this.displayName,
    required this.cartCount,
    required this.searchController,
    required this.onSearchChanged,
    required this.onVoiceTap,
    required this.onCartTap,
    this.onOrdersTap,
    this.onProfileTap,
    required this.onSettingsTap,
  });

  final String displayName;
  final int cartCount;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onVoiceTap;
  final VoidCallback onCartTap;
  final VoidCallback? onOrdersTap;
  final VoidCallback? onProfileTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18, topInset + 10, 18, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFCC7705), Color(0xFFDD8E1E), Color(0xFFF0A73A)],
          stops: [0.0, 0.35, 1.0],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _HeroBackgroundPainter()),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (onProfileTap != null)
                    GestureDetector(
                      onTap: onProfileTap,
                      child: const CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(0xFFD28E18),
                        child: Icon(Icons.person, color: Colors.white, size: 22),
                      ),
                    ),
                  if (onProfileTap != null) const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Shop Fresh',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _CircleActionButton(
                    icon: Icons.shopping_cart_outlined,
                    onTap: onCartTap,
                    badgeCount: cartCount,
                  ),
                  const SizedBox(width: 8),
                  if (onOrdersTap != null) ...[
                    _CircleActionButton(
                      icon: Icons.receipt_long_outlined,
                      onTap: onOrdersTap!,
                    ),
                    const SizedBox(width: 8),
                  ],
                  _CircleActionButton(
                    icon: Icons.settings_outlined,
                    onTap: onSettingsTap,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Shop Groceries',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 23,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Fresh ingredients delivered',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 23,
                  height: 1.20,
                ),
              ),
              const SizedBox(height: 25),
              Container(
                height: 50,
                padding: const EdgeInsets.only(left: 18, right: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(27),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF888888),
                      size: 30,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        onChanged: onSearchChanged,
                        cursorColor: const Color(0xFF6A6A6A),
                        style: const TextStyle(color: Color(0xFF2F2F2F)),
                        decoration: const InputDecoration(
                          hintText: 'Search ingredients...',
                          hintStyle: TextStyle(color: Color(0xFF6A6A6A)),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onVoiceTap,
                      icon: const Icon(
                        Icons.keyboard_voice_rounded,
                        color: Color(0xFF4D4D4D),
                        size: 27,
                      ),
                      splashRadius: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({required this.icon, required this.onTap, this.badgeCount = 0});

  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF6C6C6C), size: 21),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -2,
              top: -3,
              child: Container(
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFFB87313),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    ringPaint
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 34;
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * 0.92, size.height * 0.20),
        radius: size.height * 1.02,
      ),
      math.pi * 0.58,
      math.pi * 0.58,
      false,
      ringPaint,
    );

    ringPaint
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 20;
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * 1.02, size.height * 0.06),
        radius: size.height * 0.86,
      ),
      math.pi * 0.52,
      math.pi * 0.52,
      false,
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.title, required this.imagePath, this.icon, required this.isSelected, required this.onTap});

  final String title;
  final String imagePath;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Responsive sizing based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final isMediumScreen = screenWidth >= 400 && screenWidth < 600;

    // Larger image sizes
    final imageSize = isSmallScreen ? 60.0 : (isMediumScreen ? 70.0 : 80.0);
    final fontSize = isSmallScreen ? 11.0 : (isMediumScreen ? 12.0 : 13.0);
    final iconSize = imageSize * 0.5;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFF8E9).withOpacity(0.95)
              : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFB87313).withOpacity(0.8)
                : Colors.white.withOpacity(0.5),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: const Color(0xFFB87313).withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ]
              : [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image Container - Larger size
            Container(
              width: imageSize,
              height: imageSize,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFF7F1DE).withOpacity(0.7),
                    const Color(0xFFFCF7E8).withOpacity(0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Center(
                  child: icon != null
                      ? Icon(
                    icon,
                    color: const Color(0xFF5C8E3E),
                    size: iconSize,
                  )
                      : Image.asset(
                    imagePath,
                    width: imageSize * 0.7,
                    height: imageSize * 0.7,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.category_rounded,
                      color: const Color(0xFF5C8E3E),
                      size: iconSize,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFB87313) : const Color(0xFF3A2214),
                  fontSize: fontSize,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopIngredientCard extends StatelessWidget {
  const _ShopIngredientCard({
    required this.ingredient,
    required this.isSelected,
    required this.price,
    required this.formattedPrice,
    required this.unit,
    required this.currentQuantity,
    required this.onAddToCart,
    required this.onQuantityChanged,
  });

  final IngredientModel ingredient;
  final bool isSelected;
  final double price;
  final String formattedPrice;
  final String unit;
  final double currentQuantity;
  final Future<void> Function() onAddToCart;
  final Future<void> Function(double quantity) onQuantityChanged;

  bool get _isBreadIngredient {
    final category = ingredient.category.toLowerCase().trim();
    final name = ingredient.name.toLowerCase().trim();

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

    final rawUnit = unit.toLowerCase().trim();
    final name = ingredient.name.toLowerCase();

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

    if (liquidUnits.contains(rawUnit)) return true;

    return RegExp(r'\b(milk|oil|juice|water|soda|drink|beverage|vinegar|syrup|sauce)\b')
        .hasMatch(name);
  }

  String get _largeUnitLabel => _usesLiquidUnit ? 'L' : 'KG';

  String get _smallUnitLabel => _usesLiquidUnit ? 'ml' : 'g';

  double get _safeQuantity {
    if (!isSelected || currentQuantity <= 0) return 0.0;
    return currentQuantity.clamp(0.1, 100.0).toDouble();
  }

  String _formatNumber(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }

  String _formatQuantityDisplay(double value) {
    if (value <= 0) return _isBreadIngredient ? 'Quantity' : 'per $_largeUnitLabel';

    // Bread must stay as plain quantity only.
    if (_isBreadIngredient) return _formatNumber(value);

    if (value < 1) {
      final smallValue = value * 1000;
      final smallText = smallValue % 1 == 0
          ? smallValue.toInt().toString()
          : smallValue.toStringAsFixed(1);
      return '$smallText $_smallUnitLabel';
    }

    return '${_formatNumber(value)} $_largeUnitLabel';
  }

  String get _unitPriceDisplay {
    if (_isBreadIngredient) {
      return '${price.toStringAsFixed(2)} EGP / quantity';
    }
    return formattedPrice;
  }

  String get _mainPriceDisplay {
    final quantity = _safeQuantity;
    if (quantity > 0) {
      return '${(price * quantity).toStringAsFixed(2)} EGP';
    }
    return _unitPriceDisplay;
  }

  String _getCategoryDisplay() {
    final category = ingredient.category;
    if (category.toLowerCase() == 'fruits') return 'Fruits';
    return category;
  }

  void _openDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IngredientDetailScreen(
          ingredient: ingredient,
          initialQuantity: _safeQuantity > 0 ? _safeQuantity : 1.0,
          isInCart: isSelected,
          onAddToCart: (detailIngredient, detailQuantity) async {
            final safeQuantity = detailQuantity.clamp(0.1, 100.0).toDouble();
            await onQuantityChanged(safeQuantity);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quantity = _safeQuantity;

    return InkWell(
      onTap: () => _openDetails(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFB87313) : const Color(0xFFE8DCC8),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F1DE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CustomCachedImage(
                  imageUrl: ingredient.imageUrl,
                  width: 90,
                  height: 90,
                  fit: BoxFit.contain,
                  placeholder: const Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB87313)),
                      ),
                    ),
                  ),
                  errorWidget: Icon(
                    Icons.restaurant,
                    size: 40,
                    color: const Color(0xFFB87313).withOpacity(0.6),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ingredient.name,
                          style: const TextStyle(
                            color: Color(0xFF3A2214),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _mainPriceDisplay,
                          style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (quantity > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            _unitPriceDisplay,
                            style: const TextStyle(
                              color: Color(0xFF8B7355),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      _getCategoryDisplay(),
                      style: const TextStyle(
                        color: Color(0xFFB87313),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 82,
              height: 90,
              child: isSelected
                  ? _SelectedCardActions(
                quantityText: _formatQuantityDisplay(quantity),
                onEdit: () => _openDetails(context),
                onRemove: onAddToCart,
              )
                  : _AddCardButton(onTap: () async => _openDetails(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCardButton extends StatefulWidget {
  const _AddCardButton({required this.onTap});

  final Future<void> Function() onTap;

  @override
  State<_AddCardButton> createState() => _AddCardButtonState();
}

class _AddCardButtonState extends State<_AddCardButton> {
  bool _loading = false;

  Future<void> _handleTap() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onTap();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
          width: 74,
          height: 34,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFB87313), Color(0xFFD99622)],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: _loading
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 16, color: Colors.white),
              SizedBox(width: 3),
              Text(
                'ADD',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedCardActions extends StatefulWidget {
  const _SelectedCardActions({
    required this.quantityText,
    required this.onEdit,
    required this.onRemove,
  });

  final String quantityText;
  final VoidCallback onEdit;
  final Future<void> Function() onRemove;

  @override
  State<_SelectedCardActions> createState() => _SelectedCardActionsState();
}

class _SelectedCardActionsState extends State<_SelectedCardActions> {
  bool _removing = false;

  Future<void> _handleRemove() async {
    if (_removing) return;
    setState(() => _removing = true);
    try {
      await widget.onRemove();
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 82),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7E6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2C9A4), width: 1),
          ),
          child: Text(
            widget.quantityText,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFB87313),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _SmallCardIconButton(
              icon: Icons.edit_outlined,
              onTap: widget.onEdit,
            ),
            const SizedBox(width: 6),
            _SmallCardIconButton(
              icon: Icons.delete_outline,
              isBusy: _removing,
              onTap: _handleRemove,
            ),
          ],
        ),
      ],
    );
  }
}

class _SmallCardIconButton extends StatelessWidget {
  const _SmallCardIconButton({
    required this.icon,
    required this.onTap,
    this.isBusy = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isBusy ? null : onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE2C9A4), width: 1),
        ),
        alignment: Alignment.center,
        child: isBusy
            ? const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFB87313),
          ),
        )
            : Icon(icon, size: 17, color: const Color(0xFFB87313)),
      ),
    );
  }
}

class _BestSellerCard extends StatelessWidget {
  const _BestSellerCard({
    required this.ingredient,
    required this.isSelected,
    required this.price,
    required this.rank,
    required this.formattedPrice,
    this.orderCount,
    required this.onTap,
  });

  final IngredientModel ingredient;
  final bool isSelected;
  final double price;
  final int rank;
  final String formattedPrice;
  final int? orderCount;
  final VoidCallback onTap;



  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final imageSize = screenWidth < 600 ? 70.0 : 80.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF7E6) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFFB87313) : const Color(0xFFE2C9A4), width: isSelected ? 2 : 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: rank == 1 ? const Color(0xFFB87313) : (const Color(0xFFB87313).withOpacity(0.15)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (rank == 1)
                        const Icon(Icons.emoji_events, size: 12, color: Colors.amber),
                      if (rank == 1) const SizedBox(width: 4),
                      Text(
                        rank == 1 ? 'Top' : '#$rank',
                        style: TextStyle(
                          color: rank == 1 ? Colors.amber[800] : const Color(0xFFB87313),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: CustomCachedImage(
                    imageUrl: ingredient.imageUrl,
                    width: imageSize,
                    height: imageSize,
                    fit: BoxFit.contain,
                    placeholder: SizedBox(
                      width: imageSize * 0.35,
                      height: imageSize * 0.35,
                      child: const CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB87313))),
                    ),
                    errorWidget: Icon(Icons.restaurant, size: imageSize * 0.52, color: const Color(0xFFB87313).withOpacity(0.7)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ingredient.name,
                  style: const TextStyle(
                    color: Color(0xFF3A2214),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formattedPrice,
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFB87313) : const Color(0xFF2E7D32),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSelected ? Icons.check : Icons.add,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SelectedIngredientData {
  final IngredientModel ingredient;
  final double quantity;
  final bool isChecked;

  SelectedIngredientData({
    required this.ingredient,
    required this.quantity,
    required this.isChecked,
  });
}