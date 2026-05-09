import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:culinary_coach_app/features/home/data/models/recipe_match.dart';

class FavoriteRecipesService {
  FavoriteRecipesService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _favoritesRef(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('favorite_recipes');
  }

  Stream<Set<int>> streamFavoriteRecipeIds(String userId) {
    return _favoritesRef(userId).snapshots().map((snapshot) {
      final ids = <int>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final parsed =
            _parseRecipeId(data['recipeId']) ?? _parseRecipeId(doc.id);
        if (parsed != null && parsed > 0) {
          ids.add(parsed);
        }
      }
      return ids;
    });
  }

  Future<void> saveFavoriteRecipe({
    required String userId,
    required RecipeMatch recipe,
  }) async {
    if (recipe.id <= 0) return;

    await _favoritesRef(userId).doc('${recipe.id}').set({
      'recipeId': recipe.id,
      'title': recipe.title,
      'image': recipe.image,
      'usedIngredientCount': recipe.usedIngredientCount,
      'missedIngredientCount': recipe.missedIngredientCount,
      'rating': recipe.rating,
      'readyInMinutes': recipe.readyInMinutes,
      'servings': recipe.servings,
      'calories': recipe.calories,
      'summary': recipe.summary,
      'usedIngredients': recipe.usedIngredients,
      'missedIngredients': recipe.missedIngredients,
      'unusedIngredients': recipe.unusedIngredients,
      'instructions': recipe.instructions,
      'savedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeFavoriteRecipe({
    required String userId,
    required int recipeId,
  }) async {
    if (recipeId <= 0) return;
    await _favoritesRef(userId).doc('$recipeId').delete();
  }

  int? _parseRecipeId(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }
}
