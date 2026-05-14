// lib/features/filter/data/services/ingredient_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:culinary_coach_app/features/filter/data/models/ingredient_model.dart';

class IngredientService {
  IngredientService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const String _collectionName =
      'full_ingredients'; // ✅ Changed to match upload

  Stream<List<IngredientModel>> getAllIngredients() {
    return _firestore
        .collection(_collectionName)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => IngredientModel.fromFirestore(doc))
              .toList();
        });
  }

  // Client-side filtering - NO INDEX REQUIRED
  Stream<List<IngredientModel>> getIngredientsByCategoryStream(
    String category,
  ) {
    if (category == 'All') {
      return getAllIngredients();
    }

    return getAllIngredients().map((ingredients) {
      return ingredients.where((i) => i.category == category).toList();
    });
  }

  Future<List<IngredientModel>> getIngredientsByCategory(
    String category,
  ) async {
    final snapshot = await _firestore.collection(_collectionName).get();
    final allIngredients = snapshot.docs
        .map((doc) => IngredientModel.fromFirestore(doc))
        .toList();

    if (category == 'All') {
      allIngredients.sort((a, b) => a.name.compareTo(b.name));
      return allIngredients;
    }

    final filtered = allIngredients
        .where((i) => i.category == category)
        .toList();
    filtered.sort((a, b) => a.name.compareTo(b.name));
    return filtered;
  }

  Future<List<String>> getAllCategories() async {
    final snapshot = await _firestore.collection(_collectionName).get();
    final categories = snapshot.docs
        .map((doc) => doc.data()['category'] as String)
        .toSet()
        .toList();
    categories.sort();
    return ['All', ...categories];
  }

  Future<Map<String, int>> getCategoryCounts() async {
    final snapshot = await _firestore.collection(_collectionName).get();
    final counts = <String, int>{};
    for (var doc in snapshot.docs) {
      final category = doc.data()['category'] as String;
      counts[category] = (counts[category] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> addIngredient(IngredientModel ingredient) async {
    await _firestore
        .collection(_collectionName)
        .doc(ingredient.id)
        .set(ingredient.toFirestore());
  }

  Future<void> addMultipleIngredients(List<IngredientModel> ingredients) async {
    final batch = _firestore.batch();
    for (var ingredient in ingredients) {
      final docRef = _firestore.collection(_collectionName).doc(ingredient.id);
      batch.set(docRef, ingredient.toFirestore());
    }
    await batch.commit();
  }

  Future<void> deleteIngredient(String id) async {
    await _firestore.collection(_collectionName).doc(id).delete();
  }

  Future<bool> isCollectionEmpty() async {
    final snapshot = await _firestore
        .collection(_collectionName)
        .limit(1)
        .get();
    return snapshot.docs.isEmpty;
  }

  // New method to get ingredient count
  Future<int> getIngredientCount() async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  CollectionReference<Map<String, dynamic>> _userSelectedIngredientsRef(
    String userId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('selected_ingredients');
  }

  CollectionReference<Map<String, dynamic>> _userShopCartItemsRef(
    String userId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('shop_cart_items');
  }

  Future<void> saveUserSelectedIngredient({
    required String userId,
    required IngredientModel ingredient,
    required double quantity,
  }) async {
    final data = <String, dynamic>{
      ...ingredient.toFirestore(),
      'ingredientId': ingredient.id,
      'quantity': quantity,
      'userId': userId,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _userSelectedIngredientsRef(
      userId,
    ).doc(ingredient.id).set(data, SetOptions(merge: true));
  }

  Future<void> saveUserShopCartItem({
    required String userId,
    required IngredientModel ingredient,
    required double quantity,
  }) async {
    final data = <String, dynamic>{
      ...ingredient.toFirestore(),
      'ingredientId': ingredient.id,
      'quantity': quantity,
      'userId': userId,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _userShopCartItemsRef(
      userId,
    ).doc(ingredient.id).set(data, SetOptions(merge: true));
  }

  Future<void> updateUserSelectedIngredientQuantity({
    required String userId,
    required String ingredientId,
    required double quantity,
  }) async {
    await _userSelectedIngredientsRef(userId).doc(ingredientId).set({
      'ingredientId': ingredientId,
      'quantity': quantity,
      'userId': userId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteUserSelectedIngredient({
    required String userId,
    required String ingredientId,
  }) async {
    await _userSelectedIngredientsRef(userId).doc(ingredientId).delete();
  }

  Future<void> clearUserSelectedIngredients(String userId) async {
    final snapshot = await _userSelectedIngredientsRef(userId).get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  CollectionReference<Map<String, dynamic>> _userFrequentIngredientsRef(
    String userId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('frequent_ingredients');
  }

  Future<void> recordUserFrequentIngredient({
    required String userId,
    required IngredientModel ingredient,
  }) async {
    await _userFrequentIngredientsRef(userId).doc(ingredient.id).set({
      ...ingredient.toFirestore(),
      'ingredientId': ingredient.id,
      'userId': userId,
      'searchCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<IngredientModel>> streamUserFrequentIngredients(
    String userId, {
    int limit = 10,
  }) {
    return _userFrequentIngredientsRef(userId)
        .orderBy('searchCount', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
          final ingredients = <IngredientModel>[];
          final usedIds = <String>{};

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final ingredientId = (data['ingredientId'] as String?) ?? doc.id;
            if (usedIds.contains(ingredientId)) continue;

            try {
              final ingredientDoc = await _firestore
                  .collection(_collectionName)
                  .doc(ingredientId)
                  .get();
              if (ingredientDoc.exists) {
                ingredients.add(IngredientModel.fromFirestore(ingredientDoc));
              } else {
                ingredients.add(IngredientModel.fromFirestore(doc));
              }
              usedIds.add(ingredientId);
            } catch (_) {
              // Skip invalid frequent ingredient records.
            }
          }

          return ingredients;
        });
  }

  Stream<List<SavedIngredientSelection>> streamUserSelectedIngredients(
    String userId,
  ) {
    return _userSelectedIngredientsRef(
      userId,
    ).orderBy('updatedAt', descending: true).snapshots().asyncMap((
      selectedSnapshot,
    ) async {
      final selections = <SavedIngredientSelection>[];

      for (final selectedDoc in selectedSnapshot.docs) {
        final data = selectedDoc.data();
        final ingredientId =
            (data['ingredientId'] as String?) ?? selectedDoc.id;
        final quantityValue = data['quantity'];
        final quantity = quantityValue is num ? quantityValue.toDouble() : 1.0;

        try {
          final ingredientDoc = await _firestore
              .collection(_collectionName)
              .doc(ingredientId)
              .get();

          if (ingredientDoc.exists) {
            selections.add(
              SavedIngredientSelection(
                ingredient: IngredientModel.fromFirestore(ingredientDoc),
                quantity: quantity,
              ),
            );
          } else {
            selections.add(
              SavedIngredientSelection(
                ingredient: IngredientModel.fromFirestore(selectedDoc),
                quantity: quantity,
              ),
            );
          }
        } catch (_) {
          // Skip invalid saved ingredients instead of breaking the whole screen.
        }
      }

      selections.sort((a, b) => a.ingredient.name.compareTo(b.ingredient.name));
      return selections;
    });
  }

  Future<List<SavedIngredientSelection>> getUserSelectedIngredients(
    String userId,
  ) async {
    final selectedSnapshot = await _userSelectedIngredientsRef(userId).get();
    final selections = <SavedIngredientSelection>[];

    for (final selectedDoc in selectedSnapshot.docs) {
      final data = selectedDoc.data();
      final ingredientId = (data['ingredientId'] as String?) ?? selectedDoc.id;
      final quantityValue = data['quantity'];
      final quantity = quantityValue is num ? quantityValue.toDouble() : 1.0;

      try {
        final ingredientDoc = await _firestore
            .collection(_collectionName)
            .doc(ingredientId)
            .get();
        if (ingredientDoc.exists) {
          selections.add(
            SavedIngredientSelection(
              ingredient: IngredientModel.fromFirestore(ingredientDoc),
              quantity: quantity,
            ),
          );
        } else {
          selections.add(
            SavedIngredientSelection(
              ingredient: IngredientModel.fromFirestore(selectedDoc),
              quantity: quantity,
            ),
          );
        }
      } catch (_) {
        // Skip invalid saved ingredients instead of breaking the whole screen.
      }
    }

    selections.sort((a, b) => a.ingredient.name.compareTo(b.ingredient.name));
    return selections;
  }

  Future<List<SavedIngredientSelection>> getUserShopCartItems(
    String userId,
  ) async {
    final selectedSnapshot = await _userShopCartItemsRef(userId).get();
    final selections = <SavedIngredientSelection>[];

    for (final selectedDoc in selectedSnapshot.docs) {
      final data = selectedDoc.data();
      final ingredientId = (data['ingredientId'] as String?) ?? selectedDoc.id;
      final quantityValue = data['quantity'];
      final quantity = quantityValue is num ? quantityValue.toDouble() : 1.0;

      try {
        final ingredientDoc = await _firestore
            .collection(_collectionName)
            .doc(ingredientId)
            .get();
        if (ingredientDoc.exists) {
          selections.add(
            SavedIngredientSelection(
              ingredient: IngredientModel.fromFirestore(ingredientDoc),
              quantity: quantity,
            ),
          );
        } else {
          selections.add(
            SavedIngredientSelection(
              ingredient: IngredientModel.fromFirestore(selectedDoc),
              quantity: quantity,
            ),
          );
        }
      } catch (_) {
        // Skip invalid saved ingredients instead of breaking the whole screen.
      }
    }

    selections.sort((a, b) => a.ingredient.name.compareTo(b.ingredient.name));
    return selections;
  }
}

class SavedIngredientSelection {
  final IngredientModel ingredient;
  final double quantity;

  SavedIngredientSelection({required this.ingredient, required this.quantity});
}
