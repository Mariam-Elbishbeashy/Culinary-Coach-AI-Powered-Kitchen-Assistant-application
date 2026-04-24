import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:culinary_coach_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:culinary_coach_app/features/filter/presentation/screens/filter_screen.dart';
import 'package:culinary_coach_app/features/filter/presentation/screens/scan.dart';

class MyRecipesScreen extends StatefulWidget {
  const MyRecipesScreen({super.key});

  @override
  State<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _userName;

  // Demo recipe data - replace with Firestore data later
  final List<RecipeModel> _historyRecipes = [
    RecipeModel(
      id: '1',
      name: 'Chicken Pasta Alfredo',
      imageUrl: 'https://www.themealdb.com/images/media/meals/xxrxux7355331237.jpg',
      cookingTime: '25 min',
      date: DateTime.now().subtract(const Duration(days: 1)),
    ),
    RecipeModel(
      id: '2',
      name: 'Vegetable Stir Fry',
      imageUrl: 'https://www.themealdb.com/images/media/meals/xxpqnq1479766079.jpg',
      cookingTime: '15 min',
      date: DateTime.now().subtract(const Duration(days: 3)),
    ),
    RecipeModel(
      id: '3',
      name: 'Beef Tacos',
      imageUrl: 'https://www.themealdb.com/images/media/meals/uvuyxu1503067369.jpg',
      cookingTime: '20 min',
      date: DateTime.now().subtract(const Duration(days: 5)),
    ),
    RecipeModel(
      id: '4',
      name: 'Mediterranean Salad',
      imageUrl: 'https://www.themealdb.com/images/media/meals/wvpsxx1468256321.jpg',
      cookingTime: '10 min',
      date: DateTime.now().subtract(const Duration(days: 7)),
    ),
    RecipeModel(
      id: '5',
      name: 'Lemon Garlic Salmon',
      imageUrl: 'https://www.themealdb.com/images/media/meals/upxqpq1495563155.jpg',
      cookingTime: '30 min',
      date: DateTime.now().subtract(const Duration(days: 10)),
    ),
  ];

  final List<RecipeModel> _favoriteRecipes = [
    RecipeModel(
      id: '101',
      name: 'Spaghetti Carbonara',
      imageUrl: 'https://www.themealdb.com/images/media/meals/xxrxux7355331237.jpg',
      cookingTime: '20 min',
      isFavorite: true,
      date: DateTime.now().subtract(const Duration(days: 2)),
    ),
    RecipeModel(
      id: '102',
      name: 'Margherita Pizza',
      imageUrl: 'https://www.themealdb.com/images/media/meals/xxpqnq1479766079.jpg',
      cookingTime: '35 min',
      isFavorite: true,
      date: DateTime.now().subtract(const Duration(days: 4)),
    ),
    RecipeModel(
      id: '103',
      name: 'Chocolate Lava Cake',
      imageUrl: 'https://www.themealdb.com/images/media/meals/uvuyxu1503067369.jpg',
      cookingTime: '15 min',
      isFavorite: true,
      date: DateTime.now().subtract(const Duration(days: 6)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = doc.data();
        final firstName = (data?['firstName'] as String?)?.trim();
        if (firstName != null && firstName.isNotEmpty) {
          setState(() => _userName = firstName);
          return;
        }
      } catch (_) {}

      // Fallback to display name or email
      final fallback = user.displayName?.split(' ').first ??
          user.email?.split('@').first ??
          'Chef';
      setState(() => _userName = fallback);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final displayName = _userName ??
        currentUser?.displayName?.split(' ').first ??
        currentUser?.email?.split('@').first ??
        'Chef';

    return Scaffold(
      backgroundColor: const Color(0xFFF3E8DF),
      body: CustomScrollView(
        slivers: [
          // Top Hero Bar
          SliverToBoxAdapter(
            child: _MyRecipesHero(
              displayName: displayName,
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
            ),
          ),

          // Tab Bar
          // Tab Bar
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFE7E5FF)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFCB6B2E).withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _tabController.animateTo(0);
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _tabController.index == 0 ? const Color(0xFFCB6B2E) : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            'History',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                              color: _tabController.index == 0 ? Colors.white : const Color(0xFF8D87A6),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _tabController.animateTo(1);
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _tabController.index == 1 ? const Color(0xFFCB6B2E) : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            'Favorites',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                              color: _tabController.index == 1 ? Colors.white : const Color(0xFF8D87A6),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tab Bar Views
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                // History Tab
                _buildRecipeList(_historyRecipes, isHistory: true),
                // Favorites Tab
                _buildRecipeList(_favoriteRecipes, isHistory: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeList(List<RecipeModel> recipes, {required bool isHistory}) {
    if (recipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isHistory ? Icons.history : Icons.favorite_border,
              size: 64,
              color: const Color(0xFFCB6B2E).withAlpha(100),
            ),
            const SizedBox(height: 16),
            Text(
              isHistory ? 'No recipes in history yet' : 'No favorite recipes yet',
              style: const TextStyle(
                color: Color(0xFF3A2214),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isHistory ? 'Start cooking to see your history' : 'Tap the ❤️ on recipes to add them here',
              style: TextStyle(
                color: const Color(0xFF8B7355),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return _RecipeCard(
          recipe: recipe,
          isHistory: isHistory,
          onToggleFavorite: () {
            setState(() {
              if (isHistory) {
                // For history items, toggle favorite status
                recipe.isFavorite = !recipe.isFavorite;
                if (recipe.isFavorite) {
                  // Add to favorites
                  _favoriteRecipes.insert(0, RecipeModel(
                    id: recipe.id,
                    name: recipe.name,
                    imageUrl: recipe.imageUrl,
                    cookingTime: recipe.cookingTime,
                    isFavorite: true,
                    date: DateTime.now(),
                  ));
                } else {
                  // Remove from favorites
                  _favoriteRecipes.removeWhere((r) => r.id == recipe.id);
                }
              } else {
                // For favorites, remove from favorites
                _favoriteRecipes.removeWhere((r) => r.id == recipe.id);
                // Update history item if exists
                final historyIndex = _historyRecipes.indexWhere((r) => r.id == recipe.id);
                if (historyIndex != -1) {
                  _historyRecipes[historyIndex].isFavorite = false;
                }
              }
            });
          },
          onTap: () {
            // Navigate to recipe details
            _showRecipeDetails(context, recipe);
          },
        );
      },
    );
  }

  void _showRecipeDetails(BuildContext context, RecipeModel recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RecipeDetailsSheet(recipe: recipe),
    );
  }
}



class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? const Color(0xFFCB6B2E) : const Color(0xFF8B7355),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFFCB6B2E) : const Color(0xFF8B7355),
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Recipe Card Widget
class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.recipe,
    required this.isHistory,
    required this.onToggleFavorite,
    required this.onTap,
  });

  final RecipeModel recipe;
  final bool isHistory;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return const Color(0xFF5A9A44);
      case 'medium':
        return const Color(0xFFF0A73A);
      case 'hard':
        return const Color(0xFFD45050);
      default:
        return const Color(0xFF8B7355);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Recipe Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
              child: Image.network(
                recipe.imageUrl,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 100,
                    height: 100,
                    color: const Color(0xFFF3E8DF),
                    child: Icon(
                      Icons.restaurant,
                      size: 40,
                      color: const Color(0xFFCB6B2E).withAlpha(100),
                    ),
                  );
                },
              ),
            ),

            // Recipe Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3A2214),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: const Color(0xFFCB6B2E).withAlpha(180),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          recipe.cookingTime,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8B7355),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                          ),

                        ),
                      ],
                    ),
                    if (isHistory) ...[
                      const SizedBox(height: 6),
                      Text(
                        _formatDate(recipe.date),
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFF8B7355).withAlpha(150),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Favorite Button
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: onToggleFavorite,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: recipe.isFavorite
                        ? const Color(0xFFCB6B2E).withAlpha(20)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: recipe.isFavorite
                        ? const Color(0xFFCB6B2E)
                        : const Color(0xFF8B7355),
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Recipe Details Bottom Sheet
class _RecipeDetailsSheet extends StatelessWidget {
  const _RecipeDetailsSheet({required this.recipe});

  final RecipeModel recipe;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCB6B2E).withAlpha(50),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Image
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  child: Image.network(
                    recipe.imageUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 160,
                        color: const Color(0xFFF3E8DF),
                        child: Center(
                          child: Icon(
                            Icons.restaurant,
                            size: 60,
                            color: const Color(0xFFCB6B2E).withAlpha(100),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3A2214),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          _InfoChip(
                            icon: Icons.timer_outlined,
                            label: recipe.cookingTime,
                          ),
                          const SizedBox(width: 12),

                        ],
                      ),

                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFFF0E0D0)),
                      const SizedBox(height: 16),

                      const Text(
                        'Ingredients',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3A2214),
                        ),
                      ),
                      const SizedBox(height: 12),

                      ..._getSampleIngredients().map(
                            (ingredient) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.circle,
                                size: 6,
                                color: Color(0xFFCB6B2E),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  ingredient,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF5A4A3A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'Instructions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3A2214),
                        ),
                      ),
                      const SizedBox(height: 12),

                      ..._getSampleInstructions()
                          .asMap()
                          .entries
                          .map(
                            (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCB6B2E)
                                      .withAlpha(20),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    '${entry.key + 1}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFCB6B2E),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  entry.value,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF5A4A3A),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFCB6B2E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'Start Cooking',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

List<String> _getSampleIngredients() {
  return [
    '2 cups pasta',
    '3 cloves garlic, minced',
    '1 onion, diced',
    '2 tbsp olive oil',
    'Salt and pepper to taste',
    'Fresh herbs for garnish',
  ];
}

List<String> _getSampleInstructions() {
  return [
    'Prepare all ingredients according to recipe specifications.',
    'Heat olive oil in a large pan over medium heat.',
    'Add onions and garlic, sauté until fragrant (about 2 minutes).',
    'Add main ingredients and cook until properly done.',
    'Season with salt and pepper to taste.',
    'Garnish with fresh herbs and serve hot.',
  ];
}


class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E8DF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFCB6B2E)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF3A2214),
            ),
          ),
        ],
      ),
    );
  }
}

// Hero Section
class _MyRecipesHero extends StatelessWidget {
  const _MyRecipesHero({
    required this.displayName,
    required this.onProfileTap,
    required this.onSettingsTap,
  });

  final String displayName;
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;

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
                      'Your recipe collection',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                      ),
                    ),
                  ],
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
            'My Recipes',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'History & favorites at a glance',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
              fontSize: 13,
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

// Recipe Model
class RecipeModel {
  final String id;
  final String name;
  final String imageUrl;
  final String cookingTime;
  bool isFavorite;
  final DateTime date;

  RecipeModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.cookingTime,
    this.isFavorite = false,
    required this.date,
  });
}