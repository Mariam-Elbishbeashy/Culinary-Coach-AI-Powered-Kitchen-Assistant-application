// lib/features/home/presentation/screens/recipe_list_screen.dart

import 'dart:math' as math;

import 'package:culinary_coach_app/features/home/data/models/recipe_match.dart';
import 'package:culinary_coach_app/features/home/data/services/favorite_recipes_service.dart';
import 'package:culinary_coach_app/features/home/presentation/screens/recipe_details_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({
    super.key,
    required this.title,
    required this.recipes,
  });

  final String title;
  final List<RecipeMatch> recipes;

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FavoriteRecipesService _favoriteRecipesService =
      FavoriteRecipesService();

  int _maxMissingIngredients = 20;
  bool _onlyCanMakeNow = false;
  bool _onlyMissingOne = false;
  String _sortBy = 'Best match';
  String _selectedRecipeTime = 'Any';
  double _minRating = 0;
  String _selectedCalories = 'Any';
  final Map<int, bool> _favoriteOverrides = <int, bool>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalizeText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _searchTokens(String query) {
    return _normalizeText(query)
        .split(' ')
        .map((token) => token.trim())
        .where((token) => token.length > 1)
        .toSet()
        .toList();
  }

  String _recipeSearchText(RecipeMatch recipe) {
    return _normalizeText(
      [
        recipe.title,
        recipe.summary,
        ...recipe.usedIngredients,
        ...recipe.missedIngredients,
        ...recipe.unusedIngredients,
        ...recipe.instructions,
      ].join(' '),
    );
  }

  bool _matchesSearch(RecipeMatch recipe, List<String> tokens) {
    if (tokens.isEmpty) return true;
    final text = _recipeSearchText(recipe);
    return tokens.every(text.contains);
  }

  List<RecipeMatch> get _filteredRecipes {
    final tokens = _searchTokens(_searchController.text);
    final maxReadyTime = _maxReadyTimeFromFilter();
    final maxCalories = _maxCaloriesFromFilter();

    final filtered = widget.recipes.where((recipe) {
      if (!_matchesSearch(recipe, tokens)) return false;

      if (_onlyCanMakeNow && recipe.missedIngredientCount != 0) return false;

      if (_onlyMissingOne && recipe.missedIngredientCount != 1) return false;

      if (recipe.missedIngredientCount > _maxMissingIngredients) return false;

      if (maxReadyTime != null) {
        if (recipe.readyInMinutes <= 0) return false;
        if (recipe.readyInMinutes > maxReadyTime) return false;
      }

      if (_minRating > 0) {
        if (recipe.rating <= 0) return false;
        if (recipe.rating < _minRating) return false;
      }

      if (maxCalories != null) {
        if (recipe.calories <= 0) return false;
        if (recipe.calories > maxCalories) return false;
      }

      return true;
    }).toList();

    int compareBestMatch(RecipeMatch a, RecipeMatch b) {
      final missing = a.missedIngredientCount.compareTo(
        b.missedIngredientCount,
      );
      if (missing != 0) return missing;
      final used = b.usedIngredientCount.compareTo(a.usedIngredientCount);
      if (used != 0) return used;
      final rating = b.rating.compareTo(a.rating);
      if (rating != 0) return rating;
      return a.readyInMinutes.compareTo(b.readyInMinutes);
    }

    if (_sortBy == 'Best match') {
      filtered.sort(compareBestMatch);
    } else if (_sortBy == 'Fewest missing') {
      filtered.sort((a, b) {
        final missing = a.missedIngredientCount.compareTo(
          b.missedIngredientCount,
        );
        if (missing != 0) return missing;
        return compareBestMatch(a, b);
      });
    } else if (_sortBy == 'Most used') {
      filtered.sort((a, b) {
        final used = b.usedIngredientCount.compareTo(a.usedIngredientCount);
        if (used != 0) return used;
        return compareBestMatch(a, b);
      });
    } else if (_sortBy == 'Highest rating') {
      filtered.sort((a, b) {
        final rating = b.rating.compareTo(a.rating);
        if (rating != 0) return rating;
        return compareBestMatch(a, b);
      });
    } else if (_sortBy == 'Fastest time') {
      filtered.sort((a, b) {
        final aTime = a.readyInMinutes <= 0 ? 99999 : a.readyInMinutes;
        final bTime = b.readyInMinutes <= 0 ? 99999 : b.readyInMinutes;
        final time = aTime.compareTo(bTime);
        if (time != 0) return time;
        return compareBestMatch(a, b);
      });
    } else if (_sortBy == 'Lowest calories') {
      filtered.sort((a, b) {
        final aCalories = a.calories <= 0 ? 99999 : a.calories;
        final bCalories = b.calories <= 0 ? 99999 : b.calories;
        final calories = aCalories.compareTo(bCalories);
        if (calories != 0) return calories;
        return compareBestMatch(a, b);
      });
    }

    return filtered;
  }

  int get _activeFilterCount {
    int count = 0;
    if (_onlyCanMakeNow) count++;
    if (_onlyMissingOne) count++;
    if (_maxMissingIngredients != 20) count++;
    if (_sortBy != 'Best match') count++;
    if (_selectedRecipeTime != 'Any') count++;
    if (_minRating > 0) count++;
    if (_selectedCalories != 'Any') count++;
    return count;
  }

  int? _maxReadyTimeFromFilter() {
    if (_selectedRecipeTime == 'Under 15 min') return 15;
    if (_selectedRecipeTime == 'Under 30 min') return 30;
    if (_selectedRecipeTime == 'Under 60 min') return 60;
    return null;
  }

  int? _maxCaloriesFromFilter() {
    if (_selectedCalories == 'Under 300 cal') return 300;
    if (_selectedCalories == 'Under 500 cal') return 500;
    if (_selectedCalories == 'Under 700 cal') return 700;
    return null;
  }

  String get _ratingLabel {
    if (_minRating >= 4.5) return '4.5+ Stars';
    if (_minRating >= 4.0) return '4+ Stars';
    if (_minRating >= 3.0) return '3+ Stars';
    return 'Any';
  }

  double _ratingValueFromLabel(String label) {
    if (label == '3+ Stars') return 3.0;
    if (label == '4+ Stars') return 4.0;
    if (label == '4.5+ Stars') return 4.5;
    return 0;
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFCF7E8),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void refresh() {
              setSheetState(() {});
              setState(() {});
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  16,
                  18,
                  MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFE2C9A4),
                                ),
                              ),
                              child: const Icon(
                                Icons.arrow_back_rounded,
                                color: Color(0xFFB87313),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Filters',
                              style: TextStyle(
                                color: Color(0xFF3A2214),
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              _onlyCanMakeNow = false;
                              _onlyMissingOne = false;
                              _maxMissingIngredients = 20;
                              _sortBy = 'Best match';
                              _selectedRecipeTime = 'Any';
                              _minRating = 0;
                              _selectedCalories = 'Any';
                              refresh();
                            },
                            child: const Text(
                              'Reset',
                              style: TextStyle(
                                color: Color(0xFFB87313),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _FilterSwitchTile(
                        title: 'Recipes I can make now',
                        value: _onlyCanMakeNow,
                        onChanged: (value) {
                          _onlyCanMakeNow = value;
                          if (value) _onlyMissingOne = false;
                          refresh();
                        },
                      ),
                      const SizedBox(height: 10),
                      _FilterSwitchTile(
                        title: 'Missing one ingredient only',
                        value: _onlyMissingOne,
                        onChanged: (value) {
                          _onlyMissingOne = value;
                          if (value) _onlyCanMakeNow = false;
                          refresh();
                        },
                      ),
                      const SizedBox(height: 14),
                      _MissingSlider(
                        value: _maxMissingIngredients,
                        onChanged: (value) {
                          _maxMissingIngredients = value;
                          refresh();
                        },
                      ),
                      const SizedBox(height: 18),
                      _ChoiceSection(
                        title: 'Recipe time',
                        selected: _selectedRecipeTime,
                        values: const [
                          'Any',
                          'Under 15 min',
                          'Under 30 min',
                          'Under 60 min',
                        ],
                        onSelected: (value) {
                          _selectedRecipeTime = value;
                          refresh();
                        },
                      ),
                      const SizedBox(height: 18),
                      _ChoiceSection(
                        title: 'Rating',
                        selected: _ratingLabel,
                        values: const [
                          'Any',
                          '3+ Stars',
                          '4+ Stars',
                          '4.5+ Stars',
                        ],
                        onSelected: (value) {
                          _minRating = _ratingValueFromLabel(value);
                          refresh();
                        },
                      ),
                      const SizedBox(height: 18),
                      _ChoiceSection(
                        title: 'Calories',
                        selected: _selectedCalories,
                        values: const [
                          'Any',
                          'Under 300 cal',
                          'Under 500 cal',
                          'Under 700 cal',
                        ],
                        onSelected: (value) {
                          _selectedCalories = value;
                          refresh();
                        },
                      ),
                      const SizedBox(height: 18),
                      _ChoiceSection(
                        title: 'Sort by',
                        selected: _sortBy,
                        values: const [
                          'Best match',
                          'Fewest missing',
                          'Most used',
                          'Highest rating',
                          'Fastest time',
                          'Lowest calories',
                        ],
                        onSelected: (value) {
                          _sortBy = value;
                          refresh();
                        },
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB87313),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Text(
                            'Done (${_filteredRecipes.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleFavoriteRecipe({
    required String userId,
    required RecipeMatch recipe,
    required bool isFavorite,
  }) async {
    if (recipe.id <= 0) return;
    final nextValue = !isFavorite;
    setState(() => _favoriteOverrides[recipe.id] = nextValue);

    try {
      if (nextValue) {
        await _favoriteRecipesService.saveFavoriteRecipe(
          userId: userId,
          recipe: recipe,
        );
      } else {
        await _favoriteRecipesService.removeFavoriteRecipe(
          userId: userId,
          recipeId: recipe.id,
        );
      }
      if (!mounted) return;
      setState(() => _favoriteOverrides.remove(recipe.id));
    } catch (_) {
      if (!mounted) return;
      setState(() => _favoriteOverrides.remove(recipe.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not update favorites right now. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipes = _filteredRecipes;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F1DE),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFF3A2214),
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Color(0xFF3A2214),
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                height: 48,
                padding: const EdgeInsets.only(left: 16, right: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF888888),
                      size: 25,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        cursorColor: const Color(0xFF6A6A6A),
                        decoration: const InputDecoration(
                          hintText: 'Search recipe',
                          hintStyle: TextStyle(
                            color: Color(0xFF9A9A9A),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          onPressed: _openFilterSheet,
                          icon: const Icon(
                            Icons.tune_rounded,
                            color: Color(0xFF888888),
                            size: 23,
                          ),
                        ),
                        if (_activeFilterCount > 0)
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              width: 16,
                              height: 16,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFFB87313),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$_activeFilterCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${recipes.length} of ${widget.recipes.length} recipes',
                      style: const TextStyle(
                        color: Color(0xFF8B7355),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_activeFilterCount > 0 ||
                      _searchController.text.trim().isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() {
                          _onlyCanMakeNow = false;
                          _onlyMissingOne = false;
                          _maxMissingIngredients = 20;
                          _sortBy = 'Best match';
                          _selectedRecipeTime = 'Any';
                          _minRating = 0;
                          _selectedCalories = 'Any';
                        });
                      },
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          color: Color(0xFFB87313),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<Set<int>>(
                stream: currentUserId == null
                    ? null
                    : _favoriteRecipesService.streamFavoriteRecipeIds(
                        currentUserId,
                      ),
                initialData: const <int>{},
                builder: (context, favoritesSnapshot) {
                  final favoriteIds = Set<int>.from(
                    favoritesSnapshot.data ?? const <int>{},
                  );
                  final effectiveFavoriteIds = <int>{...favoriteIds};

                  _favoriteOverrides.forEach((recipeId, isFavorite) {
                    if (isFavorite) {
                      effectiveFavoriteIds.add(recipeId);
                    } else {
                      effectiveFavoriteIds.remove(recipeId);
                    }
                  });

                  if (recipes.isEmpty) {
                    return const Center(
                      child: Text(
                        'No recipes found. Try clearing search or filters.',
                        style: TextStyle(
                          color: Color(0xFF8B7355),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                    child: _MasonryRecipeGrid(
                      recipes: recipes,
                      favoriteRecipeIds: effectiveFavoriteIds,
                      onToggleFavorite: (recipe) {
                        if (currentUserId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please sign in to save favorite recipes.',
                              ),
                            ),
                          );
                          return;
                        }

                        _toggleFavoriteRecipe(
                          userId: currentUserId,
                          recipe: recipe,
                          isFavorite: effectiveFavoriteIds.contains(recipe.id),
                        );
                      },
                    ),
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

class _MasonryRecipeGrid extends StatelessWidget {
  const _MasonryRecipeGrid({
    required this.recipes,
    required this.favoriteRecipeIds,
    required this.onToggleFavorite,
  });

  final List<RecipeMatch> recipes;
  final Set<int> favoriteRecipeIds;
  final ValueChanged<RecipeMatch> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final left = <RecipeMatch>[];
    final right = <RecipeMatch>[];

    for (int i = 0; i < recipes.length; i++) {
      if (i.isEven) {
        left.add(recipes[i]);
      } else {
        right.add(recipes[i]);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: List.generate(left.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _MasonryRecipeCard(
                  recipe: left[index],
                  height: index.isEven ? 260 : 315,
                  isFavorite: favoriteRecipeIds.contains(left[index].id),
                  onToggleFavorite: () => onToggleFavorite(left[index]),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            children: List.generate(right.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _MasonryRecipeCard(
                  recipe: right[index],
                  height: index.isEven ? 310 : 255,
                  isFavorite: favoriteRecipeIds.contains(right[index].id),
                  onToggleFavorite: () => onToggleFavorite(right[index]),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _MasonryRecipeCard extends StatelessWidget {
  const _MasonryRecipeCard({
    required this.recipe,
    required this.height,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final RecipeMatch recipe;
  final double height;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  bool get _hasMissingOrUsed =>
      recipe.usedIngredientCount > 0 || recipe.missedIngredientCount > 0;

  @override
  Widget build(BuildContext context) {
    final canMakeNow = recipe.missedIngredientCount == 0;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecipeDetailsScreen(recipe: recipe),
          ),
        );
      },
      child: Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: canMakeNow ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: recipe.image.isEmpty
                  ? Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF5A4B3A), Color(0xFF2F2520)],
                        ),
                      ),
                      child: const Icon(
                        Icons.restaurant,
                        color: Color(0xFFFFD89B),
                        size: 42,
                      ),
                    )
                  : Image.network(
                      recipe.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF5A4B3A), Color(0xFF2F2520)],
                            ),
                          ),
                          child: const Icon(
                            Icons.restaurant,
                            color: Color(0xFFFFD89B),
                            size: 42,
                          ),
                        );
                      },
                    ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.5),
                    ],
                    stops: const [0.0, 0.36, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.36),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFFFC54D), size: 12),
                    const SizedBox(width: 3),
                    Text(
                      recipe.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: onToggleFavorite,
                child: _RecipeFavoriteHeartButton(isFavorite: isFavorite),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (_hasMissingOrUsed) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _OverlayCountBadge(
                            text: '${recipe.usedIngredientCount} used',
                            color: const Color(0xFF9BEA7A),
                            icon: Icons.check_circle_rounded,
                          ),
                          _OverlayCountBadge(
                            text: '${recipe.missedIngredientCount} missing',
                            color: const Color(0xFFFFCF7A),
                            icon: Icons.add_circle_outline_rounded,
                          ),
                        ],
                      ),
                    ],
                    if (recipe.missedIngredients.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Missing: ${recipe.missedIngredients.take(2).join(', ')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 10.7,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _OverlayMiniInfo(
                          icon: Icons.schedule_rounded,
                          text: '${recipe.readyInMinutes} mins',
                        ),
                        const SizedBox(width: 8),
                        _OverlayMiniInfo(
                          icon: Icons.local_fire_department_rounded,
                          text: recipe.calories > 0
                              ? '${recipe.calories} cal'
                              : '— cal',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayCountBadge extends StatelessWidget {
  const _OverlayCountBadge({
    required this.text,
    required this.color,
    required this.icon,
  });

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10.5, color: color),
          const SizedBox(width: 3.5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayMiniInfo extends StatelessWidget {
  const _OverlayMiniInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.92), size: 13.5),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 10.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeFavoriteHeartButton extends StatefulWidget {
  const _RecipeFavoriteHeartButton({required this.isFavorite});

  final bool isFavorite;

  @override
  State<_RecipeFavoriteHeartButton> createState() =>
      _RecipeFavoriteHeartButtonState();
}

class _RecipeFavoriteHeartButtonState extends State<_RecipeFavoriteHeartButton>
    with TickerProviderStateMixin {
  late final AnimationController _fillController;
  late final AnimationController _waveController;
  late final Animation<double> _fillAnimation;

  @override
  void initState() {
    super.initState();
    _fillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1650),
      reverseDuration: const Duration(milliseconds: 820),
      value: widget.isFavorite ? 1 : 0,
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    )..repeat();
    _fillAnimation = CurvedAnimation(
      parent: _fillController,
      curve: Curves.easeInOutCubicEmphasized,
      reverseCurve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant _RecipeFavoriteHeartButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFavorite == widget.isFavorite) return;
    if (widget.isFavorite) {
      _fillController.forward();
    } else {
      _fillController.reverse();
    }
  }

  @override
  void dispose() {
    _fillController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = Color.lerp(
      Colors.black.withValues(alpha: 0.55),
      const Color(0xFFE43D4E).withValues(alpha: 0.60),
      _fillAnimation.value,
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_fillAnimation, _waveController]),
      builder: (context, _) {
        final double value = _fillAnimation.value.clamp(0.0, 1.0).toDouble();
        final scale = 1 + (0.1 * value);
        final phase = _waveController.value * math.pi * 2;

        return Transform.scale(
          scale: scale,
          child: CircleAvatar(
            radius: 15,
            backgroundColor: Colors.white.withValues(alpha: 0.92),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 17,
                  height: 17,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (value > 0)
                        Icon(
                          Icons.favorite,
                          color: const Color(
                            0xFFE43D4E,
                          ).withValues(alpha: 0.12),
                          size: 17,
                        ),
                      ClipPath(
                        clipper: _RecipeWaveFillClipper(
                          fillLevel: value,
                          phase: phase,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Color(0xFFE43D4E),
                          size: 17,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.favorite_border, color: borderColor, size: 16.6),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RecipeWaveFillClipper extends CustomClipper<Path> {
  const _RecipeWaveFillClipper({required this.fillLevel, required this.phase});

  final double fillLevel;
  final double phase;

  @override
  Path getClip(Size size) {
    final clampedLevel = fillLevel.clamp(0.0, 1.0).toDouble();
    final waterTop = size.height * (1 - clampedLevel);
    final amplitude = 0.9 + (1.1 * (1 - clampedLevel));

    final path = Path()..moveTo(0, size.height);
    path.lineTo(0, waterTop);
    for (double x = 0; x <= size.width; x += 1) {
      final y =
          waterTop +
          math.sin((x / size.width * math.pi * 2) + phase) * amplitude;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _RecipeWaveFillClipper oldClipper) {
    return oldClipper.fillLevel != fillLevel || oldClipper.phase != phase;
  }
}

class _FilterSwitchTile extends StatelessWidget {
  const _FilterSwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2C9A4)),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF3A2214),
            fontWeight: FontWeight.w800,
          ),
        ),
        value: value,
        activeColor: const Color(0xFF75A843),
        onChanged: onChanged,
      ),
    );
  }
}

class _MissingSlider extends StatelessWidget {
  const _MissingSlider({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = value == 20 ? 'Any' : '$value';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2C9A4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Max missing ingredients: $label',
            style: const TextStyle(
              color: Color(0xFF3A2214),
              fontWeight: FontWeight.w800,
            ),
          ),
          Slider(
            value: value.toDouble(),
            min: 0,
            max: 20,
            divisions: 20,
            activeColor: const Color(0xFF75A843),
            inactiveColor: const Color(0xFFE2C9A4),
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }
}

class _ChoiceSection extends StatelessWidget {
  const _ChoiceSection({
    required this.title,
    required this.selected,
    required this.values,
    required this.onSelected,
  });

  final String title;
  final String selected;
  final List<String> values;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF3A2214),
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((value) {
            final isSelected = selected == value;

            return GestureDetector(
              onTap: () => onSelected(value),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEDF7E7) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF75A843)
                        : const Color(0xFFE2C9A4),
                  ),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF5C8E3E)
                        : const Color(0xFF5C5C66),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
