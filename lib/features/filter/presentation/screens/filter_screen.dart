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
import 'scan.dart' hide IngredientModel;

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  final IngredientService _ingredientService = IngredientService();
  final TextEditingController _searchController = TextEditingController();

  Map<String, SelectedIngredientData> selectedIngredientsMap = {};

  String selectedCategory = 'All';
  List<String> categories = ['All'];
  bool isLoading = true;
  String searchQuery = '';
  bool showAllCategories = false;
  bool isCategoryOpened = false;

  static const Color _orangeDark = Color(0xFFB87313);
  static const Color _orange = Color(0xFFD99622);
  static const Color _orangeLight = Color(0xFFF2B13E);
  static const Color _cream = Color(0xFFF7F1DE);
  static const Color _cardCream = Color(0xFFFCF7E8);
  static const Color _brown = Color(0xFF3A2214);
  static const Color _mutedBrown = Color(0xFF8B7355);
  static const Color _border = Color(0xFFE2C9A4);
  static const Color _green = Color(0xFF5C8E3E);

  int get selectedCount => selectedIngredientsMap.values.where((item) => item.isChecked).length;

  List<IngredientModel> getSelectedIngredients() {
    return selectedIngredientsMap.values
        .where((item) => item.isChecked)
        .map((item) => item.ingredient)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _initializeIngredients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      debugPrint('Error loading ingredients: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading ingredients: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void toggleIngredient(IngredientModel ingredient) {
    setState(() {
      if (selectedIngredientsMap.containsKey(ingredient.id)) {
        final current = selectedIngredientsMap[ingredient.id]!;
        selectedIngredientsMap[ingredient.id] = SelectedIngredientData(
          ingredient: ingredient,
          quantity: current.quantity,
          isChecked: !current.isChecked,
        );
      } else {
        selectedIngredientsMap[ingredient.id] = SelectedIngredientData(
          ingredient: ingredient,
          quantity: 1.0,
          isChecked: true,
        );
      }
    });
  }

  void updateQuantity(String ingredientId, double newQuantity) {
    setState(() {
      if (selectedIngredientsMap.containsKey(ingredientId)) {
        final current = selectedIngredientsMap[ingredientId]!;
        selectedIngredientsMap[ingredientId] = SelectedIngredientData(
          ingredient: current.ingredient,
          quantity: newQuantity.clamp(0.1, 100.0),
          isChecked: current.isChecked,
        );
      }
    });
  }

  void removeIngredient(String ingredientId) {
    setState(() => selectedIngredientsMap.remove(ingredientId));
  }

  void clearSelections() {
    setState(() => selectedIngredientsMap.clear());
  }


  List<String> _visibleCategoryTiles(List<String> allCategories) {
    final cleaned = allCategories.where((category) => category.trim().isNotEmpty).toList();
    if (cleaned.length <= 12) return cleaned;

    if (showAllCategories) {
      return [...cleaned, '__less__'];
    }

    final firstEleven = cleaned.take(11).toList();
    return [...firstEleven, '__more__'];
  }

  List<IngredientModel> _applySearch(List<IngredientModel> ingredients) {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return ingredients;

    return ingredients.where((ingredient) {
      final ingredientName = ingredient.name.toLowerCase();
      final ingredientCategory = ingredient.category.toLowerCase();

      // When a category is already opened, search only inside that category by ingredient name.
      if (selectedCategory != 'All') {
        return ingredientName.contains(query);
      }

      // When no specific category is selected, search globally and allow category matching too.
      return ingredientName.contains(query) || ingredientCategory.contains(query);
    }).toList();
  }

  String _openedTitle(List<IngredientModel> filteredIngredients) {
    if (selectedCategory != 'All') return selectedCategory;

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

  Future<void> _openScan() async {
    final scannedIngredients = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );

    if (scannedIngredients != null && scannedIngredients is List<IngredientModel>) {
      int addedCount = 0;
      setState(() {
        for (final ingredient in scannedIngredients) {
          if (!selectedIngredientsMap.containsKey(ingredient.id)) {
            selectedIngredientsMap[ingredient.id] = SelectedIngredientData(
              ingredient: ingredient,
              quantity: 1.0,
              isChecked: true,
            );
            addedCount++;
          }
        }
      });

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

  void showSelectedIngredientsPopup() {
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
              backgroundColor: _cardCream,
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
                        const Expanded(
                          child: Text(
                            'Selected Ingredients',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _brown),
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
                        color: _orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total selected', style: TextStyle(fontWeight: FontWeight.w700, color: _brown)),
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
                          final quantity = item.quantity;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _border),
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
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _brown),
                                          ),
                                          Text(
                                            ingredient.category,
                                            style: const TextStyle(fontSize: 12, color: _mutedBrown),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        removeIngredient(ingredient.id);
                                        setDialogState(() {});
                                        if (selectedIngredientsMap.values.where((i) => i.isChecked).isEmpty) {
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
                                    const Text('Quantity:', style: TextStyle(fontSize: 12, color: _mutedBrown)),
                                    const SizedBox(width: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: _border),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            onPressed: () {
                                              updateQuantity(ingredient.id, quantity - 0.5);
                                              setDialogState(() {});
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
                                              updateQuantity(ingredient.id, quantity + 0.5);
                                              setDialogState(() {});
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
                            onPressed: () {
                              clearSelections();
                              Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final fallbackName = _extractFirstName(currentUser?.displayName) ?? 'Chef';
    final bottomSafePadding = MediaQuery.of(context).padding.bottom + 60.0;

    if (isLoading) {
      return const Scaffold(
        backgroundColor: _cream,
        body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_orangeDark))),
      );
    }

    return Scaffold(
      backgroundColor: _cream,
      body: Column(
        children: [
          FutureBuilder<String?>(
            future: currentUser == null ? Future<String?>.value(null) : _getFirestoreFirstName(currentUser.uid),
            builder: (context, nameSnapshot) {
              final resolvedName = (nameSnapshot.data != null && nameSnapshot.data!.isNotEmpty) ? nameSnapshot.data! : fallbackName;
              return _PantryTopHeader(
                displayName: resolvedName,
                selectedCount: selectedCount,
                searchController: _searchController,
                onSearchChanged: _handleSearchChanged,
                onFilterTap: () {},
                onSettingsTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                onProfileTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
                onSelectedTap: showSelectedIngredientsPopup,
              );
            },
          ),
          Expanded(
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

                final ingredients = _applySearch(snapshot.data!);
                final visibleCategories = _visibleCategoryTiles(categories);

                return CustomScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    if (!isCategoryOpened) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                          child: _ScanIngredientCard(onTap: _openScan),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(18, 0, 18, 6),
                          child: Text(
                            'Categories',
                            style: TextStyle(color: _brown, fontSize: 18, fontWeight: FontWeight.w700),
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
                              );
                            },
                            childCount: visibleCategories.length,
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
                                          ? '${ingredients.length} ${ingredients.length == 1 ? 'ingredient' : 'ingredients'} available'
                                          : '${ingredients.length} ${ingredients.length == 1 ? 'result' : 'results'} found',
                                      style: const TextStyle(color: _mutedBrown, fontSize: 13, fontWeight: FontWeight.w600),
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
  }
}
class SelectedIngredientData {
  final IngredientModel ingredient;
  final double quantity;
  final bool isChecked;

  SelectedIngredientData({required this.ingredient, required this.quantity, required this.isChecked});
}

class _PantryTopHeader extends StatelessWidget {
  const _PantryTopHeader({
    required this.displayName,
    required this.selectedCount,
    required this.searchController,
    required this.onSearchChanged,
    required this.onFilterTap,
    required this.onSettingsTap,
    required this.onProfileTap,
    required this.onSelectedTap,
  });

  final String displayName;
  final int selectedCount;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onProfileTap;
  final VoidCallback onSelectedTap;

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
                  GestureDetector(
                    onTap: onProfileTap,
                    child: const CircleAvatar(
                      radius: 20,
                      backgroundColor: Color(0xFFD28E18),
                      child: Icon(Icons.person, color: Colors.white, size: 22),
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
                    ),
                    const SizedBox(width: 10),
                  ],
                  _CircleActionButton(
                    icon: Icons.settings_outlined,
                    onTap: onSettingsTap,
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Text(
                'Choose your ingredients',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 23,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Build your recipe matches',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 23,
                  height: 1.20,
                ),
              ),
              const SizedBox(height: 30),
              Container(
                height: 50,
                padding: const EdgeInsets.only(left: 18, right: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
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
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF2F2F2F),
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Search',
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
                      onPressed: onFilterTap,
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
class _ScanIngredientCard extends StatelessWidget {
  const _ScanIngredientCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF9D6B1E), Color(0xFFD08A16)], begin: Alignment.centerLeft, end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(color: const Color(0xFFF7F1DE), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.document_scanner_outlined, size: 48, color: Color(0xFF3A2214)),
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

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.title, required this.imagePath, this.icon, required this.isSelected, required this.onTap});

  final String title;
  final String imagePath;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF8E9) : const Color(0xFFFCF7E8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? const Color(0xFFB87313) : const Color(0xFFE2C9A4), width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFFB87313).withOpacity(0.16), blurRadius: 8, offset: const Offset(0, 3))] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: icon != null
                  ? Icon(icon, color: const Color(0xFF5C8E3E), size: 34)
                  : Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.eco_rounded, color: Color(0xFF5C8E3E), size: 30),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF3A2214), fontSize: 12, fontWeight: FontWeight.w700, height: 1.05),
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientCard extends StatelessWidget {
  const _IngredientCard({required this.ingredient, required this.isSelected, required this.onTap});

  final IngredientModel ingredient;
  final bool isSelected;
  final VoidCallback onTap;

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
          color: isSelected ? const Color(0xFFFFF7E6) : const Color(0xFFFCF7E8),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: isSelected ? const Color(0xFFB87313) : const Color(0xFFE1B58E), width: isSelected ? 2.2 : 1.6),
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
                    color: const Color(0xFF3A2214),
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
                  decoration: BoxDecoration(color: const Color(0xFFEFC7A7).withOpacity(0.45), borderRadius: BorderRadius.circular(14)),
                  child: Text(
                    ingredient.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFCB6B2E), fontSize: 11, fontWeight: FontWeight.w700),
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
