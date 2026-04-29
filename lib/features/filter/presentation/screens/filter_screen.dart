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

  // Store selected ingredients with their quantities and checked state
  Map<String, SelectedIngredientData> selectedIngredientsMap = {};

  String selectedCategory = 'All';
  List<String> categories = ['All'];
  bool isLoading = true;

  // Helper getters
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

  Future<void> _initializeIngredients() async {
    setState(() => isLoading = true);

    try {
      final loadedCategories = await _ingredientService.getAllCategories();
      setState(() {
        categories = loadedCategories;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint('Error loading ingredients: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading ingredients: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Toggle ingredient selection (check/uncheck)
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

  // Update quantity for an ingredient
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

  // Remove ingredient from selection
  void removeIngredient(String ingredientId) {
    setState(() {
      selectedIngredientsMap.remove(ingredientId);
    });
  }

  void clearSelections() {
    setState(() {
      selectedIngredientsMap.clear();
    });
  }

  // Show shopping list popup with quantity controls
  void showShoppingListPopup() {
    final selectedItems = selectedIngredientsMap.values.where((item) => item.isChecked).toList();

    if (selectedItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No ingredients selected yet'),
            backgroundColor: Color(0xFFCB6B2E),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                  maxWidth: 450,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Ingredients List',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3A2214),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Color(0xFFCB6B2E)),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFFCB6B2E), thickness: 1),
                    const SizedBox(height: 10),

                    // Summary row
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCB6B2E).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Items:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${selectedItems.length}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFCB6B2E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    Expanded(
                      child: ListView.builder(
                        itemCount: selectedItems.length,
                        itemBuilder: (context, index) {
                          final item = selectedItems[index];
                          final ingredient = item.ingredient;
                          final quantity = item.quantity;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: _buildIngredientImage(ingredient, 50),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ingredient.name,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF3A2214),
                                              ),
                                            ),
                                            Text(
                                              ingredient.category,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: const Color(0xFFCB6B2E).withOpacity(0.7),
                                              ),
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
                                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Quantity selector
                                  Row(
                                    children: [
                                      const Text(
                                        'Quantity:',
                                        style: TextStyle(fontSize: 12, color: Color(0xFF8B7355)),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(color: const Color(0xFFCB6B2E).withOpacity(0.3)),
                                          borderRadius: BorderRadius.circular(8),
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
                                              width: 50,
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
                                      const Spacer(),
                                    ],
                                  ),
                                  if (ingredient.unit != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '~ ${(quantity / _getUnitValue(ingredient.unit!)).toStringAsFixed(2)} ${ingredient.unit}',
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF8B7355)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              clearSelections();
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFCB6B2E),
                              side: const BorderSide(color: Color(0xFFCB6B2E)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: const Text('Clear All'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFCB6B2E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: const Text('Close', style: TextStyle(color: Colors.white)),
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

  double _getUnitValue(String unit) {
    switch (unit) {
      case 'kg': return 1.0;
      case 'gram': return 0.001;
      case '100g': return 0.1;
      case '500g': return 0.5;
      case 'liter': return 1.0;
      case 'bunch': return 0.2;
      case 'head': return 0.5;
      case 'dozen': return 12.0;
      case 'loaf': return 0.5;
      case 'each': return 1.0;
      default: return 1.0;
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
          width: size * 0.4,
          height: size * 0.4,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCB6B2E)),
          ),
        ),
      ),
      errorWidget: Icon(
        Icons.restaurant,
        size: size * 0.6,
        color: const Color(0xFFCB6B2E).withOpacity(0.7),
      ),
    );
  }

  Future<String?> _getFirestoreFirstName(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data();
      final firstName = (data?['firstName'] as String?)?.trim();
      if (firstName != null && firstName.isNotEmpty) return firstName;
      return null;
    } catch (_) {
      return null;
    }
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

    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3E8DF),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCB6B2E)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3E8DF),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return StreamBuilder<List<IngredientModel>>(
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
                        onPressed: _initializeIngredients,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCB6B2E),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCB6B2E)),
                  ),
                );
              }

              final ingredients = snapshot.data!;

              if (ingredients.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox, size: 64, color: Color(0xFFCB6B2E)),
                      const SizedBox(height: 16),
                      const Text(
                        'No ingredients found',
                        style: TextStyle(color: Color(0xFF3A2214), fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _IngredientsTopHero(
                      displayName: fallbackName,
                      selectedCount: selectedCount,
                      onProfileTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        );
                      },
                      onSettingsTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      },
                      onScanTap: () async {
                        final scannedIngredients = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ScanScreen()),
                        );

                        if (scannedIngredients != null && scannedIngredients is List<IngredientModel>) {
                          // Auto-select the matched ingredients (these are already matched from the database)
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

                          // Show success message
                          if (addedCount > 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added $addedCount ingredient${addedCount == 1 ? '' : 's'} to your list!'),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Ingredients already in your list'),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                      onViewSelections: showShoppingListPopup,
                    ),
                  ),
                  if (categories.isNotEmpty)
                    SliverToBoxAdapter(
                      child: ClipRect(
                        child: Container(
                          height: 50,
                          margin: const EdgeInsets.only(top: 12, bottom: 8),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final category = categories[index];
                              final isSelected = selectedCategory == category;
                              final categoryCount = category == 'All'
                                  ? ingredients.length
                                  : ingredients.where((i) => i.category == category).length;

                              return Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => setState(() => selectedCategory = category),
                                    borderRadius: BorderRadius.circular(25),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFFCB6B2E) : Colors.white,
                                        borderRadius: BorderRadius.circular(25),
                                        border: Border.all(
                                          color: isSelected ? const Color(0xFFCB6B2E) : const Color(0xFFCB6B2E).withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            category,
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : const Color(0xFF3A2214),
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                              fontSize: 13,
                                              height: 1.2,
                                            ),
                                          ),
                                          if (category != 'All') ...[
                                            const SizedBox(width: 4),
                                            Text(
                                              '($categoryCount)',
                                              style: TextStyle(
                                                color: isSelected ? Colors.white70 : const Color(0xFF8B7355),
                                                fontSize: 11,
                                                height: 1.2,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${ingredients.length} ${ingredients.length == 1 ? 'ingredient' : 'ingredients'}',
                            style: const TextStyle(
                              color: Color(0xFF8B7355),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (selectedCount > 0)
                            GestureDetector(
                              onTap: clearSelections,
                              child: const Text(
                                'Clear All',
                                style: TextStyle(
                                  color: Color(0xFFCB6B2E),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 160,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final ingredient = ingredients[index];
                          final isSelected = selectedIngredientsMap.containsKey(ingredient.id) &&
                              selectedIngredientsMap[ingredient.id]!.isChecked;
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
              );
            },
          );
        },
      ),
    );
  }
}

// Data class for selected ingredients
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

// TOP HERO SECTION
class _IngredientsTopHero extends StatelessWidget {
  const _IngredientsTopHero({
    required this.displayName,
    required this.selectedCount,
    required this.onProfileTap,
    required this.onSettingsTap,
    required this.onScanTap,
    required this.onViewSelections,
  });

  final String displayName;
  final int selectedCount;
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onScanTap;
  final VoidCallback onViewSelections;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18, topInset + 6, 18, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFCC7705), Color(0xFFDD8E1E), Color(0xFFF0A73A)],
          stops: [0.0, 0.35, 1.0],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onProfileTap,
                child: const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFFD28E18),
                  child: Icon(Icons.person, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Build your shopping list',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              if (selectedCount > 0)
                GestureDetector(
                  onTap: onViewSelections,
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shopping_cart, size: 16, color: Color(0xFFCB6B2E)),
                        const SizedBox(width: 4),
                        Text(
                          '$selectedCount',
                          style: const TextStyle(
                            color: Color(0xFFCB6B2E),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              _CircleActionButton(
                icon: Icons.settings_outlined,
                onTap: onSettingsTap,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Shopping List',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Tap ingredients to add to your list',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 44,
            padding: const EdgeInsets.only(left: 14, right: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: Color(0xFF888888), size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Search ingredients...',
                    style: TextStyle(color: Color(0xFF999999), fontSize: 13),
                  ),
                ),
                IconButton(
                  onPressed: onScanTap,
                  icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF4D4D4D), size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        width: 32,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF6C6C6C), size: 18),
      ),
    );
  }
}

class _IngredientCard extends StatelessWidget {
  const _IngredientCard({
    required this.ingredient,
    required this.isSelected,
    required this.onTap,
  });

  final IngredientModel ingredient;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final imageSize = screenWidth < 600 ? 80.0 : 90.0;
    final fontSize = screenWidth < 600 ? 11.0 : 12.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFCB6B2E).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFCB6B2E)
                : const Color(0xFFCB6B2E).withOpacity(0.5),
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: imageSize,
                  height: imageSize,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CustomCachedImage(
                      imageUrl: ingredient.imageUrl,
                      width: imageSize,
                      height: imageSize,
                      fit: BoxFit.contain,
                      placeholder: Center(
                        child: SizedBox(
                          width: imageSize * 0.4,
                          height: imageSize * 0.4,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCB6B2E)),
                          ),
                        ),
                      ),
                      errorWidget: Icon(
                        Icons.restaurant,
                        size: imageSize * 0.5,
                        color: const Color(0xFFCB6B2E).withOpacity(0.7),
                      ),
                    ),
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFCB6B2E),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                ingredient.name,
                style: TextStyle(
                  color: const Color(0xFF3A2214),
                  fontSize: fontSize,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFCB6B2E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                ingredient.category,
                style: TextStyle(
                  color: const Color(0xFFCB6B2E),
                  fontSize: screenWidth < 600 ? 8 : 9,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}