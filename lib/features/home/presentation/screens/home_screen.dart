// lib/features/home/presentation/screens/home_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/core/widgets/current_user_avatar.dart';
import 'package:culinary_coach_app/features/filter/data/models/ingredient_model.dart';
import 'package:culinary_coach_app/features/filter/data/services/ingredient_service.dart';
import 'package:culinary_coach_app/features/filter/widgets/custom_image_cache.dart';
import 'package:culinary_coach_app/features/home/data/models/recipe_match.dart';
import 'package:culinary_coach_app/features/home/data/services/favorite_recipes_service.dart';
import 'package:culinary_coach_app/features/home/presentation/screens/recipe_details_screen.dart';
import 'package:culinary_coach_app/features/home/presentation/screens/recipe_list_screen.dart';
import 'package:culinary_coach_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:culinary_coach_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final IngredientService _ingredientService = IngredientService();
  final FavoriteRecipesService _favoriteRecipesService =
      FavoriteRecipesService();
  final TextEditingController _searchController = TextEditingController();

  static const String _spoonacularKey = String.fromEnvironment(
    'SPOONACULAR_API_KEY',
  );

  List<RecipeMatch> _matchedRecipes = [];
  List<RecipeMatch> _randomRecipes = [];
  bool _isLoadingMatches = false;
  bool _isLoadingRandom = false;
  String? _errorMessage;
  Timer? _searchDebounce;
  String _lastPantrySignature = '';
  final Map<int, bool> _favoriteOverrides = <int, bool>{};

  bool _missingOneOnly = false;
  int _maxMissingIngredients = 3;
  String _selectedMealType = 'Any';
  String _selectedCuisine = 'Any';
  String _selectedDiet = 'Any';
  String _selectedRecipeTime = 'Any';
  double _minRating = 0;
  String _selectedCategoryChip = 'See All';
  final List<String> _excludedIngredients = [];
  final List<String> _keyIngredients = [];

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String? _extractFirstName(String? displayName) {
    final value = (displayName ?? '').trim();
    if (value.isEmpty) return null;
    return value.split(RegExp(r'\s+')).first;
  }

  String _pantrySignature(List<SavedIngredientSelection> selections) {
    final ids = selections.map((e) => e.ingredient.id).toList()..sort();
    return ids.join('|');
  }

  String _normalizeIngredientText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _ingredientIsInPantry(String ingredientName, Set<String> pantryNames) {
    final normalizedIngredient = _normalizeIngredientText(ingredientName);
    if (normalizedIngredient.isEmpty) return false;

    return pantryNames.any((pantryName) {
      final normalizedPantry = _normalizeIngredientText(pantryName);
      if (normalizedPantry.isEmpty) return false;
      return normalizedIngredient == normalizedPantry ||
          normalizedIngredient.contains(normalizedPantry) ||
          normalizedPantry.contains(normalizedIngredient);
    });
  }

  RecipeMatch _recipeWithPantryCounts(
    RecipeMatch recipe,
    List<SavedIngredientSelection> selections,
  ) {
    final pantryNames = selections.map((e) => e.ingredient.name).toSet();

    final ingredientPool = <String>{
      ...recipe.usedIngredients,
      ...recipe.missedIngredients,
      ...recipe.unusedIngredients,
    }.where((name) => name.trim().isNotEmpty).toList();

    if (ingredientPool.isEmpty || pantryNames.isEmpty) {
      return RecipeMatch(
        id: recipe.id,
        title: recipe.title,
        image: recipe.image,
        usedIngredientCount: pantryNames.isEmpty
            ? 0
            : recipe.usedIngredientCount,
        missedIngredientCount: pantryNames.isEmpty
            ? ingredientPool.length
            : recipe.missedIngredientCount,
        rating: recipe.rating,
        readyInMinutes: recipe.readyInMinutes,
        servings: recipe.servings,
        calories: recipe.calories,
        difficulty: recipe.difficulty,
        preparationMinutes: recipe.preparationMinutes,
        ingredientDetails: recipe.ingredientDetails,
        summary: recipe.summary,
        usedIngredients: pantryNames.isEmpty
            ? const []
            : recipe.usedIngredients,
        missedIngredients: pantryNames.isEmpty
            ? ingredientPool
            : recipe.missedIngredients,
        unusedIngredients: recipe.unusedIngredients,
        instructions: recipe.instructions,
      );
    }

    final used = <String>[];
    final missed = <String>[];

    for (final ingredient in ingredientPool) {
      if (_ingredientIsInPantry(ingredient, pantryNames)) {
        used.add(ingredient);
      } else {
        missed.add(ingredient);
      }
    }

    return RecipeMatch(
      id: recipe.id,
      title: recipe.title,
      image: recipe.image,
      usedIngredientCount: used.length,
      missedIngredientCount: missed.length,
      rating: recipe.rating,
      readyInMinutes: recipe.readyInMinutes,
      servings: recipe.servings,
      calories: recipe.calories,
      difficulty: recipe.difficulty,
      preparationMinutes: recipe.preparationMinutes,
      ingredientDetails: recipe.ingredientDetails,
      summary: recipe.summary,
      usedIngredients: used,
      missedIngredients: missed,
      unusedIngredients: recipe.unusedIngredients,
      instructions: recipe.instructions,
    );
  }

  List<RecipeMatch> _recipesWithPantryCounts(
    List<RecipeMatch> recipes,
    List<SavedIngredientSelection> selections,
  ) {
    return recipes
        .map((recipe) => _recipeWithPantryCounts(recipe, selections))
        .toList();
  }

  String _formatApiError(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      return 'Spoonacular key problem. Check that the API key is valid and passed with --dart-define.';
    }
    if (response.statusCode == 402) {
      return 'Spoonacular daily quota is finished. Try again later or use another API key.';
    }
    return 'Could not load recipes. API error ${response.statusCode}.';
  }

  void _applyRecipeApiFilters(Map<String, String> params) {
    if (_selectedMealType != 'Any')
      params['type'] = _selectedMealType.toLowerCase();
    if (_selectedCuisine != 'Any') params['cuisine'] = _selectedCuisine;
    if (_selectedDiet != 'Any') {
      params['diet'] = _selectedDiet == 'Healthy' ? 'whole30' : _selectedDiet;
    }
    final maxTime = _maxReadyTimeFromFilter();
    if (maxTime != null) params['maxReadyTime'] = '$maxTime';
  }

  int? _maxReadyTimeFromFilter() {
    if (_selectedRecipeTime == 'Under 15 min') return 15;
    if (_selectedRecipeTime == 'Under 30 min') return 30;
    if (_selectedRecipeTime == 'Under 60 min') return 60;
    return null;
  }

  List<RecipeMatch> _sortHomeRecipes(List<RecipeMatch> recipes) {
    return recipes..sort((a, b) {
      final missingCompare = a.missedIngredientCount.compareTo(
        b.missedIngredientCount,
      );
      if (missingCompare != 0) return missingCompare;
      final usedCompare = b.usedIngredientCount.compareTo(
        a.usedIngredientCount,
      );
      if (usedCompare != 0) return usedCompare;
      final ratingCompare = b.rating.compareTo(a.rating);
      if (ratingCompare != 0) return ratingCompare;
      return a.readyInMinutes.compareTo(b.readyInMinutes);
    });
  }

  void _onSearchChanged(
    String value,
    List<SavedIngredientSelection> selections,
  ) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 550), () {
      if (mounted) _findMatchedRecipes(selections);
    });
  }

  Future<void> _refreshAll(List<SavedIngredientSelection> selections) async {
    await Future.wait([
      _findMatchedRecipes(selections),
      _loadRandomRecipes(force: true),
    ]);
  }

  Future<void> _loadRandomRecipes({bool force = false}) async {
    if (_spoonacularKey.isEmpty) return;
    if (!force && _randomRecipes.isNotEmpty) return;
    if (_isLoadingRandom) return;

    setState(() => _isLoadingRandom = true);

    try {
      final params = <String, String>{
        'number': '100',
        'offset': '${DateTime.now().millisecondsSinceEpoch % 900}',
        'addRecipeInformation': 'true',
        'fillIngredients': 'true',
        'addRecipeNutrition': 'true',
        'sort': 'random',
        'apiKey': _spoonacularKey,
      };
      _applyRecipeApiFilters(params);

      final uri = Uri.https(
        'api.spoonacular.com',
        '/recipes/complexSearch',
        params,
      );
      final response = await http.get(uri);
      if (response.statusCode != 200)
        throw Exception(_formatApiError(response));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final rawRecipes = decoded['results'];
      if (rawRecipes is! List) return;

      final loaded =
          rawRecipes
              .whereType<Map<String, dynamic>>()
              .map((item) => RecipeMatch.fromComplexSearchJson(item, const []))
              .where(_passesFilters)
              .toList()
            ..sort((a, b) {
              final ratingCompare = b.rating.compareTo(a.rating);
              if (ratingCompare != 0) return ratingCompare;
              return a.readyInMinutes.compareTo(b.readyInMinutes);
            });

      if (!mounted) return;
      setState(() => _randomRecipes = loaded);
    } catch (_) {
      // Keep home usable even if recommended recipes fail.
    } finally {
      if (mounted) setState(() => _isLoadingRandom = false);
    }
  }

  Future<void> _findMatchedRecipes(
    List<SavedIngredientSelection> selections,
  ) async {
    if (_spoonacularKey.isEmpty) {
      setState(
        () => _errorMessage =
            'Missing Spoonacular API key. Run with --dart-define=SPOONACULAR_API_KEY=YOUR_API_KEY',
      );
      return;
    }

    final searchQuery = _searchController.text.trim();
    final pantryIngredients = selections
        .map((e) => e.ingredient.name.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    final finalIngredients = {
      ...pantryIngredients,
      ..._keyIngredients.map((e) => e.toLowerCase()),
    }.toList();

    if (finalIngredients.isEmpty && searchQuery.isEmpty) {
      setState(() {
        _matchedRecipes = [];
        _errorMessage = null;
      });
      await _loadRandomRecipes(force: true);
      return;
    }

    setState(() {
      _isLoadingMatches = true;
      _errorMessage = null;
    });

    try {
      final loaded = searchQuery.isNotEmpty
          ? await _searchRecipesByName(
              query: searchQuery,
              pantryIngredients: pantryIngredients,
            )
          : await _findRecipesByIngredients(finalIngredients);
      final filtered = _sortHomeRecipes(loaded.where(_passesFilters).toList());

      if (!mounted) return;
      setState(() => _matchedRecipes = filtered);
      await _loadRandomRecipes(force: true);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoadingMatches = false);
    }
  }

  Future<List<RecipeMatch>> _findRecipesByIngredients(
    List<String> ingredients,
  ) async {
    final uri = Uri.https('api.spoonacular.com', '/recipes/findByIngredients', {
      'ingredients': ingredients.join(','),
      'number': '100',
      'ranking': '1',
      'ignorePantry': 'true',
      'apiKey': _spoonacularKey,
    });
    final response = await http.get(uri);
    if (response.statusCode != 200) throw Exception(_formatApiError(response));
    final decoded = jsonDecode(response.body) as List<dynamic>;
    final baseRecipes = decoded
        .whereType<Map<String, dynamic>>()
        .map(RecipeMatch.fromFindByIngredientsJson)
        .toList();

    return _loadBulkRecipeDetails(baseRecipes);
  }

  Future<List<RecipeMatch>> _loadBulkRecipeDetails(
    List<RecipeMatch> recipes,
  ) async {
    final ids = recipes
        .map((recipe) => recipe.id)
        .where((id) => id > 0)
        .toList();
    if (ids.isEmpty) return recipes;

    final detailsById = <int, RecipeMatch>{};
    for (var start = 0; start < ids.length; start += 50) {
      final batchIds = ids.skip(start).take(50).join(',');
      final uri = Uri.https('api.spoonacular.com', '/recipes/informationBulk', {
        'ids': batchIds,
        'includeNutrition': 'true',
        'apiKey': _spoonacularKey,
      });
      final response = await http.get(uri);
      if (response.statusCode != 200)
        throw Exception(_formatApiError(response));

      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        for (final item in decoded.whereType<Map<String, dynamic>>()) {
          final detailed = RecipeMatch.fromRandomJson(item);
          detailsById[detailed.id] = detailed;
        }
      }
    }

    return recipes.map((recipe) {
      final detailed = detailsById[recipe.id];
      return detailed == null ? recipe : recipe.mergeDetails(detailed);
    }).toList();
  }

  Future<List<RecipeMatch>> _searchRecipesByName({
    required String query,
    required List<String> pantryIngredients,
  }) async {
    final params = <String, String>{
      'query': query,
      'number': '100',
      'addRecipeInformation': 'true',
      'fillIngredients': 'true',
      'addRecipeNutrition': 'true',
      'apiKey': _spoonacularKey,
    };
    if (pantryIngredients.isNotEmpty) {
      params['includeIngredients'] = pantryIngredients.join(',');
      params['sort'] = 'max-used-ingredients';
    }
    _applyRecipeApiFilters(params);

    final uri = Uri.https(
      'api.spoonacular.com',
      '/recipes/complexSearch',
      params,
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) throw Exception(_formatApiError(response));
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final results = decoded['results'];
    if (results is! List) return [];
    return results
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => RecipeMatch.fromComplexSearchJson(item, pantryIngredients),
        )
        .toList();
  }

  bool _passesFilters(RecipeMatch recipe) {
    final allText = [
      recipe.title,
      ...recipe.usedIngredients,
      ...recipe.missedIngredients,
      ...recipe.unusedIngredients,
    ].join(' ').toLowerCase();

    for (final keyIngredient in _keyIngredients) {
      if (!allText.contains(keyIngredient.toLowerCase())) return false;
    }
    for (final excluded in _excludedIngredients) {
      if (allText.contains(excluded.toLowerCase())) return false;
    }

    if (_missingOneOnly && recipe.missedIngredientCount != 1) return false;
    if (recipe.missedIngredientCount > _maxMissingIngredients) return false;

    final maxTime = _maxReadyTimeFromFilter();
    if (maxTime != null &&
        recipe.readyInMinutes > 0 &&
        recipe.readyInMinutes > maxTime) {
      return false;
    }

    if (_minRating > 0 && recipe.rating < _minRating) return false;
    return true;
  }

  int get _activeFilterCount {
    int count = 0;
    if (_missingOneOnly) count++;
    if (_maxMissingIngredients != 3) count++;
    if (_selectedMealType != 'Any') count++;
    if (_selectedCuisine != 'Any') count++;
    if (_selectedDiet != 'Any') count++;
    if (_selectedRecipeTime != 'Any') count++;
    if (_minRating > 0) count++;
    if (_excludedIngredients.isNotEmpty) count++;
    if (_keyIngredients.isNotEmpty) count++;
    return count;
  }

  Future<void> _addSuggestionToPantry({
    required String userId,
    required IngredientModel ingredient,
  }) async {
    await _ingredientService.saveUserSelectedIngredient(
      userId: userId,
      ingredient: ingredient,
      quantity: 1.0,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${ingredient.name} added to your pantry'),
        backgroundColor: const Color(0xFF6FA04D),
      ),
    );
  }

  Future<void> _removeFromPantry({
    required String userId,
    required String ingredientId,
  }) async {
    await _ingredientService.deleteUserSelectedIngredient(
      userId: userId,
      ingredientId: ingredientId,
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

  Widget _buildPantryIngredientImage(IngredientModel ingredient, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CustomCachedImage(
        imageUrl: ingredient.imageUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholder: Center(
          child: SizedBox(
            width: size * 0.35,
            height: size * 0.35,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB87313)),
            ),
          ),
        ),
        errorWidget: Icon(
          Icons.restaurant_rounded,
          size: size * 0.52,
          color: const Color(0xFFB87313),
        ),
      ),
    );
  }

  void _showPantrySheet({
    required String userId,
    required List<SavedIngredientSelection> selectedIngredients,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StreamBuilder<List<SavedIngredientSelection>>(
          stream: _ingredientService.streamUserSelectedIngredients(userId),
          initialData: selectedIngredients,
          builder: (context, snapshot) {
            final currentItems =
                snapshot.data ?? const <SavedIngredientSelection>[];
            final isDarkMode = Theme.of(context).brightness == Brightness.dark;
            final dialogBg = isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFFCF7E8);
            final cardBg = isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;
            final tilePreviewBg = isDarkMode ? const Color(0xFF1F1F1F) : const Color(0xFFF7F1DE);
            final primaryText = isDarkMode ? const Color(0xFFF2F2F2) : const Color(0xFF3A2214);
            final secondaryText = isDarkMode ? const Color(0xFFBEBEBE) : const Color(0xFF8B7355);
            final borderColor = isDarkMode ? const Color(0xFF3A3A3A) : const Color(0xFFE2C9A4);
            final statCardBg = isDarkMode
                ? const Color(0xFFB87313).withValues(alpha: 0.2)
                : const Color(0xFFD99622).withValues(alpha: 0.12);

            return Dialog(
              backgroundColor: dialogBg,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                padding: const EdgeInsets.all(18),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.82,
                  maxWidth: 460,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Your Pantry',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: primaryText,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFFB87313),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statCardBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total selected',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: primaryText,
                            ),
                          ),
                          Text(
                            '${currentItems.length}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB87313),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (currentItems.isEmpty)
                      Flexible(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 36),
                            child: Text(
                              'Your pantry is empty.',
                              style: TextStyle(
                                color: secondaryText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: currentItems.length,
                          itemBuilder: (context, index) {
                            final ingredient = currentItems[index].ingredient;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: borderColor,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: tilePreviewBg,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: _buildPantryIngredientImage(
                                      ingredient,
                                      52,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ingredient.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: primaryText,
                                          ),
                                        ),
                                        Text(
                                          ingredient.category,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: secondaryText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _removeFromPantry(
                                      userId: userId,
                                      ingredientId: ingredient.id,
                                    ),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: currentItems.isEmpty
                                ? null
                                : () async {
                              await _ingredientService
                                  .clearUserSelectedIngredients(userId);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFB87313),
                              side: const BorderSide(color: Color(0xFFB87313)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Text('Clear All'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              _findMatchedRecipes(currentItems);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB87313),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Text(
                              'Search',
                              style: TextStyle(color: Colors.white),
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
      },
    );
  }

  void _openFilterSheet(List<SavedIngredientSelection> selectedIngredients) {
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
              _findMatchedRecipes(selectedIngredients);
              _loadRandomRecipes(force: true);
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
                              'Recipe Filters',
                              style: TextStyle(
                                color: Color(0xFF3A2214),
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _missingOneOnly = false;
                                _maxMissingIngredients = 3;
                                _selectedMealType = 'Any';
                                _selectedCuisine = 'Any';
                                _selectedDiet = 'Any';
                                _selectedRecipeTime = 'Any';
                                _minRating = 0;
                                _excludedIngredients.clear();
                                _keyIngredients.clear();
                              });
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
                      const SizedBox(height: 14),
                      _BottomSwitchTile(
                        title: 'Missing one ingredient only',
                        value: _missingOneOnly,
                        onChanged: (value) {
                          _missingOneOnly = value;
                          refresh();
                        },
                      ),
                      const SizedBox(height: 10),
                      _BottomSliderTile(
                        title: 'Max missing ingredients',
                        value: _maxMissingIngredients,
                        onChanged: (value) {
                          _maxMissingIngredients = value;
                          refresh();
                        },
                      ),
                      const SizedBox(height: 16),
                      _BottomChoiceSection(
                        title: 'Meal type',
                        selected: _selectedMealType,
                        values: const [
                          'Any',
                          'Breakfast',
                          'Lunch',
                          'Dinner',
                          'Snack',
                          'Dessert',
                        ],
                        onSelected: (value) {
                          _selectedMealType = value;
                          refresh();
                        },
                      ),
                      const SizedBox(height: 16),
                      _BottomChoiceSection(
                        title: 'Cuisines',
                        selected: _selectedCuisine,
                        values: const [
                          'Any',
                          'Italian',
                          'Mediterranean',
                          'Asian',
                          'Mexican',
                          'Middle Eastern',
                        ],
                        onSelected: (value) {
                          _selectedCuisine = value;
                          refresh();
                        },
                      ),
                      const SizedBox(height: 16),
                      _BottomChoiceSection(
                        title: 'Diet',
                        selected: _selectedDiet,
                        values: const [
                          'Any',
                          'Vegetarian',
                          'Vegan',
                          'Gluten Free',
                          'Healthy',
                        ],
                        onSelected: (value) {
                          _selectedDiet = value;
                          refresh();
                        },
                      ),
                      const SizedBox(height: 16),
                      _BottomChoiceSection(
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
                      const SizedBox(height: 16),
                      _BottomChoiceSection(
                        title: 'Rating',
                        selected: _minRating > 0 ? '4+ Stars' : 'Any',
                        values: const ['Any', '4+ Stars'],
                        onSelected: (value) {
                          _minRating = value == '4+ Stars' ? 4.0 : 0;
                          refresh();
                        },
                      ),
                      const SizedBox(height: 16),
                      _IngredientDropdownSection(
                        title: 'Key Ingredient(s)',
                        values: _keyIngredients,
                        availableValues: selectedIngredients
                            .map((item) => item.ingredient.name)
                            .toList(),
                        emptyText: 'Add ingredients to your pantry first.',
                        onAdd: (value) {
                          if (!_keyIngredients.contains(value))
                            _keyIngredients.add(value);
                          refresh();
                        },
                        onRemove: (value) {
                          _keyIngredients.remove(value);
                          refresh();
                        },
                      ),
                      const SizedBox(height: 16),
                      _IngredientDropdownSection(
                        title: 'Exclude Ingredient(s)',
                        values: _excludedIngredients,
                        availableValues: selectedIngredients
                            .map((item) => item.ingredient.name)
                            .toList(),
                        emptyText: 'Add ingredients to your pantry first.',
                        onAdd: (value) {
                          if (!_excludedIngredients.contains(value))
                            _excludedIngredients.add(value);
                          refresh();
                        },
                        onRemove: (value) {
                          _excludedIngredients.remove(value);
                          refresh();
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _findMatchedRecipes(selectedIngredients);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB87313),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: const Text(
                            'Done',
                            style: TextStyle(fontWeight: FontWeight.w900),
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

  void _openSeeMore(String title, List<RecipeMatch> recipes) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeListScreen(title: title, recipes: recipes),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final fallbackName = _extractFirstName(currentUser?.displayName) ?? 'Chef';
    final scaffoldColor = Theme.of(context).scaffoldBackgroundColor;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: scaffoldColor,
        body: Center(
          child: Text(
            'Please sign in to find recipes from your ingredients.',
            style: TextStyle(
              color: isDarkMode ? const Color(0xFFE3E3E3) : const Color(0xFF3A2214),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        final data = userSnapshot.data?.data();
        final firstName = (data?['firstName'] as String?)?.trim();
        final resolvedName = firstName != null && firstName.isNotEmpty ? firstName : fallbackName;

        return StreamBuilder<List<SavedIngredientSelection>>(
          stream: _ingredientService.streamUserSelectedIngredients(
            currentUser.uid,
          ),
          builder: (context, selectedSnapshot) {
            final selectedIngredients = selectedSnapshot.data ?? [];
            final selectedIds = selectedIngredients
                .map((e) => e.ingredient.id)
                .toSet();
            final pantrySignature = _pantrySignature(selectedIngredients);

            if (selectedSnapshot.hasData &&
                pantrySignature != _lastPantrySignature) {
              _lastPantrySignature = pantrySignature;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _refreshAll(selectedIngredients);
              });
            } else if (selectedSnapshot.hasData &&
                _randomRecipes.isEmpty &&
                !_isLoadingRandom) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _loadRandomRecipes(force: true);
              });
            }

            return Scaffold(
              backgroundColor: scaffoldColor,
              body: Column(
                children: [
                  _HomeTopHero(
                    displayName: resolvedName,
                    searchController: _searchController,
                    pantryCount: selectedIngredients.length,
                    activeFilterCount: _activeFilterCount,
                    onSearchChanged: (value) => _onSearchChanged(value, selectedIngredients),
                    onSearchSubmitted: (_) => _findMatchedRecipes(selectedIngredients),
                    onPantryTap: () => _showPantrySheet(userId: currentUser.uid, selectedIngredients: selectedIngredients),
                    onProfileTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen())),
                    onSettingsTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
                    onFilterTap: () => _openFilterSheet(selectedIngredients),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: const Color(0xFFB87313),
                      onRefresh: () => _refreshAll(selectedIngredients),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            _PremiumCard(onTap: () {}),
                            const SizedBox(height: 16),
                            _CategoryChips(
                              selectedLabel: _selectedCategoryChip,
                              onTap: (label) {
                                setState(() {
                                  _selectedCategoryChip = label.isEmpty ? 'See All' : label;
                                  _selectedMealType = label.isEmpty ? 'Any' : label;
                                  _searchController.clear();
                                });
                                _findMatchedRecipes(selectedIngredients);
                                _loadRandomRecipes(force: true);
                              },
                            ),
                            const SizedBox(height: 16),
                            _DoYouHaveSection(
                              ingredientService: _ingredientService,
                              selectedIds: selectedIds,
                              onAddIngredient: (ingredient) => _addSuggestionToPantry(userId: currentUser.uid, ingredient: ingredient),
                            ),
                            if (_errorMessage != null)
                              Padding(padding: const EdgeInsets.fromLTRB(18, 16, 18, 0), child: _ErrorCard(message: _errorMessage!)),
                            const SizedBox(height: 18),
                            Builder(
                              builder: (context) {
                                final matchedWithCounts = _recipesWithPantryCounts(_matchedRecipes, selectedIngredients);
                                final randomWithCounts = _recipesWithPantryCounts(_randomRecipes, selectedIngredients);

                                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                  stream: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(currentUser.uid)
                                      .collection('favorite_recipes')
                                      .snapshots(),
                                  builder: (context, favoriteSnapshot) {
                                    final favoriteRecipeIds = <int>{};

                                    for (final doc in favoriteSnapshot.data?.docs ?? const []) {
                                      final data = doc.data();
                                      final recipeId = data['recipeId'];
                                      if (recipeId is int) {
                                        favoriteRecipeIds.add(recipeId);
                                      } else {
                                        final parsedId = int.tryParse(doc.id);
                                        if (parsedId != null) favoriteRecipeIds.add(parsedId);
                                      }
                                    }

                                    _favoriteOverrides.forEach((recipeId, isFavorite) {
                                      if (isFavorite) {
                                        favoriteRecipeIds.add(recipeId);
                                      } else {
                                        favoriteRecipeIds.remove(recipeId);
                                      }
                                    });

                                    return _HomeRecipeSections(
                                      matchedRecipes: matchedWithCounts,
                                      randomRecipes: randomWithCounts,
                                      favoriteRecipeIds: favoriteRecipeIds,
                                      isLoadingMatches: _isLoadingMatches,
                                      isLoadingRandom: _isLoadingRandom,
                                      onSeeMoreMatches: () => _openSeeMore('Recipe Matches', matchedWithCounts),
                                      onSeeMoreRandom: () => _openSeeMore('Recommended Recipe', randomWithCounts),
                                      onToggleFavorite: (recipe) => _toggleFavoriteRecipe(
                                        userId: currentUser.uid,
                                        recipe: recipe,
                                        isFavorite: favoriteRecipeIds.contains(recipe.id),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
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
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final isSmallHeight = size.height < 430;

    final horizontalPadding = isLandscape ? 28.0 : 18.0;
    final cardHeight = isLandscape ? (isSmallHeight ? 104.0 : 116.0) : 132.0;
    final titleSize = isLandscape ? 15.0 : 16.0;
    final descriptionSize = isLandscape ? 10.5 : 11.0;
    final buttonVerticalPadding = isLandscape ? 6.0 : 8.0;
    final buttonHorizontalPadding = isLandscape ? 12.0 : 13.0;
    final iconSize = isLandscape ? 50.0 : 58.0;
    final circleSize = isLandscape ? 116.0 : 132.0;
    final textRightPadding = isLandscape ? 124.0 : 138.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          height: cardHeight,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1F1B16), Color(0xFF31251B)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _PremiumPatternPainter()),
                ),
                Positioned(
                  right: -16,
                  bottom: -18,
                  child: Container(
                    width: circleSize,
                    height: circleSize,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0A73A).withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  right: isLandscape ? 26 : 22,
                  bottom: isLandscape ? 18 : 22,
                  child: Icon(
                    Icons.ramen_dining_rounded,
                    color: const Color(0xFFF0A73A),
                    size: iconSize,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    isLandscape ? 12 : 16,
                    textRightPadding,
                    isLandscape ? 12 : 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Go to premium now!',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFFF0A73A),
                          fontSize: titleSize,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Cook with the best recipes from around the world to your table.',
                        maxLines: isLandscape ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: descriptionSize,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: isLandscape ? 8 : 12),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: buttonHorizontalPadding,
                          vertical: buttonVerticalPadding,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0A73A),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Text(
                          'Start 7-day FREE Trial',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selectedLabel, required this.onTap});

  final String selectedLabel;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final categories = [
      ('See All', Icons.apps_rounded),
      ('Breakfast', Icons.free_breakfast_rounded),
      ('Lunch', Icons.lunch_dining_rounded),
      ('Snack', Icons.cookie_rounded),
      ('Dinner', Icons.dinner_dining_rounded),
    ];

    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final horizontalPadding = isLandscape ? 28.0 : 18.0;
    final chipHeight = isLandscape ? 34.0 : 38.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: SizedBox(
        height: chipHeight,
        width: double.infinity,
        child: isLandscape
            ? Row(
          children: [
            for (int index = 0; index < categories.length; index++) ...[
              Expanded(
                child: _CategoryChipButton(
                  label: categories[index].$1,
                  icon: categories[index].$2,
                  selected: selectedLabel == categories[index].$1,
                  onTap: () => onTap(
                    categories[index].$1 == 'See All'
                        ? ''
                        : categories[index].$1,
                  ),
                ),
              ),
              if (index != categories.length - 1) const SizedBox(width: 8),
            ],
          ],
        )
            : ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final item = categories[index];
            return _CategoryChipButton(
              label: item.$1,
              icon: item.$2,
              selected: selectedLabel == item.$1,
              onTap: () => onTap(item.$1 == 'See All' ? '' : item.$1),
            );
          },
        ),
      ),
    );
  }
}

class _CategoryChipButton extends StatelessWidget {
  const _CategoryChipButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: isLandscape ? 8 : 13),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0A73A) : const Color(0xFFFCF7E8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFFF0A73A) : const Color(0xFFE2C9A4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: isLandscape ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: isLandscape ? 14 : 15,
              color: selected ? Colors.white : const Color(0xFFB87313),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF8B7355),
                  fontSize: isLandscape ? 11.5 : 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeRecipeSections extends StatelessWidget {
  const _HomeRecipeSections({
    required this.matchedRecipes,
    required this.randomRecipes,
    required this.favoriteRecipeIds,
    required this.isLoadingMatches,
    required this.isLoadingRandom,
    required this.onSeeMoreMatches,
    required this.onSeeMoreRandom,
    required this.onToggleFavorite,
  });

  final List<RecipeMatch> matchedRecipes;
  final List<RecipeMatch> randomRecipes;
  final Set<int> favoriteRecipeIds;
  final bool isLoadingMatches;
  final bool isLoadingRandom;
  final VoidCallback onSeeMoreMatches;
  final VoidCallback onSeeMoreRandom;
  final ValueChanged<RecipeMatch> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (matchedRecipes.isNotEmpty || isLoadingMatches)
          _RecipeSection(
            title: 'Recipe Matches',
            recipes: matchedRecipes,
            favoriteRecipeIds: favoriteRecipeIds,
            isLoading: isLoadingMatches,
            onSeeMore: onSeeMoreMatches,
            onToggleFavorite: onToggleFavorite,
            large: true,
          ),
        if (matchedRecipes.isNotEmpty) const SizedBox(height: 18),
        _RecipeSection(
          title: 'Recommended Recipe',
          recipes: randomRecipes,
          favoriteRecipeIds: favoriteRecipeIds,
          isLoading: isLoadingRandom,
          onSeeMore: onSeeMoreRandom,
          onToggleFavorite: onToggleFavorite,
          large: false,
        ),
        const SizedBox(height: 120),
      ],
    );
  }
}

class _RecipeSection extends StatelessWidget {
  const _RecipeSection({
    required this.title,
    required this.recipes,
    required this.favoriteRecipeIds,
    required this.isLoading,
    required this.onSeeMore,
    required this.onToggleFavorite,
    required this.large,
  });
  final String title;
  final List<RecipeMatch> recipes;
  final Set<int> favoriteRecipeIds;
  final bool isLoading;
  final VoidCallback onSeeMore;
  final ValueChanged<RecipeMatch> onToggleFavorite;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    if (isLoading && recipes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 18),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFB87313)),
        ),
      );
    }
    if (recipes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDarkMode ? const Color(0xFFF2F2F2) : const Color(0xFF3A2214),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onSeeMore,
                child: const Text(
                  'See more',
                  style: TextStyle(
                    color: Color(0xFFB87313),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 264,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recipes.take(8).length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) => _RecipeCard(
                recipe: recipes[index],
                isFavorite: favoriteRecipeIds.contains(recipes[index].id),
                onToggleFavorite: () => onToggleFavorite(recipes[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.recipe,
    required this.isFavorite,
    required this.onToggleFavorite,
  });
  final RecipeMatch recipe;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final canMakeNow = recipe.missedIngredientCount == 0;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RecipeDetailsScreen(recipe: recipe)),
      ),
      child: Container(
        width: 190,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
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
                  size: 46,
                ),
              )
                  : Image.network(recipe.image, fit: BoxFit.cover),
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
                      Colors.black.withValues(alpha: 0.48),
                    ],
                    stops: const [0.0, 0.36, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 9,
              left: 9,
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
              top: 9,
              right: 9,
              child: GestureDetector(
                onTap: onToggleFavorite,
                child: _FavoriteHeartButton(isFavorite: isFavorite),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
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
                            fontSize: 13.2,
                            height: 1.12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _CountBadge(
                              text: '${recipe.usedIngredientCount} used',
                              color: const Color(0xFF9BEA7A),
                              icon: Icons.check_circle_rounded,
                            ),
                            _CountBadge(
                              text: '${recipe.missedIngredientCount} missing',
                              color: const Color(0xFFFFCF7A),
                              icon: Icons.add_circle_outline_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          recipe.missedIngredients.isEmpty
                              ? 'You have everything needed.'
                              : 'Missing: ${recipe.missedIngredients.take(3).join(', ')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 10.7,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.24),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            _MiniInfo(
                              icon: Icons.schedule_rounded,
                              text: '${recipe.readyInMinutes} mins',
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                            const SizedBox(width: 8),
                            _MiniInfo(
                              icon: Icons.local_fire_department_rounded,
                              text: recipe.calories > 0
                                  ? '${recipe.calories} cal'
                                  : '— cal',
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                          ],
                        ),
                      ],
                    ),
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

class _FavoriteHeartButton extends StatefulWidget {
  const _FavoriteHeartButton({required this.isFavorite});

  final bool isFavorite;

  @override
  State<_FavoriteHeartButton> createState() => _FavoriteHeartButtonState();
}

class _FavoriteHeartButtonState extends State<_FavoriteHeartButton>
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
  void didUpdateWidget(covariant _FavoriteHeartButton oldWidget) {
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
      const Color(0xFFE43D4E),
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
                        clipper: _WaveFillClipper(
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
                Icon(Icons.favorite_border, color: borderColor, size: 17),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WaveFillClipper extends CustomClipper<Path> {
  const _WaveFillClipper({required this.fillLevel, required this.phase});

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
  bool shouldReclip(covariant _WaveFillClipper oldClipper) {
    return oldClipper.fillLevel != fillLevel || oldClipper.phase != phase;
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({
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
            style: TextStyle(
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

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({
    required this.icon,
    required this.text,
    required this.color,
  });
  final IconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Row(
        children: [
          Icon(icon, color: color, size: 13.5),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
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

class _DoYouHaveSection extends StatelessWidget {
  const _DoYouHaveSection({
    required this.ingredientService,
    required this.selectedIds,
    required this.onAddIngredient,
  });
  final IngredientService ingredientService;
  final Set<String> selectedIds;
  final ValueChanged<IngredientModel> onAddIngredient;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<List<IngredientModel>>(
      stream: ingredientService.getAllIngredients(),
      builder: (context, snapshot) {
        final suggestions = (snapshot.data ?? [])
            .where((ingredient) => !selectedIds.contains(ingredient.id))
            .take(12)
            .toList();
        if (suggestions.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Do you have?',
                style: TextStyle(
                  color: isDarkMode
                      ? const Color(0xFFF2F2F2)
                      : const Color(0xFF4F4F59),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: suggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 9),
                  itemBuilder: (context, index) {
                    final ingredient = suggestions[index];
                    return GestureDetector(
                      onTap: () => onAddIngredient(ingredient),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCF7E8),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2C9A4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.add_rounded,
                              size: 15,
                              color: Color(0xFFB87313),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              ingredient.name,
                              style: const TextStyle(
                                color: Color(0xFF8B7355),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
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

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeTopHero extends StatelessWidget {
  const _HomeTopHero({
    required this.displayName,
    required this.searchController,
    required this.pantryCount,
    required this.activeFilterCount,
    required this.onPantryTap,
    required this.onProfileTap,
    required this.onSettingsTap,
    required this.onFilterTap,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
  });

  final String displayName;
  final TextEditingController searchController;
  final int pantryCount;
  final int activeFilterCount;
  final VoidCallback onPantryTap;
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onFilterTap;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final isCompact = isLandscape;
    final heroTitleSize = isCompact ? 16.0 : 23.0;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final heroGradient = isDarkMode
        ? const [Color(0xFF1A1A1A), Color(0xFF2D2D2D), Color(0xFF3D3D3D)]
        : const [Color(0xFFCC7705), Color(0xFFDD8E1E), Color(0xFFF0A73A)];
    final avatarBg = isDarkMode
        ? const Color(0xFF444444)
        : const Color(0xFFD28E18);
    final actionBg = isDarkMode ? const Color(0xFF444444) : Colors.white;
    final actionIconColor = isDarkMode
        ? Colors.white70
        : const Color(0xFF6C6C6C);
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
                  CurrentUserAvatar(
                    size: 40,
                    onTap: onProfileTap,
                    backgroundColor: avatarBg,
                    borderColor: Colors.white.withValues(alpha: 0.65),
                    borderWidth: 2,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (pantryCount > 0) ...[
                    _CircleActionButton(
                      icon: Icons.inventory_2_rounded,
                      onTap: onPantryTap,
                      badgeCount: pantryCount,
                      backgroundColor: actionBg,
                      iconColor: actionIconColor,
                    ),
                    const SizedBox(width: 10),
                  ],
                  _CircleActionButton(
                    icon: Icons.settings_outlined,
                    onTap: onSettingsTap,
                    backgroundColor: actionBg,
                    iconColor: actionIconColor,
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 6 : 26),
              Text(
                'What are we cooking today?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: heroTitleSize,
                  height: 1.15,
                ),
              ),
              SizedBox(height: isCompact ? 8 : 25),
              Container(
                height: isCompact ? 40 : 50,
                padding: const EdgeInsets.only(left: 16, right: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(27),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.12),
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
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        onChanged: onSearchChanged,
                        onSubmitted: onSearchSubmitted,
                        cursorColor: const Color(0xFF6A6A6A),
                        decoration: const InputDecoration(
                          hintText: 'Search',
                          hintStyle: TextStyle(
                            color: Color(0xFF9A9A9A),
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          isDense: true,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          onPressed: onFilterTap,
                          icon: const Icon(
                            Icons.tune_rounded,
                            color: Color(0xFF4D4D4D),
                            size: 24,
                          ),
                        ),
                        if (activeFilterCount > 0)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFFB87313),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                activeFilterCount > 9
                                    ? '9+'
                                    : '$activeFilterCount',
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
              SizedBox(height: isCompact ? 2 : 8),
            ],
          ),
        ],
      ),
    );
  }
}

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
              top: -4,
              right: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFB87313),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomSwitchTile extends StatelessWidget {
  const _BottomSwitchTile({
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

class _BottomSliderTile extends StatelessWidget {
  const _BottomSliderTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
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
            '$title: $value',
            style: const TextStyle(
              color: Color(0xFF3A2214),
              fontWeight: FontWeight.w800,
            ),
          ),
          Slider(
            value: value.toDouble(),
            min: 0,
            max: 5,
            divisions: 5,
            activeColor: const Color(0xFF75A843),
            inactiveColor: const Color(0xFFE2C9A4),
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }
}

class _BottomChoiceSection extends StatelessWidget {
  const _BottomChoiceSection({
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

class _IngredientDropdownSection extends StatelessWidget {
  const _IngredientDropdownSection({
    required this.title,
    required this.values,
    required this.availableValues,
    required this.emptyText,
    required this.onAdd,
    required this.onRemove,
  });

  final String title;
  final List<String> values;
  final List<String> availableValues;
  final String emptyText;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final normalizedSelected = values
        .map((item) => item.toLowerCase().trim())
        .toSet();
    final options =
    availableValues
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .where((item) => !normalizedSelected.contains(item.toLowerCase()))
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2C9A4)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: null,
              hint: Text(
                options.isEmpty ? emptyText : 'Choose from your pantry',
                style: const TextStyle(
                  color: Color(0xFF8B7355),
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFFB87313),
              ),
              items: options.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF3A2214),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
              onChanged: options.isEmpty
                  ? null
                  : (value) {
                      if (value == null || value.trim().isEmpty) return;
                      onAdd(value.trim());
                    },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((item) {
            return InputChip(
              label: Text(item),
              onDeleted: () => onRemove(item),
              backgroundColor: Colors.white,
              deleteIconColor: const Color(0xFFB87313),
              labelStyle: const TextStyle(
                color: Color(0xFF3A2214),
                fontWeight: FontWeight.w700,
              ),
            );
          }).toList(),
        ),
      ],
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
      ..color = Colors.white.withValues(alpha: 0.08)
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
      ..color = Colors.white.withValues(alpha: 0.05)
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

class _PremiumPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (double i = -size.height; i < size.width; i += 18) {
      canvas.drawLine(
        Offset(i, size.height),
        Offset(i + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
