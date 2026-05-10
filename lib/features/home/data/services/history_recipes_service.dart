import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:culinary_coach_app/features/home/data/models/recipe_match.dart';

class HistoryRecipesService {
  HistoryRecipesService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _historyRef(String userId) {
    return _firestore.collection('users').doc(userId).collection(
      'started_recipes',
    );
  }

  Future<void> saveHistoryRecipe({
    required String userId,
    required RecipeMatch recipe,
  }) async {
    if (recipe.id <= 0) return;

    await _historyRef(userId).doc('${recipe.id}').set({
      'recipeId': recipe.id,
      'title': recipe.title,
      'image': recipe.image,
      'usedIngredientCount': recipe.usedIngredientCount,
      'missedIngredientCount': recipe.missedIngredientCount,
      'rating': recipe.rating,
      'readyInMinutes': recipe.readyInMinutes,
      'servings': recipe.servings,
      'calories': recipe.calories,
      'difficulty': recipe.difficulty,
      'preparationMinutes': recipe.preparationMinutes,
      'summary': recipe.summary,
      'usedIngredients': recipe.usedIngredients,
      'missedIngredients': recipe.missedIngredients,
      'unusedIngredients': recipe.unusedIngredients,
      'instructions': recipe.instructions,
      'startedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
