// lib/features/home/presentation/screens/recipe_details_screen.dart

import 'dart:convert';
import 'dart:math' as math;

import 'package:culinary_coach_app/app/shell/presentation/screens/main_shell_screen.dart';
import 'package:culinary_coach_app/features/filter/data/models/ingredient_model.dart';
import 'package:culinary_coach_app/features/filter/data/services/ingredient_service.dart';
import 'package:culinary_coach_app/features/home/data/models/recipe_match.dart';
import 'package:culinary_coach_app/features/home/data/services/favorite_recipes_service.dart';
import 'package:culinary_coach_app/features/home/data/services/history_recipes_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RecipeDetailsScreen extends StatefulWidget {
  const RecipeDetailsScreen({super.key, required this.recipe});

  final RecipeMatch recipe;

  @override
  State<RecipeDetailsScreen> createState() => _RecipeDetailsScreenState();
}

class _RecipeDetailsScreenState extends State<RecipeDetailsScreen> {
  static const String _spoonacularKey = String.fromEnvironment(
    'SPOONACULAR_API_KEY',
  );
  final FavoriteRecipesService _favoriteRecipesService =
      FavoriteRecipesService();
  final HistoryRecipesService _historyRecipesService = HistoryRecipesService();
  final IngredientService _ingredientService = IngredientService();

  late RecipeMatch _recipe;
  bool _isLoading = false;
  bool _isSavingToHistory = false;
  final Map<int, bool> _favoriteOverrides = <int, bool>{};
  int _servings = 0;
  bool _showFullDescription = false;
  bool _ingredientsExpanded = true;
  bool _directionExpanded = true;
  final Map<String, double> _ingredientMultipliers = <String, double>{};
  final Set<String> _selectedMissingIngredientKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
    _servings = _recipe.servings > 0 ? _recipe.servings : 2;
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    if (_spoonacularKey.isEmpty || _recipe.id == 0) return;
    setState(() => _isLoading = true);

    try {
      final uri = Uri.https(
        'api.spoonacular.com',
        '/recipes/${_recipe.id}/information',
        {'includeNutrition': 'false', 'apiKey': _spoonacularKey},
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _recipe = _recipe.copyWithDetails(decoded);
        if (_servings <= 0) {
          _servings = _recipe.servings > 0 ? _recipe.servings : 2;
        }
      });
    } catch (_) {
      // Keep the basic card data if details fail.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavoriteRecipe({
    required String userId,
    required bool isFavorite,
  }) async {
    if (_recipe.id <= 0) return;
    final nextValue = !isFavorite;
    setState(() => _favoriteOverrides[_recipe.id] = nextValue);

    try {
      if (nextValue) {
        await _favoriteRecipesService.saveFavoriteRecipe(
          userId: userId,
          recipe: _recipe,
        );
      } else {
        await _favoriteRecipesService.removeFavoriteRecipe(
          userId: userId,
          recipeId: _recipe.id,
        );
      }
      if (!mounted) return;
      setState(() => _favoriteOverrides.remove(_recipe.id));
    } catch (_) {
      if (!mounted) return;
      setState(() => _favoriteOverrides.remove(_recipe.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not update favorites right now. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> _saveRecipeToHistory(String userId) async {
    if (_recipe.id <= 0 || _isSavingToHistory) return;
    setState(() => _isSavingToHistory = true);
    try {
      await _historyRecipesService.saveHistoryRecipe(
        userId: userId,
        recipe: _recipe,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Recipe saved to history.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save recipe history right now.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingToHistory = false);
      }
    }
  }

  String _normalizeIngredientText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _missingIngredientNames() {
    final seen = <String>{};
    final values = <String>[];
    for (final item in _recipe.missedIngredients) {
      final name = item.trim();
      if (name.isEmpty) continue;
      final key = _normalizeIngredientText(name);
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      values.add(name);
    }
    return values;
  }

  Map<String, RecipeIngredient> _missingIngredientDetailsByKey() {
    final byKey = <String, RecipeIngredient>{};
    if (_recipe.ingredientDetails.isEmpty) return byKey;
    final missingKeys = _missingIngredientNames()
        .map(_normalizeIngredientText)
        .where((e) => e.isNotEmpty)
        .toSet();

    for (final detail in _recipe.ingredientDetails) {
      final detailKey = _normalizeIngredientText(detail.name);
      if (detailKey.isEmpty) continue;
      if (missingKeys.contains(detailKey)) {
        byKey[detailKey] = detail;
        continue;
      }
      for (final missingKey in missingKeys) {
        if (missingKey.contains(detailKey) || detailKey.contains(missingKey)) {
          byKey.putIfAbsent(missingKey, () => detail);
        }
      }
    }
    return byKey;
  }

  void _syncMissingSelectionState(List<String> missingNames) {
    final missingKeys = missingNames
        .map(_normalizeIngredientText)
        .where((e) => e.isNotEmpty)
        .toSet();

    _selectedMissingIngredientKeys.removeWhere((k) => !missingKeys.contains(k));
    if (_selectedMissingIngredientKeys.isEmpty && missingKeys.isNotEmpty) {
      _selectedMissingIngredientKeys.addAll(missingKeys);
    }
  }

  void _toggleMissingIngredientSelection(String key) {
    setState(() {
      if (_selectedMissingIngredientKeys.contains(key)) {
        _selectedMissingIngredientKeys.remove(key);
      } else {
        _selectedMissingIngredientKeys.add(key);
      }
    });
  }

  IngredientModel? _bestIngredientMatch(
    String missingName,
    List<IngredientModel> allIngredients,
  ) {
    final missingNorm = _normalizeIngredientText(missingName);
    if (missingNorm.isEmpty) return null;

    IngredientModel? partial;
    for (final ingredient in allIngredients) {
      final nameNorm = _normalizeIngredientText(ingredient.name);
      if (nameNorm.isEmpty) continue;
      if (nameNorm == missingNorm) return ingredient;
      if (nameNorm.contains(missingNorm) || missingNorm.contains(nameNorm)) {
        partial ??= ingredient;
      }
    }
    return partial;
  }

  Future<void> _addMissingIngredientsToCart(String userId) async {
    final missing = _missingIngredientNames();
    if (missing.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No missing ingredients to add.')),
      );
      return;
    }
    final selectedMissing = missing.where((name) {
      final key = _normalizeIngredientText(name);
      return key.isNotEmpty && _selectedMissingIngredientKeys.contains(key);
    }).toList();
    if (selectedMissing.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one missing ingredient.'),
        ),
      );
      return;
    }

    try {
      final allIngredients = await _ingredientService.getAllIngredients().first;
      final detailByKey = _missingIngredientDetailsByKey();
      int addedCount = 0;

      for (final missingName in selectedMissing) {
        final missingKey = _normalizeIngredientText(missingName);
        final match = _bestIngredientMatch(missingName, allIngredients);
        if (match == null) continue;
        final detail = detailByKey[missingKey];
        final scaledAmount = detail?.amount == null
            ? 1.0
            : (detail!.amount! * _servingScaleFactor()).clamp(0.1, 100.0);
        await _ingredientService.saveUserShopCartItem(
          userId: userId,
          ingredient: match,
          quantity: scaledAmount.toDouble(),
        );
        addedCount++;
      }

      if (!mounted) return;
      if (addedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not match missing ingredients in cart database.',
            ),
          ),
        );
      } else if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _AnimatedSuccessCheckmark(),
                    const SizedBox(height: 10),
                    const Text(
                      'Added to cart',
                      style: TextStyle(
                        color: Color(0xFF1F1B16),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$addedCount ingredient(s) are added to cart successfully.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF6D6558),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFFD8CBB6),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Continue',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MainShellScreen(
                                      initialIndex: 3,
                                      openShopCartOnStart: true,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFCB871F),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'View cart',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add missing ingredients. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<Set<int>>(
      stream: currentUserId == null
          ? null
          : _favoriteRecipesService.streamFavoriteRecipeIds(currentUserId),
      initialData: const <int>{},
      builder: (context, snapshot) {
        final favoriteIds = Set<int>.from(snapshot.data ?? const <int>{});
        final effectiveFavoriteIds = <int>{...favoriteIds};
        _favoriteOverrides.forEach((recipeId, value) {
          if (value) {
            effectiveFavoriteIds.add(recipeId);
          } else {
            effectiveFavoriteIds.remove(recipeId);
          }
        });
        final isFavorite = effectiveFavoriteIds.contains(_recipe.id);
        final descriptionText = _recipe.summary.isNotEmpty
            ? _recipe.summary
            : 'A delicious recipe selected for you. Check the ingredients and follow the directions below.';
        final difficultyText = _recipe.difficulty?.trim();
        final hasDifficulty =
            difficultyText != null && difficultyText.isNotEmpty;
        final preparationMinutes = _recipe.preparationMinutes;
        final hasPreparation =
            preparationMinutes != null && preparationMinutes > 0;

        return Scaffold(
          backgroundColor: const Color(0xFFF6F3ED),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: SizedBox(
            width: 148,
            height: 40,
            child: ElevatedButton(
              onPressed: () {
                if (_isSavingToHistory) return;
                final userId = currentUserId;
                if (userId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please sign in to save recipe history.'),
                    ),
                  );
                  return;
                }
                _saveRecipeToHistory(userId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE1A441),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.restaurant_menu_rounded, size: 15),
                  const SizedBox(width: 6),
                  Text(
                    _isSavingToHistory ? 'saving...' : 'start coocking',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CircleIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Food Details',
                            style: TextStyle(
                              color: Color(0xFF1C1A17),
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      _CircleIconButton(
                        icon: Icons.edit_outlined,
                        onTap: () {},
                      ),
                      const SizedBox(width: 8),
                      _CircleIconButton(
                        icon: Icons.more_vert_rounded,
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _recipe.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1F1B16),
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _InfoText(
                        icon: Icons.access_time_rounded,
                        text: '${_recipe.readyInMinutes} mins',
                      ),
                      if (hasDifficulty) ...[
                        const SizedBox(width: 10),
                        _InfoText(
                          icon: Icons.local_fire_department_outlined,
                          text: difficultyText,
                        ),
                      ],
                      const SizedBox(width: 10),
                      _InfoText(
                        icon: Icons.whatshot_outlined,
                        text: _recipe.calories > 0
                            ? '${_recipe.calories} cal'
                            : '— cal',
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFF0B31A),
                        size: 17,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _recipe.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Color(0xFF6F6659),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        _recipe.image.isEmpty
                            ? Container(
                                height: 260,
                                width: double.infinity,
                                color: const Color(0xFFEDE2C8),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.restaurant,
                                  color: Color(0xFFB87313),
                                  size: 62,
                                ),
                              )
                            : Image.network(
                                _recipe.image,
                                height: 260,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: GestureDetector(
                            onTap: () {
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
                                isFavorite: isFavorite,
                              );
                            },
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.28),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                              child: _DetailsFavoriteHeartButton(
                                isFavorite: isFavorite,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Description',
                    style: TextStyle(
                      color: Color(0xFF2C2620),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    descriptionText,
                    maxLines: _showFullDescription ? 8 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF61584B),
                      height: 1.45,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () => setState(
                      () => _showFullDescription = !_showFullDescription,
                    ),
                    child: Text(
                      _showFullDescription ? 'Read less' : 'Read more',
                      style: const TextStyle(
                        color: Color(0xFFC7851F),
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EEE3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2D8C6)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ServingStatBox(
                            title: 'Servings',
                            trailing: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _SmallRoundAction(
                                  icon: Icons.remove,
                                  onTap: () => setState(() {
                                    if (_servings > 1) _servings--;
                                  }),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$_servings',
                                  style: const TextStyle(
                                    color: Color(0xFF2E2821),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _SmallRoundAction(
                                  icon: Icons.add,
                                  onTap: () => setState(() => _servings++),
                                  filled: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ServingStatBox(
                            title: 'Cook',
                            trailing: Text(
                              '${_recipe.readyInMinutes} mins',
                              style: const TextStyle(
                                color: Color(0xFF2E2821),
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        if (hasPreparation) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ServingStatBox(
                              title: 'Preparation',
                              trailing: Text(
                                '$preparationMinutes mins',
                                style: const TextStyle(
                                  color: Color(0xFF2E2821),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DetailPanel(
                    title: 'Ingredients',
                    expanded: _ingredientsExpanded,
                    onToggle: () => setState(
                      () => _ingredientsExpanded = !_ingredientsExpanded,
                    ),
                    child: _buildIngredientsAndMissingContent(currentUserId),
                  ),
                  const SizedBox(height: 10),
                  _DetailPanel(
                    title: 'Direction',
                    expanded: _directionExpanded,
                    onToggle: () => setState(
                      () => _directionExpanded = !_directionExpanded,
                    ),
                    child: _recipe.instructions.isEmpty
                        ? const Text(
                            'Detailed directions are not available for this recipe.',
                            style: TextStyle(
                              color: Color(0xFF6D6558),
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _recipe.instructions.asMap().entries.map((
                              entry,
                            ) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  '${entry.key + 1}. ${entry.value}',
                                  style: const TextStyle(
                                    color: Color(0xFF312B24),
                                    height: 1.32,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  if (_isLoading) ...[
                    const SizedBox(height: 16),
                    const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFB87313),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<String> _ingredientList() {
    final items = <String>{
      ..._recipe.usedIngredients,
      ..._recipe.missedIngredients,
      ..._recipe.unusedIngredients,
    };
    return items.toList();
  }

  List<String> _ingredientDisplayLines() {
    if (_recipe.ingredientDetails.isNotEmpty) {
      final lines = <String>[];
      final scale = _servingScaleFactor();
      for (final ingredient in _recipe.ingredientDetails) {
        final amountValue = ingredient.amount;
        final amountText = amountValue == null
            ? ''
            : '${_formatAmount(amountValue * scale)} ';
        final unitText = ingredient.unit.isEmpty ? '' : '${ingredient.unit} ';
        final line = '$amountText$unitText${ingredient.name}'.trim();
        if (line.isNotEmpty) lines.add(line);
      }
      if (lines.isNotEmpty) return lines;
    }
    return _ingredientList();
  }

  String _ingredientKey(RecipeIngredient ingredient) {
    return ingredient.name.trim().toLowerCase();
  }

  double _ingredientMultiplier(RecipeIngredient ingredient) {
    return _ingredientMultipliers[_ingredientKey(ingredient)] ?? 1;
  }

  void _increaseIngredientAmount(RecipeIngredient ingredient) {
    final key = _ingredientKey(ingredient);
    final current = _ingredientMultipliers[key] ?? 1;
    setState(() => _ingredientMultipliers[key] = current + 0.25);
  }

  void _decreaseIngredientAmount(RecipeIngredient ingredient) {
    final key = _ingredientKey(ingredient);
    final current = _ingredientMultipliers[key] ?? 1;
    final next = current - 0.25;
    if (next <= 0.25) {
      setState(() => _ingredientMultipliers[key] = 0.25);
      return;
    }
    setState(() => _ingredientMultipliers[key] = next);
  }

  void _resetIngredientQuantitiesToDefault() {
    setState(() {
      _ingredientMultipliers.clear();
      _servings = _recipe.servings > 0 ? _recipe.servings : 2;
    });
  }

  Widget _buildIngredientsContent() {
    final missingKeys = _missingIngredientNames()
        .map(_normalizeIngredientText)
        .where((e) => e.isNotEmpty)
        .toSet();

    if (_recipe.ingredientDetails.isNotEmpty) {
      final scale = _servingScaleFactor();
      final nonMissingDetails = _recipe.ingredientDetails.where((ingredient) {
        final key = _normalizeIngredientText(ingredient.name);
        if (key.isEmpty) return false;
        for (final missing in missingKeys) {
          if (key == missing ||
              key.contains(missing) ||
              missing.contains(key)) {
            return false;
          }
        }
        return true;
      }).toList();
      if (nonMissingDetails.isEmpty) {
        return const Text(
          'All ingredients needed are listed in Missing ingredients below.',
          style: TextStyle(
            color: Color(0xFF6D6558),
            fontWeight: FontWeight.w600,
          ),
        );
      }

      return Column(
        children: nonMissingDetails.map((ingredient) {
          final amount = ingredient.amount;
          final multiplier = _ingredientMultiplier(ingredient);
          final effectiveAmount = amount == null
              ? null
              : (amount * scale * multiplier);
          final amountText = effectiveAmount == null
              ? '—'
              : _formatAmount(effectiveAmount);
          final unitText = ingredient.unit.isEmpty ? '' : ' ${ingredient.unit}';
          final hasAmount = effectiveAmount != null;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F3E8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2D8C6)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ingredient.name,
                        style: const TextStyle(
                          color: Color(0xFF2F2821),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasAmount
                            ? '$amountText$unitText'
                            : 'Quantity unavailable',
                        style: const TextStyle(
                          color: Color(0xFF7A705F),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasAmount)
                  Row(
                    children: [
                      _SmallRoundAction(
                        icon: Icons.remove,
                        onTap: () => _decreaseIngredientAmount(ingredient),
                      ),
                      const SizedBox(width: 8),
                      _SmallRoundAction(
                        icon: Icons.add,
                        onTap: () => _increaseIngredientAmount(ingredient),
                        filled: true,
                      ),
                    ],
                  ),
              ],
            ),
          );
        }).toList(),
      );
    }

    if (_ingredientDisplayLines().isNotEmpty) {
      final filteredLines = _ingredientDisplayLines().where((line) {
        final key = _normalizeIngredientText(line);
        if (key.isEmpty) return false;
        for (final missing in missingKeys) {
          if (key.contains(missing) || missing.contains(key)) return false;
        }
        return true;
      }).toList();
      if (filteredLines.isEmpty) {
        return const Text(
          'All ingredients needed are listed in Missing ingredients below.',
          style: TextStyle(
            color: Color(0xFF6D6558),
            fontWeight: FontWeight.w600,
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: filteredLines
            .map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• $e',
                  style: const TextStyle(
                    color: Color(0xFF312B24),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            .toList(),
      );
    }

    return const Text(
      'No ingredients available.',
      style: TextStyle(color: Color(0xFF6D6558), fontWeight: FontWeight.w600),
    );
  }

  Widget _buildIngredientsAndMissingContent(String? currentUserId) {
    final missing = _missingIngredientNames();
    _syncMissingSelectionState(missing);
    final detailByKey = _missingIngredientDetailsByKey();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _resetIngredientQuantitiesToDefault,
            icon: const Icon(Icons.restart_alt_rounded, size: 15),
            label: const Text('Reset Quantities'),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF5C5143),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: const BorderSide(color: Color(0xFFDCCFB8)),
              textStyle: const TextStyle(
                fontSize: 11.8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildIngredientsContent(),
        if (missing.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(height: 1, color: const Color(0xFFE2D8C6)),
          const SizedBox(height: 10),
          const Text(
            'Missing ingredients',
            style: TextStyle(
              color: Color(0xFF2F2922),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: missing.map((name) {
              final key = _normalizeIngredientText(name);
              final detail = detailByKey[key];
              final hasAmount = detail?.amount != null;
              final effectiveAmount = hasAmount
                  ? (detail!.amount! * _servingScaleFactor()).clamp(0.1, 100.0)
                  : null;
              final amountText = effectiveAmount == null
                  ? 'Quantity unavailable'
                  : '${_formatAmount(effectiveAmount.toDouble())}${detail!.unit.isEmpty ? '' : ' ${detail.unit}'}';
              final isSelected = _selectedMissingIngredientKeys.contains(key);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBE8DA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE3BE9F)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Color(0xFF2F2821),
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            amountText,
                            style: const TextStyle(
                              color: Color(0xFF7A705F),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: key.isEmpty
                          ? null
                          : () => _toggleMissingIngredientSelection(key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFCB871F)
                              : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFCB871F)
                                : const Color(0xFFCEC1AA),
                          ),
                        ),
                        child: Icon(
                          Icons.check,
                          size: 15,
                          color: isSelected ? Colors.white : Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: 118,
              height: 34,
              child: ElevatedButton(
                onPressed: () {
                  if (currentUserId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please sign in to add ingredients to cart.',
                        ),
                      ),
                    );
                    return;
                  }
                  _addMissingIngredientsToCart(currentUserId);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE1A441),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'add to cart',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  double _servingScaleFactor() {
    final baseServings = _recipe.servings > 0 ? _recipe.servings : _servings;
    if (baseServings <= 0) return 1;
    return _servings / baseServings;
  }

  String _formatAmount(double value) {
    final roundedInt = value.roundToDouble();
    if ((value - roundedInt).abs() < 0.01) return roundedInt.toInt().toString();

    final rounded1 = (value * 10).round() / 10;
    if ((rounded1 - rounded1.roundToDouble()).abs() < 0.01) {
      return rounded1.toInt().toString();
    }
    return rounded1.toStringAsFixed(1);
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF3A2214), size: 19),
      ),
    );
  }
}

class _AnimatedSuccessCheckmark extends StatelessWidget {
  const _AnimatedSuccessCheckmark();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (context, value, _) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFE9F8EC).withValues(alpha: 0.95),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF9FD7A8)),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF3A9B52),
              size: 32,
            ),
          ),
        );
      },
    );
  }
}

class _SmallRoundAction extends StatelessWidget {
  const _SmallRoundAction({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF2A261F) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: filled ? const Color(0xFF2A261F) : const Color(0xFFCEC1AA),
          ),
        ),
        child: Icon(
          icon,
          size: 14,
          color: filled ? Colors.white : const Color(0xFF5E5548),
        ),
      ),
    );
  }
}

class _ServingStatBox extends StatelessWidget {
  const _ServingStatBox({required this.title, required this.trailing});

  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF6E6558),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        trailing,
      ],
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEE3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2D8C6)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF2C2620),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF7A705F),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: child,
            ),
        ],
      ),
    );
  }
}

class _DetailsFavoriteHeartButton extends StatefulWidget {
  const _DetailsFavoriteHeartButton({required this.isFavorite});

  final bool isFavorite;

  @override
  State<_DetailsFavoriteHeartButton> createState() =>
      _DetailsFavoriteHeartButtonState();
}

class _DetailsFavoriteHeartButtonState
    extends State<_DetailsFavoriteHeartButton>
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
  void didUpdateWidget(covariant _DetailsFavoriteHeartButton oldWidget) {
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
      const Color(0xFF3A2214).withValues(alpha: 0.7),
      const Color(0xFFE43D4E),
      _fillAnimation.value,
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_fillAnimation, _waveController]),
      builder: (context, _) {
        final double value = _fillAnimation.value.clamp(0.0, 1.0).toDouble();
        final phase = _waveController.value * math.pi * 2;

        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (value > 0)
                    Icon(
                      Icons.favorite,
                      color: const Color(0xFFE43D4E).withValues(alpha: 0.12),
                      size: 18,
                    ),
                  ClipPath(
                    clipper: _DetailsWaveFillClipper(
                      fillLevel: value,
                      phase: phase,
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: Color(0xFFE43D4E),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.favorite_border_rounded, color: borderColor, size: 19),
          ],
        );
      },
    );
  }
}

class _DetailsWaveFillClipper extends CustomClipper<Path> {
  const _DetailsWaveFillClipper({required this.fillLevel, required this.phase});

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
  bool shouldReclip(covariant _DetailsWaveFillClipper oldClipper) {
    return oldClipper.fillLevel != fillLevel || oldClipper.phase != phase;
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF8B7355), size: 16),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF8B7355),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFCF7E8),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF8B7355),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF3A2214),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandableInfo extends StatelessWidget {
  const _ExpandableInfo({
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFCF7E8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          title: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF3A2214),
              fontWeight: FontWeight.w900,
            ),
          ),
          iconColor: const Color(0xFFB87313),
          collapsedIconColor: const Color(0xFFB87313),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: children,
        ),
      ),
    );
  }
}
