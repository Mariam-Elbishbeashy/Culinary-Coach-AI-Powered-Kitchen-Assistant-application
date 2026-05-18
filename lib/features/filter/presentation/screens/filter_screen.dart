import 'dart:math' as math;

// ignore_for_file: deprecated_member_use, unnecessary_underscores
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/core/widgets/current_user_avatar.dart';
import 'package:culinary_coach_app/features/filter/data/models/ingredient_model.dart';
import 'package:culinary_coach_app/features/filter/data/services/ingredient_service.dart';
import 'package:culinary_coach_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:culinary_coach_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:culinary_coach_app/features/filter/widgets/custom_image_cache.dart';
import 'scan.dart';
import 'voice.dart';

/// Main pantry/filter screen where the user can search, scan, and select ingredients.
///
/// This widget is stateful because the selected category, search text, loading
/// state, and selected ingredients all change while the user interacts with it.
class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

/// State class that contains all screen logic for ingredients, categories,
/// searching, selection, quantities, Firestore synchronization, and UI building.
class _FilterScreenState extends State<FilterScreen> {
  /// Service responsible for loading ingredients/categories and saving the
  /// user's selected pantry ingredients in Firestore.
  final IngredientService _ingredientService = IngredientService();

  /// Controller used to read and update the search input programmatically,
  /// especially after voice search or when clearing the category view.
  final TextEditingController _searchController = TextEditingController();


  /// Stores the selected ingredients using the ingredient ID as the key.
  ///
  /// This makes checking, updating, and removing selected ingredients fast.
  Map<String, SelectedIngredientData> selectedIngredientsMap = {};


  /// Currently opened category. `All` means the screen shows all ingredients.
  String selectedCategory = 'All';

  /// Available ingredient categories. It starts with `All` until Firestore data loads.
  List<String> categories = ['All'];

  /// Controls the first loading screen while categories are being loaded.
  bool isLoading = true;

  /// Current text written in the search bar.
  String searchQuery = '';

  /// Decides whether the categories grid shows only the first 11 categories
  /// plus `More`, or all categories plus `Less`.
  bool showAllCategories = false;

  /// Decides whether the user is on the starting category page or inside
  /// the ingredients/results page.
  bool isCategoryOpened = false;


  /// Main dark orange color used for selected states, badges, and buttons.
  static const Color _orangeDark = Color(0xFFB87313);
  /// Main orange accent used for highlights and soft backgrounds.
  static const Color _orange = Color(0xFFD99622);
  /// Page background color.
  static const Color _cream = Color(0xFFF7F1DE);
  /// Card/dialog background color.
  static const Color _cardCream = Color(0xFFFCF7E8);
  /// Main text color.
  static const Color _brown = Color(0xFF3A2214);
  /// Secondary text color.
  static const Color _mutedBrown = Color(0xFF8B7355);
  /// Shared border color for cards, buttons, and chips.
  static const Color _border = Color(0xFFE2C9A4);


  /// Number of currently checked ingredients.
  int get selectedCount => selectedIngredientsMap.values.where((item) => item.isChecked).length;


  /// Returns only the ingredient models that are currently selected.
  ///
  /// This can be used by other parts of the app to know what the user has
  /// in their pantry/filter list.
  List<IngredientModel> getSelectedIngredients() {
    return selectedIngredientsMap.values
        .where((item) => item.isChecked)
        .map((item) => item.ingredient)
        .toList();
  }

  @override
  /// Runs once when the screen is created.
  ///
  /// It starts loading the ingredient categories immediately.
  void initState() {
    super.initState();
    _initializeIngredients();
  }

  @override
  /// Cleans the search controller when the screen is removed to avoid memory leaks.
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Loads all ingredient categories from the ingredient service.
  ///
  /// If the category list does not already contain `All`, it adds it manually
  /// so the user can always return to a global ingredient view.
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
      debugPrint('Error loading ingredients: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading ingredients: $e'), backgroundColor: Colors.red),
      );
    }
  }


  /// Shortcut getter for the currently signed-in Firebase user ID.
  ///
  /// Returns `null` when no user is signed in.
  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;


  /// Shows a message when the user tries to save ingredients without signing in.
  void _showAuthRequiredMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please sign in to save your selected ingredients.'),
        backgroundColor: _orangeDark,
        duration: Duration(seconds: 2),
      ),
    );
  }


  /// Selects or unselects an ingredient.
  ///
  /// The UI is updated immediately, then Firestore is updated. If the ingredient
  /// was already selected, it is removed. Otherwise, it is added with quantity 1.0.
  Future<void> toggleIngredient(IngredientModel ingredient) async {
    final userId = _currentUserId;
    if (userId == null) {
      _showAuthRequiredMessage();
      return;
    }

    final isAlreadySelected =
        selectedIngredientsMap.containsKey(ingredient.id) &&
            selectedIngredientsMap[ingredient.id]!.isChecked;

    setState(() {
      if (isAlreadySelected) {
        selectedIngredientsMap.remove(ingredient.id);
      } else {
        selectedIngredientsMap[ingredient.id] = SelectedIngredientData(
          ingredient: ingredient,
          quantity: 1.0,
          isChecked: true,
        );
      }
    });

    try {
      if (isAlreadySelected) {
        await _ingredientService.deleteUserSelectedIngredient(
          userId: userId,
          ingredientId: ingredient.id,
        );
      } else {
        await _ingredientService.saveUserSelectedIngredient(
          userId: userId,
          ingredient: ingredient,
          quantity: 1.0,
        );
      }
    } catch (e) {
      debugPrint('Error updating selected ingredient: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update ${ingredient.name}. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  /// Updates the saved quantity for a selected ingredient.
  ///
  /// Quantity is clamped between 0.1 and 100.0 to avoid invalid or extreme values.
  Future<void> updateQuantity(String ingredientId, double newQuantity) async {
    final userId = _currentUserId;
    if (userId == null) {
      _showAuthRequiredMessage();
      return;
    }

    if (!selectedIngredientsMap.containsKey(ingredientId)) return;

    final current = selectedIngredientsMap[ingredientId]!;
    final previousQuantity = current.quantity;
    final safeQuantity = newQuantity.clamp(0.1, 100.0).toDouble();

    // Update UI immediately first. Firestore is updated right after.
    setState(() {
      selectedIngredientsMap[ingredientId] = SelectedIngredientData(
        ingredient: current.ingredient,
        quantity: safeQuantity,
        isChecked: current.isChecked,
      );
    });

    try {
      await _ingredientService.updateUserSelectedIngredientQuantity(
        userId: userId,
        ingredientId: ingredientId,
        quantity: safeQuantity,
      );
    } catch (e) {
      debugPrint('Error updating quantity: $e');

      // If saving fails, restore the old quantity so UI and database do not disagree.
      if (mounted && selectedIngredientsMap.containsKey(ingredientId)) {
        final latest = selectedIngredientsMap[ingredientId]!;
        setState(() {
          selectedIngredientsMap[ingredientId] = SelectedIngredientData(
            ingredient: latest.ingredient,
            quantity: previousQuantity,
            isChecked: latest.isChecked,
          );
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update quantity. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  /// Reads the most recent quantity shown inside the selected ingredients dialog.
  ///
  /// If the ingredient is not found, it returns the fallback value.
  double _currentDialogQuantity(String ingredientId, double fallback) {
    final item = selectedIngredientsMap[ingredientId];
    if (item == null) return fallback;
    return item.quantity;
  }


  /// Changes ingredient quantity directly from the selected ingredients popup.
  ///
  /// It refreshes the dialog instantly so the user sees the number change after
  /// one tap, then saves the new quantity to Firestore.
  Future<void> _changeQuantityFromDialog({
    required String ingredientId,
    required double delta,
    required VoidCallback refreshDialog,
  }) async {
    final currentItem = selectedIngredientsMap[ingredientId];
    if (currentItem == null) return;

    final newQuantity = (currentItem.quantity + delta).clamp(0.1, 100.0).toDouble();

    // Refresh dialog immediately so one tap changes the number at once.
    setState(() {
      selectedIngredientsMap[ingredientId] = SelectedIngredientData(
        ingredient: currentItem.ingredient,
        quantity: newQuantity,
        isChecked: currentItem.isChecked,
      );
    });
    refreshDialog();

    final userId = _currentUserId;
    if (userId == null) {
      _showAuthRequiredMessage();
      return;
    }

    try {
      await _ingredientService.updateUserSelectedIngredientQuantity(
        userId: userId,
        ingredientId: ingredientId,
        quantity: newQuantity,
      );
    } catch (e) {
      debugPrint('Error updating quantity: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update quantity. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  /// Removes a single ingredient from the selected pantry list and Firestore.
  Future<void> removeIngredient(String ingredientId) async {
    final userId = _currentUserId;
    if (userId == null) {
      _showAuthRequiredMessage();
      return;
    }

    setState(() => selectedIngredientsMap.remove(ingredientId));

    try {
      await _ingredientService.deleteUserSelectedIngredient(
        userId: userId,
        ingredientId: ingredientId,
      );
    } catch (e) {
      debugPrint('Error removing ingredient: $e');
    }
  }


  /// Clears all selected ingredients from the local UI and Firestore.
  Future<void> clearSelections() async {
    final userId = _currentUserId;
    if (userId == null) {
      _showAuthRequiredMessage();
      return;
    }

    setState(() => selectedIngredientsMap.clear());

    try {
      await _ingredientService.clearUserSelectedIngredients(userId);
    } catch (e) {
      debugPrint('Error clearing ingredients: $e');
    }
  }



  /// Decides which category tiles should be visible.
  ///
  /// If there are more than 12 categories, the first view shows 11 categories
  /// and a `More` tile. When expanded, it shows all categories and a `Less` tile.
  List<String> _visibleCategoryTiles(List<String> allCategories) {
    final cleaned = allCategories.where((category) => category.trim().isNotEmpty).toList();
    if (cleaned.length <= 12) return cleaned;

    if (showAllCategories) {
      return [...cleaned, '__less__'];
    }

    final firstEleven = cleaned.take(11).toList();
    return [...firstEleven, '__more__'];
  }


  /// Normalizes search text before matching.
  ///
  /// It lowercases the text, removes unsupported symbols, and collapses
  /// repeated spaces so search comparisons become easier and cleaner.
  String _normalizeSearchText(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s,/-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }


  /// Converts the raw search input into searchable terms.
  ///
  /// Comma-separated input keeps phrases together, while space-separated input
  /// is split into individual words. Common stop words are removed.
  List<String> _extractSearchTerms(String value) {
    final normalized = _normalizeSearchText(value);
    if (normalized.isEmpty) return [];

    final stopWords = <String>{
      'and',
      'or',
      'with',
      'for',
      'the',
      'a',
      'an',
      'of',
      'to',
      'in',
      'please',
      'search',
      'ingredient',
      'ingredients',
    };

    // If the user writes: milk, chicken breast, rice
    // keep comma-separated phrases together.
    if (normalized.contains(',')) {
      return normalized
          .split(',')
          .map((term) => term.trim())
          .where((term) => term.isNotEmpty && !stopWords.contains(term))
          .toSet()
          .toList();
    }

    // If the user writes: milk chicken rice
    // search each word separately so more ingredients can appear.
    return normalized
        .split(RegExp(r'\s+'))
        .map((term) => term.trim())
        .where((term) => term.length > 1 && !stopWords.contains(term))
        .toSet()
        .toList();
  }


  /// Checks whether an ingredient matches at least one search term.
  ///
  /// If a category is open, the search checks ingredient names only.
  /// If `All` is open, the search checks both ingredient names and categories.
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

      // When a category is already opened, search only inside that category by ingredient name.
      if (selectedCategory != 'All') {
        if (ingredientName.contains(normalizedTerm)) return true;
        continue;
      }

      // When no specific category is selected, search globally by ingredient name and category.
      if (ingredientName.contains(normalizedTerm) || ingredientCategory.contains(normalizedTerm)) {
        return true;
      }
    }

    return false;
  }


  /// Applies the current search query to a list of ingredients.
  List<IngredientModel> _applySearch(List<IngredientModel> ingredients) {
    final terms = _extractSearchTerms(searchQuery);
    if (terms.isEmpty) return ingredients;

    return ingredients.where((ingredient) {
      return _ingredientMatchesAnySearchTerm(ingredient: ingredient, terms: terms);
    }).toList();
  }


  /// Chooses the title shown above the ingredient results grid.
  ///
  /// It can show the selected category, `Search Results`, the best matched
  /// ingredient category, or `All Ingredients`.
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


  /// Handles every change in the search field.
  ///
  /// Typing opens the ingredient results page automatically. Clearing a global
  /// search returns the user back to the scan/categories start view.
  void _handleSearchChanged(String value) {
    final query = value.trim();

    setState(() {
      searchQuery = value;

      // From the beginning page: typing immediately opens the ingredients area.
      if (query.isNotEmpty && !isCategoryOpened) {
        isCategoryOpened = true;
        selectedCategory = 'All';
      }

      // If the user clears a global search, return to the scan/categories start view.
      if (query.isEmpty && selectedCategory == 'All' && isCategoryOpened) {
        isCategoryOpened = false;
      }
    });
  }


  /// Returns the local asset path used as the icon for a category.
  ///
  /// If no matching asset exists, an empty string is returned and the category
  /// tile will fall back to its default error icon.
  String _categoryIconPath(String category) {
    final key = category.toLowerCase().trim();
    final map = <String, String>{
      'all': 'assets/images/all-ingredients.png',
      'asian': 'assets/images/asian.png',
      'baking': 'assets/images/bake.png',
      'breads': 'assets/images/breads.png',
      'breakfast': 'assets/images/breakfast.png',
      'broths': 'assets/images/broths.png',
      'canned goods': 'assets/images/canned-food.png',
      'dairy': 'assets/images/dairy-products.png',
      'beverages': 'assets/images/drinks.png',
      'frozen foods': 'assets/images/frozen-foods.png',
      'fruits': 'assets/images/fruit.png',
      'herbs': 'assets/images/herbs.png',
      'grains': 'assets/images/grains.png',
      'legumes': 'assets/images/legumes.png',
      'beans': 'assets/images/legumes.png',
      'meat': 'assets/images/meat.png',
      'middle eastern': 'assets/images/middle-easter.png',
      'nuts': 'assets/images/nuts.png',
      'oils': 'assets/images/oil.png',
      'sauces': 'assets/images/sauces.png',
      'seafood': 'assets/images/seafood.png',
      'seeds': 'assets/images/seeds.png',
      'snacks': 'assets/images/snacks.png',
      'spices': 'assets/images/spice.png',
      'spice blends': 'assets/images/spices-blends.png',
      'sweeteners': 'assets/images/sweeteners.png',
      'vegetables': 'assets/images/vegetable (1).png',
    };
    return map[key] ?? '';
  }


  /// Opens the voice search screen and uses the returned spoken ingredient text
  /// as the search query.
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


  /// Opens the scan screen and adds the scanned ingredients to the selected list.
  ///
  /// Only ingredients that are not already selected are added and saved.
  Future<void> _openScan() async {
    final scannedIngredients = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );

    if (scannedIngredients != null && scannedIngredients is List<IngredientModel>) {
      final userId = _currentUserId;
      if (userId == null) {
        _showAuthRequiredMessage();
        return;
      }

      int addedCount = 0;
      final ingredientsToSave = <IngredientModel>[];

      setState(() {
        for (final ingredient in scannedIngredients) {
          if (!selectedIngredientsMap.containsKey(ingredient.id)) {
            selectedIngredientsMap[ingredient.id] = SelectedIngredientData(
              ingredient: ingredient,
              quantity: 1.0,
              isChecked: true,
            );
            ingredientsToSave.add(ingredient);
            addedCount++;
          }
        }
      });

      for (final ingredient in ingredientsToSave) {
        await _ingredientService.saveUserSelectedIngredient(
          userId: userId,
          ingredient: ingredient,
          quantity: 1.0,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(addedCount > 0
              ? 'Added $addedCount ingredient${addedCount == 1 ? '' : 's'} to your selections!'
              : 'Ingredients already selected'),
          backgroundColor: addedCount > 0 ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }


  /// Shows a popup containing all selected ingredients.
  ///
  /// The popup lets the user review selected items, remove items, change
  /// quantities, clear all selections, or close the dialog.
  void showSelectedIngredientsPopup() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final selectedItems = selectedIngredientsMap.values.where((item) => item.isChecked).toList();

    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No ingredients selected yet'),
          backgroundColor: _orangeDark,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentItems = selectedIngredientsMap.values.where((item) => item.isChecked).toList();
            return Dialog(
              backgroundColor: isDarkMode
                  ? const Color(0xFF1F1F1F)
                  : _cardCream,
              insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Container(
                padding: const EdgeInsets.all(18),
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82, maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Selected Ingredients',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? const Color(0xFFF2F2F2)
                                  : _brown,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: _orangeDark),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color(0xFF2A2A2A)
                            : _orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total selected',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDarkMode
                                  ? const Color(0xFFE3E3E3)
                                  : _brown,
                            ),
                          ),
                          Text('${currentItems.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: _orangeDark)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: currentItems.length,
                        itemBuilder: (context, index) {
                          final item = currentItems[index];
                          final ingredient = item.ingredient;
                          final quantity = _currentDialogQuantity(ingredient.id, item.quantity);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? const Color(0xFF2A2A2A)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDarkMode
                                    ? const Color(0xFF444444)
                                    : _border,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: _buildIngredientImage(ingredient, 52),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ingredient.name,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: isDarkMode
                                                  ? const Color(0xFFF2F2F2)
                                                  : _brown,
                                            ),
                                          ),
                                          Text(
                                            ingredient.category,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDarkMode
                                                  ? const Color(0xFFBEBEBE)
                                                  : _mutedBrown,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () async {
                                        await removeIngredient(ingredient.id);
                                        setDialogState(() {});
                                        if (selectedIngredientsMap.values.where((i) => i.isChecked).isEmpty && context.mounted) {
                                          Navigator.pop(context);
                                        }
                                      },
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      'Quantity:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDarkMode
                                            ? const Color(0xFFBEBEBE)
                                            : _mutedBrown,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: isDarkMode
                                              ? const Color(0xFF4A4A4A)
                                              : _border,
                                        ),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            onPressed: () {
                                              _changeQuantityFromDialog(
                                                ingredientId: ingredient.id,
                                                delta: -0.5,
                                                refreshDialog: () => setDialogState(() {}),
                                              );
                                            },
                                            icon: const Icon(Icons.remove, size: 16),
                                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                            padding: EdgeInsets.zero,
                                          ),
                                          SizedBox(
                                            width: 46,
                                            child: Text(
                                              quantity.toStringAsFixed(1),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () {
                                              _changeQuantityFromDialog(
                                                ingredientId: ingredient.id,
                                                delta: 0.5,
                                                refreshDialog: () => setDialogState(() {}),
                                              );
                                            },
                                            icon: const Icon(Icons.add, size: 16),
                                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ],
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
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              await clearSelections();
                              if (context.mounted) Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _orangeDark,
                              side: const BorderSide(color: _orangeDark),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                            child: const Text('Clear All'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _orangeDark,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                            child: const Text('Done', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  /// Builds the ingredient image widget with a loading placeholder and fallback icon.
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


  /// Reads the user's first name from the Firestore `users` collection.
  ///
  /// Returns null if the name is missing or if the request fails.
  Future<String?> _getFirestoreFirstName(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final firstName = (doc.data()?['firstName'] as String?)?.trim();
      if (firstName != null && firstName.isNotEmpty) return firstName;
    } catch (_) {}
    return null;
  }


  /// Extracts the first word from Firebase Auth display name to use as a fallback.
  String? _extractFirstName(String? displayName) {
    final value = (displayName ?? '').trim();
    if (value.isEmpty) return null;
    return value.split(RegExp(r'\s+')).first;
  }

  @override
  /// Builds the whole filter screen UI.
  ///
  /// The UI changes depending on loading state, authentication state, selected
  /// category, search query, and Firestore ingredient streams.
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final fallbackName = _extractFirstName(currentUser?.displayName) ?? 'Chef';
    final bottomSafePadding = MediaQuery.of(context).padding.bottom + 60.0;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final scaffoldColor = isDarkMode ? const Color(0xFF121212) : _cream;

    // Show a centered loading indicator until categories are loaded.
    if (isLoading) {
      return Scaffold(
        backgroundColor: scaffoldColor,
        body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_orangeDark))),
      );
    }


    // If no user is signed in, show the header but block saving selected ingredients.
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: scaffoldColor,
        body: Column(
          children: [
            _PantryTopHeader(
              displayName: fallbackName,
              selectedCount: 0,
              isDarkMode: isDarkMode,
              searchController: _searchController,
              onSearchChanged: _handleSearchChanged,
              onFilterTap: _openVoiceSearch,
              onSettingsTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
              onProfileTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
              onSelectedTap: showSelectedIngredientsPopup,
            ),
            Expanded(
              child: Center(
                child: Text(
                  'Please sign in to save selected ingredients.',
                  style: TextStyle(
                    color: isDarkMode ? Color(0xFFE3E3E3) : _brown,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }


    // Listen to the user's saved selected ingredients so the UI stays synced
    // with Firestore in real time.
    return StreamBuilder<List<SavedIngredientSelection>>(
      stream: _ingredientService.streamUserSelectedIngredients(currentUser.uid),
      builder: (context, selectedSnapshot) {
        if (selectedSnapshot.hasData) {
          selectedIngredientsMap = {
            for (final selection in selectedSnapshot.data!)
              selection.ingredient.id: SelectedIngredientData(
                ingredient: selection.ingredient,
                quantity: selection.quantity,
                isChecked: true,
              ),
          };
        }

        return Scaffold(
          backgroundColor: scaffoldColor,
          body: Column(
            children: [
              // Load the user's first name from Firestore for the header greeting.
              FutureBuilder<String?>(
                future: _getFirestoreFirstName(currentUser.uid),
                builder: (context, nameSnapshot) {
                  final resolvedName = (nameSnapshot.data != null && nameSnapshot.data!.isNotEmpty) ? nameSnapshot.data! : fallbackName;
                  return _PantryTopHeader(
                    displayName: resolvedName,
                    selectedCount: selectedCount,
                    isDarkMode: isDarkMode,
                    searchController: _searchController,
                    onSearchChanged: _handleSearchChanged,
                    onFilterTap: _openVoiceSearch,
                    onSettingsTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                    onProfileTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
                    onSelectedTap: showSelectedIngredientsPopup,
                  );
                },
              ),
              Expanded(
                // Listen to ingredients based on the currently selected category.
                child: StreamBuilder<List<IngredientModel>>(
                  stream: selectedCategory == 'All' ? _ingredientService.getAllIngredients() : _ingredientService.getIngredientsByCategoryStream(selectedCategory),
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
                              onPressed: _initializeIngredients,
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

                    // Apply the current search query before building the grid.
                    final ingredients = _applySearch(snapshot.data!);
                    final visibleCategories = _visibleCategoryTiles(categories);

                    return CustomScrollView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        // Start view: scan card + categories grid.
                        if (!isCategoryOpened) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                              child: _ScanIngredientCard(
                                onTap: _openScan,
                                isDarkMode: isDarkMode,
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                              child: Text(
                                'Categories',
                                style: TextStyle(
                                  color: isDarkMode
                                      ? const Color(0xFFF2F2F2)
                                      : _brown,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                childAspectRatio: 0.92,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                  final category = visibleCategories[index];
                                  final isMoreTile = category == '__more__';
                                  final isLessTile = category == '__less__';
                                  final isToggleTile = isMoreTile || isLessTile;

                                  return _CategoryTile(
                                    title: isMoreTile ? 'More' : isLessTile ? 'Less' : category,
                                    imagePath: isToggleTile ? '' : _categoryIconPath(category),
                                    icon: isMoreTile
                                        ? Icons.more_horiz_rounded
                                        : isLessTile
                                        ? Icons.expand_less_rounded
                                        : null,
                                    isSelected: false,
                                    onTap: isToggleTile
                                        ? () => setState(() => showAllCategories = !showAllCategories)
                                        : () => setState(() {
                                      selectedCategory = category;
                                      isCategoryOpened = true;
                                      searchQuery = '';
                                      _searchController.clear();
                                    }),
                                    isDarkMode: isDarkMode,
                                  );
                                },
                                childCount: visibleCategories.length,
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(child: SizedBox(height: bottomSafePadding)),
                        ] else ...[
                          // Opened view: back button + ingredient/search results grid.
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
                                        color: isDarkMode
                                            ? const Color(0xFF2A2A2A)
                                            : Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDarkMode
                                              ? const Color(0xFF444444)
                                              : _border,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.arrow_back_rounded,
                                        color: isDarkMode
                                            ? const Color(0xFFF2F2F2)
                                            : _orangeDark,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _openedTitle(ingredients),
                                          style: TextStyle(
                                            color: isDarkMode
                                                ? const Color(0xFFF2F2F2)
                                                : _brown,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          searchQuery.trim().isEmpty
                                              ? '${ingredients.length} ${ingredients.length == 1 ? 'ingredient' : 'ingredients'} available'
                                              : '${ingredients.length} ${ingredients.length == 1 ? 'result' : 'results'} found',
                                          style: TextStyle(
                                            color: isDarkMode
                                                ? const Color(0xFFBEBEBE)
                                                : _mutedBrown,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (selectedCount > 0)
                                    GestureDetector(
                                      onTap: showSelectedIngredientsPopup,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                        decoration: BoxDecoration(color: _orangeDark, borderRadius: BorderRadius.circular(18)),
                                        child: Text(
                                          '$selectedCount selected',
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (ingredients.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.search_off,
                                      size: 54,
                                      color: _orangeDark,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No ingredients found',
                                      style: TextStyle(
                                        color: isDarkMode
                                            ? const Color(0xFFE3E3E3)
                                            : _brown,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(18, 0, 18, bottomSafePadding),
                              sliver: SliverGrid(
                                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 165,
                                  childAspectRatio: 0.75,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                    final ingredient = ingredients[index];
                                    final isSelected = selectedIngredientsMap.containsKey(ingredient.id) && selectedIngredientsMap[ingredient.id]!.isChecked;
                                    return _IngredientCard(
                                      ingredient: ingredient,
                                      isSelected: isSelected,
                                      onTap: () => toggleIngredient(ingredient),
                                      isDarkMode: isDarkMode,
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
        );
      },
    );
  }
}
/// Local model used by this screen to store selected ingredient information.
///
/// It wraps the original ingredient with its selected quantity and checked state.
class SelectedIngredientData {
  final IngredientModel ingredient;
  final double quantity;
  final bool isChecked;

  SelectedIngredientData({required this.ingredient, required this.quantity, required this.isChecked});
}

/// Orange top header used in the pantry/filter screen.
///
/// It displays the profile avatar, user name, selected item button, settings
/// button, screen title, search field, and voice search button.
class _PantryTopHeader extends StatelessWidget {
  const _PantryTopHeader({
    required this.displayName,
    required this.selectedCount,
    required this.isDarkMode,
    required this.searchController,
    required this.onSearchChanged,
    required this.onFilterTap,
    required this.onSettingsTap,
    required this.onProfileTap,
    required this.onSelectedTap,
  });

  final String displayName;
  final int selectedCount;
  final bool isDarkMode;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onProfileTap;
  final VoidCallback onSelectedTap;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    // Make the header shorter in landscape mode so it fits smaller laptop screens.
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final isCompact = isLandscape;
    final heroTitleSize = isCompact ? 16.0 : 23.0;
    final heroGradient = isDarkMode
        ? const [Color(0xFF1A1A1A), Color(0xFF2D2D2D), Color(0xFF3D3D3D)]
        : const [Color(0xFFCC7705), Color(0xFFDD8E1E), Color(0xFFF0A73A)];
    final avatarBg = isDarkMode ? const Color(0xFF444444) : const Color(0xFFD28E18);
    final headerButtonBg = isDarkMode ? const Color(0xFF444444) : Colors.white;
    final headerButtonIcon = isDarkMode ? Colors.white70 : const Color(0xFF6C6C6C);
    final searchBg = isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;
    final searchIconColor = isDarkMode
        ? const Color(0xFFD0D0D0)
        : const Color(0xFF888888);
    final searchTextColor = isDarkMode
        ? const Color(0xFFE3E3E3)
        : const Color(0xFF2F2F2F);
    final searchHintColor = isDarkMode
        ? const Color(0xFFB0B0B0)
        : const Color(0xFF6A6A6A);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        18,
        topInset + (isCompact ? 4 : 10),
        18,
        isCompact ? 8 : 18,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: heroGradient,
          stops: [0.0, 0.35, 1.0],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
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
                  GestureDetector(
                    onTap: onProfileTap,
                    child: CurrentUserAvatar(
                      size: 40,
                      onTap: onProfileTap,
                      backgroundColor: avatarBg,
                      borderColor: Colors.white.withValues(alpha: 0.65),
                      borderWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 10),
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
                          'Home Chef',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selectedCount > 0) ...[
                    _CircleActionButton(
                      icon: Icons.format_list_bulleted_rounded,
                      onTap: onSelectedTap,
                      badgeCount: selectedCount,
                      backgroundColor: headerButtonBg,
                      iconColor: headerButtonIcon,
                    ),
                    const SizedBox(width: 10),
                  ],
                  _CircleActionButton(
                    icon: Icons.settings_outlined,
                    onTap: onSettingsTap,
                    backgroundColor: headerButtonBg,
                    iconColor: headerButtonIcon,
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 6 : 26),
              Text(
                'Choose your ingredients',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: heroTitleSize,
                  height: 1.12,
                ),
              ),
              if (!isCompact) ...[
                const SizedBox(height: 4),
                Text(
                  'Build your recipe matches',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: heroTitleSize,
                    height: 1.20,
                  ),
                ),
              ],
              SizedBox(height: isCompact ? 8 : 25),
              Container(
                height: isCompact ? 40 : 50,
                padding: const EdgeInsets.only(left: 16, right: 6),
                decoration: BoxDecoration(
                  color: searchBg,
                  borderRadius: BorderRadius.circular(27),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: searchIconColor,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        onChanged: onSearchChanged,
                        cursorColor: searchIconColor,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: searchTextColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search',
                          hintStyle: TextStyle(color: searchHintColor),
                          filled: false,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onFilterTap,
                      icon: Icon(
                        Icons.keyboard_voice_rounded,
                        color: isDarkMode
                            ? const Color(0xFFD0D0D0)
                            : const Color(0xFF4D4D4D),
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
              SizedBox(height: isCompact ? 2 : 10),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small circular icon button used in the header.
///
/// It can optionally display a badge count, used for selected ingredients.
class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
    this.backgroundColor = Colors.white,
    this.iconColor = const Color(0xFF6C6C6C),
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;
  final Color backgroundColor;
  final Color iconColor;

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
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 21),
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

/// Custom painter for the subtle decorative arcs in the orange header.
class _HeroBackgroundPainter extends CustomPainter {
  @override
  /// Draws two translucent white arcs to give the header more visual depth.
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
  /// Returns false because the decorative arcs are static and do not animate.
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
/// Card shown above the categories that opens the ingredient scanning flow.
class _ScanIngredientCard extends StatelessWidget {
  const _ScanIngredientCard({
    required this.onTap,
    required this.isDarkMode,
  });

  final VoidCallback onTap;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode
                ? const [Color(0xFF1F1B16), Color(0xFF2A221B), Color(0xFF3A2E22)]
                : const [Color(0xFF9D6B1E), Color(0xFFD08A16)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1F1F1F) : const Color(0xFFF7F1DE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.document_scanner_outlined,
                size: 48,
                color: isDarkMode ? const Color(0xFFF2F2F2) : const Color(0xFF3A2214),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Scan Ingredient', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text('Point camera at food to add items quickly', style: TextStyle(color: Colors.white, fontSize: 13, height: 1.25)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Reusable category tile used in the categories grid and category filter sheet.
///
/// It can show either an asset image or an icon, depending on the provided data.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.title,
    required this.imagePath,
    this.icon,
    required this.isSelected,
    required this.onTap,
    this.isDarkMode = false,
  });

  final String title;
  final String imagePath;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode ? const Color(0xFF2F2A23) : const Color(0xFFFFF8E9))
              : (isDarkMode ? const Color(0xFF232323) : const Color(0xFFFCF7E8)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFB87313)
                : (isDarkMode ? const Color(0xFF444444) : const Color(0xFFE2C9A4)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFFB87313).withOpacity(0.16), blurRadius: 8, offset: const Offset(0, 3))] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: icon != null
                  ? Icon(
                      icon,
                      color: isDarkMode
                          ? const Color(0xFF9BEA7A)
                          : const Color(0xFF5C8E3E),
                      size: 34,
                    )
                  : Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.eco_rounded,
                  color: isDarkMode
                      ? const Color(0xFF9BEA7A)
                      : const Color(0xFF5C8E3E),
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDarkMode
                    ? const Color(0xFFF2F2F2)
                    : const Color(0xFF3A2214),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable ingredient card shown in the ingredient results grid.
/// It displays the ingredient image, name, category, and selected check mark.
class _IngredientCard extends StatelessWidget {
  const _IngredientCard({
    required this.ingredient,
    required this.isSelected,
    required this.onTap,
    this.isDarkMode = false,
  });

  final IngredientModel ingredient;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final imageSize = screenWidth < 600 ? 86.0 : 96.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode ? const Color(0xFF2F2A23) : const Color(0xFFFFF7E6))
              : (isDarkMode ? const Color(0xFF232323) : const Color(0xFFFCF7E8)),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFB87313)
                : (isDarkMode ? const Color(0xFF444444) : const Color(0xFFE1B58E)),
            width: isSelected ? 2.2 : 1.6,
          ),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
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
                ),
                const SizedBox(height: 8),
                Text(
                  ingredient.name,
                  style: TextStyle(
                    color: isDarkMode
                        ? const Color(0xFFF2F2F2)
                        : const Color(0xFF3A2214),
                    fontSize: screenWidth < 600 ? 13 : 14,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF3A2D20)
                        : const Color(0xFFEFC7A7).withOpacity(0.45),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    ingredient.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDarkMode
                          ? const Color(0xFFFFC08A)
                          : const Color(0xFFCB6B2E),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (isSelected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(color: Color(0xFFB87313), shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 17, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
/// Optional bottom sheet for choosing a category.
///
/// This class is currently unused in the active UI, but it can be used later
/// if the category picker is moved back into a bottom sheet.
class _CategoryFilterSheet extends StatelessWidget {
  const _CategoryFilterSheet({
    required this.categories,
    required this.selectedCategory,
    required this.iconResolver,
    required this.onSelect,
  });

  final List<String> categories;
  final String selectedCategory;
  final String Function(String) iconResolver;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 44, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2C9A4), borderRadius: BorderRadius.circular(8))),
            ),
            const SizedBox(height: 16),
            const Text('Filter by category', style: TextStyle(color: Color(0xFF3A2214), fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: categories.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 0.9, crossAxisSpacing: 10, mainAxisSpacing: 10),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return _CategoryTile(
                    title: category,
                    imagePath: iconResolver(category),
                    isSelected: selectedCategory == category,
                    onTap: () => onSelect(category),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
/// Reference bottom navigation bar design.
///
/// This class is currently unused in the active UI. It appears to be kept as
/// a previous/alternative bottom bar design.
class _ReferenceBottomBar extends StatelessWidget {
  const _ReferenceBottomBar({required this.onCenterTap, required this.selectedCount});

  final VoidCallback onCenterTap;
  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88 + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 18, offset: const Offset(0, -6))],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _BottomItem(icon: Icons.home_rounded, label: 'Home'),
                _BottomItem(icon: Icons.favorite_border_rounded, label: 'Favorite'),
                SizedBox(width: 78),
                _BottomItem(icon: Icons.restaurant_menu_rounded, label: 'Meal'),
                _BottomItem(icon: Icons.shopping_basket_outlined, label: 'Grocery'),
              ],
            ),
          ),
          Positioned(
            top: -34,
            child: GestureDetector(
              onTap: onCenterTap,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFD99622),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [BoxShadow(color: const Color(0xFFD99622).withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 8))],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.add_rounded, color: Colors.white, size: 40),
                    if (selectedCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: Text('$selectedCount', style: const TextStyle(color: Color(0xFFB87313), fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single icon and label item used inside `_ReferenceBottomBar`.
class _BottomItem extends StatelessWidget {
  const _BottomItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF8B8B8B), size: 25),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Color(0xFF8B8B8B), fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
