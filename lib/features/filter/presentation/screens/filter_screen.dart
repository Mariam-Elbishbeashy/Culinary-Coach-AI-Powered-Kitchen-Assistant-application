import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:culinary_coach_app/features/settings/presentation/screens/settings_screen.dart';
import 'scan.dart';

class IngredientModel {
  final String name;
  final String imageUrl;
  final String category;

  const IngredientModel({
    required this.name,
    required this.imageUrl,
    required this.category,
  });
}

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  List<IngredientModel> allIngredients = [];
  bool isLoading = true;
  Set<String> selectedIngredients = {}; // Track selected ingredients

  // Categories with correct types
  final List<String> categories = [
    'All', 'Vegetables', 'Fruits', 'Meat', 'Seafood',
    'Dairy', 'Grains', 'Legumes', 'Spices & Condiments', 'Herbs'
  ];

  String selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    fetchIngredients();
  }

  Future<void> fetchIngredients() async {
    setState(() => isLoading = true);

    try {
      final Map<String, IngredientModel> uniqueIngredients = {};

      // Fetch from TheMealDB
      await fetchFromMealDB(uniqueIngredients);

      // Fetch from CocktailDB for more ingredients
      await fetchFromCocktailDB(uniqueIngredients);

      // Add Egyptian raw ingredients
      addEgyptianIngredients(uniqueIngredients);

      final ingredientsList = uniqueIngredients.values.toList();
      ingredientsList.sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        allIngredients = ingredientsList;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint('Error fetching ingredients: $e');
    }
  }

  Future<void> fetchFromMealDB(Map<String, IngredientModel> uniqueIngredients) async {
    try {
      final response = await http.get(
        Uri.parse('https://www.themealdb.com/api/json/v1/1/list.php?i=list'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rawList = data['meals'] ?? [];

        for (var item in rawList) {
          final rawName = (item['strIngredient'] ?? '').toString().trim();
          if (rawName.isEmpty) continue;

          final key = rawName.toLowerCase();
          if (!uniqueIngredients.containsKey(key)) {
            uniqueIngredients[key] = IngredientModel(
              name: rawName,
              imageUrl: "https://www.themealdb.com/images/ingredients/$rawName.png",
              category: categorizeIngredient(rawName),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('MealDB error: $e');
    }
  }

  Future<void> fetchFromCocktailDB(Map<String, IngredientModel> uniqueIngredients) async {
    try {
      final response = await http.get(
        Uri.parse('https://www.thecocktaildb.com/api/json/v1/1/list.php?i=list'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rawList = data['drinks'] ?? [];

        for (var item in rawList) {
          final rawName = (item['strIngredient1'] ?? '').toString().trim();
          if (rawName.isEmpty) continue;

          final key = rawName.toLowerCase();
          if (!uniqueIngredients.containsKey(key)) {
            uniqueIngredients[key] = IngredientModel(
              name: rawName,
              imageUrl: "https://www.thecocktaildb.com/images/ingredients/$rawName.png",
              category: categorizeIngredient(rawName),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('CocktailDB error: $e');
    }
  }

  void addEgyptianIngredients(Map<String, IngredientModel> uniqueIngredients) {
    final egyptianIngredients = [
      // Vegetables
      'Molokhia', 'Eggplant', 'Okra', 'Zucchini', 'Cucumber', 'Tomato',
      'Onion', 'Garlic', 'Potato', 'Carrot', 'Bell Pepper', 'Cabbage',
      'Cauliflower', 'Spinach', 'Lettuce', 'Celery', 'Parsley', 'Radish',
      'Turnip', 'Beetroot', 'Leek', 'Pumpkin', 'Squash', 'Artichoke',
      'Green Beans', 'Peas', 'Sweet Potato', 'Taro Root',

      // Fruits
      'Mango', 'Orange', 'Guava', 'Pomegranate', 'Fig', 'Date',
      'Banana', 'Apple', 'Grape', 'Strawberry', 'Watermelon', 'Cantaloupe',
      'Apricot', 'Peach', 'Plum', 'Pear', 'Lemon', 'Lime', 'Grapefruit',

      // Meat
      'Chicken', 'Duck', 'Pigeon', 'Quail', 'Lamb', 'Beef', 'Rabbit',
      'Goat Meat', 'Camel Meat', 'Liver', 'Kidney', 'Heart', 'Bone Marrow',

      // Seafood
      'Nile Tilapia', 'Nile Perch', 'Sea Bass', 'Sea Bream', 'Mullet',
      'Sardines', 'Mackerel', 'Shrimp', 'Calamari', 'Squid', 'Octopus',
      'Crab', 'Mussels', 'Clams', 'Oysters',

      // Dairy
      'Milk', 'Yogurt', 'Cream', 'Butter', 'Ghee', 'Cheese', 'Feta Cheese',
      'Ricotta Cheese', 'Goat Cheese', 'Labneh',

      // Grains
      'Rice', 'Wheat', 'Bulgur Wheat', 'Couscous', 'Freekeh', 'Barley',
      'Oats', 'Corn', 'Semolina', 'Vermicelli',

      // Legumes
      'Lentils', 'Chickpeas', 'Fava Beans', 'Lupin Beans', 'White Beans',
      'Kidney Beans', 'Black Eyed Peas', 'Split Peas',

      // Spices & Condiments
      'Cumin', 'Coriander', 'Cinnamon', 'Clove', 'Cardamom', 'Nutmeg',
      'Turmeric', 'Saffron', 'Black Pepper', 'White Pepper', 'Ginger',
      'Fenugreek', 'Anise', 'Caraway', 'Nigella Seeds', 'Sesame Seeds',
      'Sumac', 'Paprika', 'Chili Powder', 'Curry Powder', 'Dried Mint',
      'Olive Oil', 'Vegetable Oil', 'Corn Oil', 'Sunflower Oil',
      'Sesame Oil', 'Coconut Oil', 'Vinegar', 'Apple Cider Vinegar',
      'Honey', 'Date Syrup', 'Pomegranate Molasses', 'Tahini', 'Salt',

      // Herbs (Fresh)
      'Fresh Mint', 'Fresh Basil', 'Fresh Thyme', 'Fresh Rosemary',
      'Fresh Dill', 'Fresh Cilantro', 'Fresh Oregano', 'Bay Leaves',
      'Fresh Sage', 'Fresh Marjoram', 'Fresh Tarragon', 'Fresh Lemongrass'
    ];

    for (var name in egyptianIngredients) {
      final key = name.toLowerCase();
      if (!uniqueIngredients.containsKey(key)) {
        uniqueIngredients[key] = IngredientModel(
          name: name,
          imageUrl: "https://www.themealdb.com/images/ingredients/$name.png",
          category: categorizeIngredient(name),
        );
      }
    }
  }

  String categorizeIngredient(String name) {
    final n = name.toLowerCase();

    // VEGETABLES
    if (n == 'molokhia' || n == 'eggplant' || n == 'okra' || n == 'zucchini' ||
        n == 'cucumber' || n == 'tomato' || n == 'onion' || n == 'garlic' ||
        n == 'potato' || n == 'carrot' || n == 'bell pepper' || n == 'cabbage' ||
        n == 'cauliflower' || n == 'spinach' || n == 'lettuce' || n == 'celery' ||
        n == 'radish' || n == 'turnip' || n == 'beetroot' || n == 'leek' ||
        n == 'pumpkin' || n == 'squash' || n == 'artichoke' || n == 'green beans' ||
        n == 'peas' || n == 'sweet potato' || n == 'taro root' || n.contains('sweet potato'))
      return 'Vegetables';

    // FRUITS
    if (n == 'mango' || n == 'orange' || n == 'guava' || n == 'pomegranate' ||
        n == 'fig' || n == 'date' || n == 'banana' || n == 'apple' ||
        n == 'grape' || n == 'strawberry' || n == 'watermelon' || n == 'cantaloupe' ||
        n == 'apricot' || n == 'peach' || n == 'plum' || n == 'pear' ||
        n == 'lemon' || n == 'lime' || n == 'grapefruit')
      return 'Fruits';

    // MEAT
    if (n.contains('chicken') || n.contains('duck') || n.contains('pigeon') ||
        n.contains('quail') || n.contains('lamb') || n.contains('beef') ||
        n.contains('rabbit') || n.contains('goat meat') || n.contains('camel meat') ||
        n.contains('liver') || n.contains('kidney') || n.contains('heart') ||
        n.contains('bone marrow'))
      return 'Meat';

    // SEAFOOD
    if (n.contains('tilapia') || n.contains('perch') || n.contains('sea bass') ||
        n.contains('sea bream') || n.contains('mullet') || n.contains('sardines') ||
        n.contains('mackerel') || n.contains('shrimp') || n.contains('calamari') ||
        n.contains('squid') || n.contains('octopus') || n.contains('crab') ||
        n.contains('mussels') || n.contains('clams') || n.contains('oysters'))
      return 'Seafood';

    // DAIRY
    if (n.contains('milk') || n.contains('yogurt') || n.contains('cream') ||
        n.contains('butter') || n.contains('ghee') || n.contains('cheese') ||
        n.contains('feta') || n.contains('ricotta') || n.contains('goat cheese') ||
        n.contains('labneh'))
      return 'Dairy';

    // GRAINS
    if (n.contains('rice') || n.contains('wheat') || n.contains('bulgur') ||
        n.contains('couscous') || n.contains('freekeh') || n.contains('barley') ||
        n.contains('oats') || n.contains('corn') || n.contains('semolina') ||
        n.contains('vermicelli'))
      return 'Grains';

    // LEGUMES
    if (n.contains('lentils') || n.contains('chickpeas') || n.contains('fava beans') ||
        n.contains('lupin beans') || n.contains('white beans') || n.contains('kidney beans') ||
        n.contains('black eyed peas') || n.contains('split peas'))
      return 'Legumes';

    // SPICES & CONDIMENTS
    if (n == 'cumin' || n == 'coriander' || n == 'cinnamon' || n == 'clove' ||
        n == 'cardamom' || n == 'nutmeg' || n == 'turmeric' || n == 'saffron' ||
        n == 'black pepper' || n == 'white pepper' || n == 'ginger' ||
        n == 'fenugreek' || n == 'anise' || n == 'caraway' || n == 'nigella seeds' ||
        n == 'sesame seeds' || n == 'sumac' || n == 'paprika' || n == 'chili powder' ||
        n == 'curry powder' || n == 'dried mint' || n.contains('oil') ||
        n == 'vinegar' || n == 'apple cider vinegar' || n == 'honey' ||
        n == 'date syrup' || n == 'pomegranate molasses' || n == 'tahini' ||
        n == 'salt')
      return 'Spices & Condiments';

    // HERBS
    if (n == 'fresh mint' || n == 'fresh basil' || n == 'fresh thyme' ||
        n == 'fresh rosemary' || n == 'fresh dill' || n == 'fresh cilantro' ||
        n == 'fresh oregano' || n == 'bay leaves' || n == 'fresh sage' ||
        n == 'fresh marjoram' || n == 'fresh tarragon' || n == 'fresh lemongrass' ||
        n.contains('parsley'))
      return 'Herbs';

    return 'Vegetables';
  }

  List<IngredientModel> get filteredIngredients {
    if (selectedCategory == 'All') {
      return allIngredients;
    }
    return allIngredients.where((ingredient) {
      return ingredient.category == selectedCategory;
    }).toList();
  }

  void toggleIngredient(IngredientModel ingredient) {
    setState(() {
      if (selectedIngredients.contains(ingredient.name)) {
        selectedIngredients.remove(ingredient.name);
      } else {
        selectedIngredients.add(ingredient.name);
      }
    });
  }

  void clearSelections() {
    setState(() {
      selectedIngredients.clear();
    });
  }

  void showSelectedIngredientsPopup() {
    if (selectedIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No ingredients selected yet'),
          backgroundColor: Color(0xFFCB6B2E),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Selected Ingredients',
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
                Expanded(
                  child: ListView.builder(
                    itemCount: selectedIngredients.length,
                    itemBuilder: (context, index) {
                      final ingredientName = selectedIngredients.toList()[index];
                      final ingredient = allIngredients.firstWhere(
                            (i) => i.name == ingredientName,
                        orElse: () => IngredientModel(
                          name: ingredientName,
                          imageUrl: '',
                          category: 'Unknown',
                        ),
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E8DF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  ingredient.imageUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.restaurant,
                                      size: 25,
                                      color: const Color(0xFFCB6B2E).withOpacity(0.7),
                                    );
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
                                    ingredient.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF3A2214),
                                    ),
                                  ),
                                  Text(
                                    ingredient.category,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: const Color(0xFFCB6B2E).withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  selectedIngredients.remove(ingredientName);
                                });
                                Navigator.pop(context);
                                showSelectedIngredientsPopup(); // Refresh popup
                              },
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Color(0xFFCB6B2E), size: 20),
                            ),
                          ],
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

    final content = _FilterContent(
      displayName: fallbackName,
      allIngredients: allIngredients,
      filteredIngredients: filteredIngredients,
      isLoading: isLoading,
      categories: categories,
      selectedCategory: selectedCategory,
      selectedIngredients: selectedIngredients,
      onCategorySelected: (category) => setState(() => selectedCategory = category),
      onToggleIngredient: toggleIngredient,
      onClearSelections: clearSelections,
      onShowSelections: showSelectedIngredientsPopup,
    );

    if (currentUser == null) return content;

    return FutureBuilder<String?>(
      future: _getFirestoreFirstName(currentUser.uid),
      builder: (context, snapshot) {
        final resolvedName = (snapshot.data != null && snapshot.data!.isNotEmpty)
            ? snapshot.data!
            : fallbackName;
        return _FilterContent(
          displayName: resolvedName,
          allIngredients: allIngredients,
          filteredIngredients: filteredIngredients,
          isLoading: isLoading,
          categories: categories,
          selectedCategory: selectedCategory,
          selectedIngredients: selectedIngredients,
          onCategorySelected: (category) => setState(() => selectedCategory = category),
          onToggleIngredient: toggleIngredient,
          onClearSelections: clearSelections,
          onShowSelections: showSelectedIngredientsPopup,
        );
      },
    );
  }
}

class _FilterContent extends StatelessWidget {
  const _FilterContent({
    required this.displayName,
    required this.allIngredients,
    required this.filteredIngredients,
    required this.isLoading,
    required this.categories,
    required this.selectedCategory,
    required this.selectedIngredients,
    required this.onCategorySelected,
    required this.onToggleIngredient,
    required this.onClearSelections,
    required this.onShowSelections,
  });

  final String displayName;
  final List<IngredientModel> allIngredients;
  final List<IngredientModel> filteredIngredients;
  final bool isLoading;
  final List<String> categories;
  final String selectedCategory;
  final Set<String> selectedIngredients;
  final Function(String) onCategorySelected;
  final Function(IngredientModel) onToggleIngredient;
  final VoidCallback onClearSelections;
  final VoidCallback onShowSelections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3E8DF),
      body: CustomScrollView(
        slivers: [
          // Top Hero Bar - Scrollable
          SliverToBoxAdapter(
            child: _IngredientsTopHero(
              displayName: displayName,
              selectedCount: selectedIngredients.length,
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
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanScreen()),
                );
                if (result != null && result is List<String>) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Scan feature ready!'),
                      backgroundColor: Color(0xFFCB6B2E),
                    ),
                  );
                }
              },
              onViewSelections: onShowSelections,
            ),
          ),

          // Category Pills
          if (!isLoading && categories.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                height: 42,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = selectedCategory == category;
                    final categoryCount = category == 'All'
                        ? allIngredients.length
                        : allIngredients.where((i) => i.category == category).length;

                    return GestureDetector(
                      onTap: () => onCategorySelected(category),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                              ),
                            ),
                            if (category != 'All') ...[
                              const SizedBox(width: 4),
                              Text(
                                '($categoryCount)',
                                style: TextStyle(
                                  color: isSelected ? Colors.white70 : const Color(0xFF8B7355),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Results count
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${filteredIngredients.length} ${filteredIngredients.length == 1 ? 'ingredient' : 'ingredients'}',
                    style: const TextStyle(
                      color: Color(0xFF8B7355),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (selectedIngredients.isNotEmpty)
                    GestureDetector(
                      onTap: onClearSelections,
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

          // Ingredients Grid
          if (isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCB6B2E)),
                ),
              ),
            )
          else if (filteredIngredients.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 48, color: Color(0xFFCB6B2E)),
                    SizedBox(height: 12),
                    Text(
                      'No ingredients found',
                      style: TextStyle(color: Color(0xFF3A2214), fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final ingredient = filteredIngredients[index];
                    final isSelected = selectedIngredients.contains(ingredient.name);
                    return _IngredientCard(
                      ingredient: ingredient,
                      isSelected: isSelected,
                      onTap: () => onToggleIngredient(ingredient),
                    );
                  },
                  childCount: filteredIngredients.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Select your ingredients',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                      ),
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
                      children: [
                        const Icon(Icons.checklist, size: 16, color: Color(0xFFCB6B2E)),
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
            'Select Ingredients',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Tap on ingredients to select what you have',
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
                    'Browse ingredients...',
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFCB6B2E).withOpacity(0.1) : Colors.transparent,
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
          children: [
            // Image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8DF).withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Image.network(
                      ingredient.imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.restaurant,
                          size: 45,
                          color: const Color(0xFFCB6B2E).withOpacity(0.7),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFCB6B2E)),
                          ),
                        );
                      },
                    ),
                    if (isSelected)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Color(0xFFCB6B2E),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                ingredient.name,
                style: TextStyle(
                  color: const Color(0xFF3A2214),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Category indicator
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFCB6B2E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                ingredient.category,
                style: TextStyle(
                  color: const Color(0xFFCB6B2E),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}