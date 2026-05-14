// lib/features/my_recipes/presentation/screens/my_recipes_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:culinary_coach_app/core/widgets/current_user_avatar.dart';
import 'package:culinary_coach_app/features/home/data/models/recipe_match.dart';
import 'package:culinary_coach_app/features/home/presentation/screens/recipe_details_screen.dart';
import 'package:culinary_coach_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:culinary_coach_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Extension to add Firestore methods to RecipeMatch
extension RecipeMatchFirestore on RecipeMatch {
  Map<String, dynamic> toFirestoreStarted() {
    return {
      'calories': calories,
      'difficulty': difficulty,
      'image': image,
      'instructions': instructions,
      'missedIngredientCount': missedIngredientCount,
      'missedIngredients': missedIngredients,
      'preparationMinutes': preparationMinutes,
      'rating': rating,
      'readyInMinutes': readyInMinutes,
      'recipeId': id,
      'servings': servings,
      'startedAt': FieldValue.serverTimestamp(),
      'summary': summary,
      'title': title,
      'unusedIngredients': unusedIngredients,
      'usedIngredientCount': usedIngredientCount,
      'usedIngredients': usedIngredients,
    };
  }

  Map<String, dynamic> toFirestoreFavorite() {
    return {
      'calories': calories,
      'image': image,
      'instructions': instructions,
      'missedIngredientCount': missedIngredientCount,
      'missedIngredients': missedIngredients,
      'rating': rating,
      'readyInMinutes': readyInMinutes,
      'recipeId': id,
      'savedAt': FieldValue.serverTimestamp(),
      'servings': servings,
      'summary': summary,
      'title': title,
      'unusedIngredients': unusedIngredients,
      'usedIngredientCount': usedIngredientCount,
      'usedIngredients': usedIngredients,
    };
  }
}

// Helper function to convert Firestore data to RecipeMatch
RecipeMatch _recipeMatchFromFirestore(Map<String, dynamic> data, String docId) {
  return RecipeMatch(
    id: data['recipeId'] as int? ?? int.tryParse(docId) ?? 0,
    title: data['title'] as String? ?? '',
    image: data['image'] as String? ?? '',
    usedIngredientCount: data['usedIngredientCount'] as int? ?? 0,
    missedIngredientCount: data['missedIngredientCount'] as int? ?? 0,
    rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
    readyInMinutes: data['readyInMinutes'] as int? ?? 0,
    servings: data['servings'] as int? ?? 0,
    calories: data['calories'] as int? ?? 0,
    difficulty: data['difficulty'] as String?,
    preparationMinutes: data['preparationMinutes'] as int?,
    ingredientDetails: const [],
    summary: data['summary'] as String? ?? '',
    usedIngredients: List<String>.from(data['usedIngredients'] ?? []),
    missedIngredients: List<String>.from(data['missedIngredients'] ?? []),
    unusedIngredients: List<String>.from(data['unusedIngredients'] ?? []),
    instructions: List<String>.from(data['instructions'] ?? []),
  );
}

class MyRecipesScreen extends StatefulWidget {
  const MyRecipesScreen({
    super.key,
    required this.isDarkMode,
    required this.onDarkModeChanged,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;

  @override
  State<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Future<void> _persistFavoriteRecipeCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'favoriteRecipesCount': _favoriteRecipes.length},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserName();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _persistFavoriteRecipeCount();
    });
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

  void _toggleDarkMode() {
    // Call the parent's callback to update dark mode globally
    widget.onDarkModeChanged(!widget.isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final userId = currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        backgroundColor: widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFF3E8DF),
        body: const Center(
          child: Text('Please sign in to view your recipes.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFF3E8DF),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _MyRecipesHero(
              isDarkMode: widget.isDarkMode,
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
              onDarkModeToggle: _toggleDarkMode,
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: widget.isDarkMode
                      ? const Color(0xFF2C2C2C).withValues(alpha: 0.88)
                      : Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: widget.isDarkMode ? const Color(0xFF444444) : const Color(0xFFE7E5FF)),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.isDarkMode ? const Color(0xFF000000) : const Color(0xFFCB6B2E)).withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _tabController.animateTo(0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _tabController.index == 0
                                ? const Color(0xFFCB6B2E)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            'History',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                              color: _tabController.index == 0
                                  ? Colors.white
                                  : (widget.isDarkMode ? const Color(0xFFA0A0A0) : const Color(0xFF8D87A6)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _tabController.animateTo(1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _tabController.index == 1
                                ? const Color(0xFFCB6B2E)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            'Favorites',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                              color: _tabController.index == 1
                                  ? Colors.white
                                  : (widget.isDarkMode ? const Color(0xFFA0A0A0) : const Color(0xFF8D87A6)),
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
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _HistoryTab(userId: userId, isDarkMode: widget.isDarkMode),
                _FavoritesTab(userId: userId, isDarkMode: widget.isDarkMode),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.userId, required this.isDarkMode});

  final String userId;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('started_recipes')
          .orderBy('startedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Color(0xFFCB6B2E)),
                const SizedBox(height: 12),
                Text('Error: ${snapshot.error}', style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87)),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFCB6B2E)),
          );
        }

        final recipes = snapshot.data?.docs ?? [];

        if (recipes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: const Color(0xFFCB6B2E).withValues(alpha: 0.7)),
                const SizedBox(height: 16),
                Text(
                  'No recipes in history yet',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : const Color(0xFF3A2214),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start cooking to see your history',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white38 : const Color(0xFF8B7355),
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
            _persistFavoriteRecipeCount();
          },
          onTap: () {
            // Navigate to recipe details
            _showRecipeDetails(context, recipe);
          },
        );
      },
    );
  }
}

class _FavoritesTab extends StatelessWidget {
  const _FavoritesTab({required this.userId, required this.isDarkMode});

  final String userId;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('favorite_recipes')
          .orderBy('savedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Color(0xFFCB6B2E)),
                const SizedBox(height: 12),
                Text('Error: ${snapshot.error}', style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87)),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFCB6B2E)),
          );
        }

        final recipes = snapshot.data?.docs ?? [];

        if (recipes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: 64, color: const Color(0xFFCB6B2E).withValues(alpha: 0.7)),
                const SizedBox(height: 16),
                Text(
                  'No favorite recipes yet',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : const Color(0xFF3A2214),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the ❤️ on recipes to add them here',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white38 : const Color(0xFF8B7355),
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
          physics: const AlwaysScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            final doc = recipes[index];
            final data = doc.data() as Map<String, dynamic>;
            final recipe = _recipeMatchFromFirestore(data, doc.id);
            final savedAt = data['savedAt'] as Timestamp?;
            return _RecipeCard(
              recipe: recipe,
              recipeId: doc.id,
              userId: userId,
              isHistory: false,
              timestamp: savedAt,
              isDarkMode: isDarkMode,
            );
          },
        );
      },
    );
  }
}

class _RecipeCard extends StatefulWidget {
  const _RecipeCard({
    required this.recipe,
    required this.recipeId,
    required this.userId,
    required this.isHistory,
    required this.isDarkMode,
    this.timestamp,
  });

  final RecipeMatch recipe;
  final String recipeId;
  final String userId;
  final bool isHistory;
  final Timestamp? timestamp;
  final bool isDarkMode;

  @override
  State<_RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<_RecipeCard> {
  bool _isFavorite = false;
  bool _isLoadingFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkIfFavorite();
  }

  Future<void> _checkIfFavorite() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('favorite_recipes')
        .doc(widget.recipeId)
        .get();

    if (mounted) {
      setState(() {
        _isFavorite = doc.exists;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isLoadingFavorite) return;
    setState(() => _isLoadingFavorite = true);

    try {
      final favRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('favorite_recipes')
          .doc(widget.recipeId);

      if (_isFavorite) {
        await favRef.delete();
        setState(() => _isFavorite = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Removed from favorites'),
              backgroundColor: widget.isDarkMode ? Colors.grey[800] : const Color(0xFF8B7355),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        final favoriteData = widget.recipe.toFirestoreFavorite();
        await favRef.set(favoriteData);
        setState(() => _isFavorite = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Added to favorites'), backgroundColor: Color(0xFFCB6B2E), duration: Duration(seconds: 1)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update favorites'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingFavorite = false);
    }
  }

  Future<void> _removeFromHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFFCF7E8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove from history?',
          style: TextStyle(
            color: widget.isDarkMode ? Colors.white : const Color(0xFF3A2214),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This recipe will be removed from your history.',
          style: TextStyle(
            color: widget.isDarkMode ? Colors.white70 : const Color(0xFF8B7355),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: widget.isDarkMode ? Colors.white60 : const Color(0xFF8B7355))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Color(0xFFCB6B2E))),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('started_recipes')
          .doc(widget.recipeId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Removed from history'),
            backgroundColor: widget.isDarkMode ? Colors.grey[800] : const Color(0xFF8B7355),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove from history'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Recently';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    }
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final canMakeNow = widget.recipe.missedIngredientCount == 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeDetailsScreen(recipe: widget.recipe)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: widget.isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: canMakeNow
              ? Border.all(color: const Color(0xFF9BEA7A), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: (widget.isDarkMode ? Colors.black : Colors.black).withAlpha(
                widget.isDarkMode ? 40 : 8,
              ),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
              child: widget.recipe.image.isNotEmpty
                  ? Image.network(
                widget.recipe.image,
                width: 100,
                height: 117,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 100,
                    height: 100,
                    color: widget.isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF3E8DF),
                    child: Icon(Icons.restaurant, size: 40, color: const Color(0xFFCB6B2E).withAlpha(100)),
                  );
                },
              )
                  : Container(
                width: 100,
                height: 100,
                color: widget.isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF3E8DF),
                child: Icon(Icons.restaurant, size: 40, color: const Color(0xFFCB6B2E).withAlpha(100)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.recipe.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: widget.isDarkMode ? Colors.white : const Color(0xFF3A2214),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 14, color: const Color(0xFFCB6B2E).withAlpha(180)),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.recipe.readyInMinutes} min',
                          style: TextStyle(fontSize: 12, color: widget.isDarkMode ? Colors.white60 : const Color(0xFF8B7355)),
                        ),
                        const SizedBox(width: 12),
                        if (widget.recipe.usedIngredientCount > 0 || widget.recipe.missedIngredientCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: canMakeNow
                                  ? const Color(0xFF9BEA7A).withAlpha(30)
                                  : const Color(0xFFFFCF7A).withAlpha(30),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              canMakeNow ? 'Ready to cook!' : '${widget.recipe.missedIngredientCount} missing',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: canMakeNow ? const Color(0xFF2D6A1F) : const Color(0xFFB87313),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (widget.timestamp != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _formatDate(widget.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: (widget.isDarkMode ? Colors.white38 : const Color(0xFF8B7355)).withAlpha(150),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _toggleFavorite,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isFavorite
                            ? const Color(0xFFCB6B2E).withAlpha(20)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: _isLoadingFavorite
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFCB6B2E)),
                      )
                          : Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite ? const Color(0xFFCB6B2E) : (widget.isDarkMode ? Colors.white54 : const Color(0xFF8B7355)),
                        size: 22,
                      ),
                    ),
                  ),
                  if (widget.isHistory)
                    GestureDetector(
                      onTap: _removeFromHistory,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.close,
                          color: widget.isDarkMode ? Colors.white54 : const Color(0xFF8B7355),
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyRecipesHero extends StatelessWidget {
  const _MyRecipesHero({
    required this.isDarkMode,
    required this.onProfileTap,
    required this.onSettingsTap,
    required this.onDarkModeToggle,
  });

  final bool isDarkMode;
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onDarkModeToggle;

  String? _extractFirstName(String? displayName) {
    final value = (displayName ?? '').trim();
    if (value.isEmpty) return null;
    return value.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final topInset = MediaQuery.of(context).padding.top;

    return StreamBuilder<DocumentSnapshot>(
      stream: currentUser == null ? null : FirebaseFirestore.instance.collection('users').doc(currentUser.uid).snapshots(),
      builder: (context, userSnapshot) {
        String displayName = 'Chef';
        String? profileImageUrl;
        String? profileImageLocalPath;

        if (currentUser != null) {
          final data = userSnapshot.data?.data() as Map<String, dynamic>?;
          final firstName = (data?['firstName'] as String?)?.trim();
          final fallbackName = _extractFirstName(currentUser.displayName) ?? 'Chef';
          displayName = (firstName != null && firstName.isNotEmpty) ? firstName : fallbackName;
          profileImageUrl = (data?['profileImageUrl'] as String?)?.trim();
          profileImageLocalPath = (data?['profileImageLocalPath'] as String?)?.trim();
        }

        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(18, topInset + 6, 18, 20),
          decoration: BoxDecoration(
            gradient: isDarkMode
                ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1A1A), Color(0xFF2D2D2D), Color(0xFF3D3D3D)],
              stops: [0.0, 0.35, 1.0],
            )
                : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFCC7705), Color(0xFFDD8E1E), Color(0xFFF0A73A)],
              stops: [0.0, 0.35, 1.0],
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: onProfileTap,
                    child: CurrentUserAvatar(
                      size: 32,
                      onTap: onProfileTap,
                      overrideImageUrl: profileImageUrl,
                      overrideLocalPath: profileImageLocalPath,
                      backgroundColor: isDarkMode ? const Color(0xFF444444) : const Color(0xFFD28E18),
                      borderColor: Colors.white.withValues(alpha: 0.65),
                      borderWidth: 2,
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
                    icon: isDarkMode ? Icons.light_mode : Icons.dark_mode,
                    onTap: onDarkModeToggle,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(width: 8),
                  _CircleActionButton(icon: Icons.settings_outlined, onTap: onSettingsTap, isDarkMode: isDarkMode),
                ],
              ),
              const SizedBox(height: 16),
              const Text('My Recipes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22)),
              const SizedBox(height: 2),
              const Text('History & favorites at a glance', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500, fontSize: 13)),
            ],
          ),
        );
      },
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({required this.icon, required this.onTap, required this.isDarkMode});

  final IconData icon;
  final VoidCallback onTap;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        width: 32,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF444444) : Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isDarkMode ? Colors.white70 : const Color(0xFF6C6C6C), size: 18),
      ),
    );
  }
}