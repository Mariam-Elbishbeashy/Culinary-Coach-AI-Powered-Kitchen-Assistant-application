import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:culinary_coach_app/features/home/data/models/recipe_match.dart';

class HistoryRecipesService {
  HistoryRecipesService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _historyRef(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('started_recipes');
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

  Future<void> saveCookingProgress({
    required String userId,
    required int recipeId,
    required int currentStep,
    required int totalSteps,
    required bool isCompleted,
    required bool exitedCookingScreen,
  }) async {
    if (recipeId <= 0) return;

    final safeTotal = totalSteps <= 0 ? 1 : totalSteps;
    final safeCurrent = currentStep.clamp(1, safeTotal);
    final progress = (safeCurrent / safeTotal).clamp(0.0, 1.0);

    final payload = <String, dynamic>{
      'cookingCurrentStep': safeCurrent,
      'cookingTotalSteps': safeTotal,
      'cookingProgress': progress,
      'cookingCompleted': isCompleted,
      'cookingExitedFromGuide': exitedCookingScreen,
      'cookingUpdatedAt': FieldValue.serverTimestamp(),
    };
    if (isCompleted) {
      payload['cookingCompletedAt'] = FieldValue.serverTimestamp();
    }

    await _historyRef(
      userId,
    ).doc('$recipeId').set(payload, SetOptions(merge: true));
  }

  Future<int?> fetchSavedCookingStep({
    required String userId,
    required int recipeId,
  }) async {
    if (recipeId <= 0) return null;

    final doc = await _historyRef(userId).doc('$recipeId').get();
    final data = doc.data();
    if (data == null) return null;

    final isCompleted = data['cookingCompleted'] == true;
    if (isCompleted) return null;

    final rawStep = data['cookingCurrentStep'];
    if (rawStep is int && rawStep > 0) return rawStep;
    if (rawStep is num && rawStep > 0) return rawStep.toInt();
    return null;
  }
}
