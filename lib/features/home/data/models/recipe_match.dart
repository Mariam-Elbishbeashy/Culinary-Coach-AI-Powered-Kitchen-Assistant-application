// lib/features/home/data/models/recipe_match.dart

class RecipeMatch {
  final int id;
  final String title;
  final String image;
  final int usedIngredientCount;
  final int missedIngredientCount;
  final double rating;
  final int readyInMinutes;
  final int servings;
  final int calories;
  final String? difficulty;
  final int? preparationMinutes;
  final List<RecipeIngredient> ingredientDetails;
  final String summary;
  final List<String> usedIngredients;
  final List<String> missedIngredients;
  final List<String> unusedIngredients;
  final List<String> instructions;

  const RecipeMatch({
    required this.id,
    required this.title,
    required this.image,
    required this.usedIngredientCount,
    required this.missedIngredientCount,
    required this.rating,
    required this.readyInMinutes,
    required this.servings,
    required this.calories,
    this.difficulty,
    this.preparationMinutes,
    required this.ingredientDetails,
    required this.summary,
    required this.usedIngredients,
    required this.missedIngredients,
    required this.unusedIngredients,
    required this.instructions,
  });

  static int _readInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _readDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int? _readOptionalInt(dynamic value) {
    final parsed = _readInt(value, -1);
    return parsed > 0 ? parsed : null;
  }

  static double? _readOptionalDouble(dynamic value) {
    if (value is num) {
      final parsed = value.toDouble();
      return parsed > 0 ? parsed : null;
    }
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static String? _readDifficulty(Map<String, dynamic> json) {
    final raw = (json['difficulty'] ?? json['difficultyLevel'] ?? json['level'])
        ?.toString()
        .trim();
    if (raw == null || raw.isEmpty) return null;
    final lowered = raw.toLowerCase();
    return lowered[0].toUpperCase() + lowered.substring(1);
  }

  static int _caloriesFromJson(Map<String, dynamic> json) {
    final direct = _readInt(json['calories'], -1);
    if (direct >= 0) return direct;

    final nutrition = json['nutrition'];
    if (nutrition is Map<String, dynamic>) {
      final nutrients = nutrition['nutrients'];
      if (nutrients is List) {
        for (final item in nutrients) {
          if (item is Map<String, dynamic>) {
            final name = (item['name'] ?? '').toString().toLowerCase();
            if (name == 'calories') {
              return _readDouble(item['amount'], 0).round();
            }
          }
        }
      }
    }

    return 0;
  }

  static double _ratingFromJson(Map<String, dynamic> json) {
    // Spoonacular usually returns scores as 0..100. Convert to a 0..5 star value.
    final spoonacularScore = _readDouble(json['spoonacularScore'], -1);
    if (spoonacularScore >= 0)
      return (spoonacularScore / 20).clamp(0, 5).toDouble();

    final healthScore = _readDouble(json['healthScore'], -1);
    if (healthScore >= 0) return (healthScore / 20).clamp(0, 5).toDouble();

    // Fallback for endpoints that only return popularity counts.
    final likes = _readDouble(json['aggregateLikes'], -1);
    if (likes >= 0) return (3.5 + (likes / 200)).clamp(0, 5).toDouble();

    return 0.0;
  }

  static List<String> _readIngredientNames(
    Map<String, dynamic> json,
    String key,
  ) {
    final list = json[key];
    if (list is! List) return [];
    return list
        .map((item) {
          if (item is Map<String, dynamic>) {
            return (item['name'] ??
                    item['original'] ??
                    item['originalName'] ??
                    '')
                .toString();
          }
          return '';
        })
        .where((name) => name.trim().isNotEmpty)
        .toList();
  }

  static List<String> _readInstructionSteps(Map<String, dynamic> json) {
    final steps = <String>[];
    final analyzed = json['analyzedInstructions'];
    if (analyzed is List &&
        analyzed.isNotEmpty &&
        analyzed.first is Map<String, dynamic>) {
      final rawSteps = (analyzed.first as Map<String, dynamic>)['steps'];
      if (rawSteps is List) {
        for (final item in rawSteps) {
          if (item is Map<String, dynamic>) {
            final step = (item['step'] ?? '').toString().trim();
            if (step.isNotEmpty) steps.add(step);
          }
        }
      }
    }

    final rawInstructions = (json['instructions'] ?? '').toString().trim();
    if (steps.isEmpty && rawInstructions.isNotEmpty) {
      final cleaned = _stripHtml(rawInstructions);
      if (cleaned.isNotEmpty) steps.add(cleaned);
    }

    return steps;
  }

  static String _stripHtml(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<RecipeIngredient> _readDetailedIngredients(
    Map<String, dynamic> json,
  ) {
    final detailed = <RecipeIngredient>[];
    final seen = <String>{};

    void addFromList(dynamic rawList) {
      if (rawList is! List) return;
      for (final item in rawList) {
        if (item is! Map<String, dynamic>) continue;
        final name =
            (item['nameClean'] ?? item['name'] ?? item['originalName'] ?? '')
                .toString()
                .trim();
        if (name.isEmpty) continue;
        final key = name.toLowerCase();
        if (seen.contains(key)) continue;
        seen.add(key);

        detailed.add(
          RecipeIngredient(
            name: name,
            amount: _readOptionalDouble(item['amount']),
            unit: (item['unit'] ?? '').toString().trim(),
          ),
        );
      }
    }

    addFromList(json['extendedIngredients']);
    if (detailed.isEmpty) {
      addFromList(json['usedIngredients']);
      addFromList(json['missedIngredients']);
      addFromList(json['unusedIngredients']);
    }

    return detailed;
  }

  factory RecipeMatch.fromFindByIngredientsJson(Map<String, dynamic> json) {
    return RecipeMatch(
      id: _readInt(json['id'], 0),
      title: (json['title'] ?? 'Recipe').toString(),
      image: (json['image'] ?? '').toString(),
      usedIngredientCount: _readInt(json['usedIngredientCount'], 0),
      missedIngredientCount: _readInt(json['missedIngredientCount'], 0),
      rating: _ratingFromJson(json),
      readyInMinutes: _readInt(json['readyInMinutes'], 0),
      servings: _readInt(json['servings'], 0),
      calories: _caloriesFromJson(json),
      difficulty: _readDifficulty(json),
      preparationMinutes: _readOptionalInt(json['preparationMinutes']),
      ingredientDetails: _readDetailedIngredients(json),
      summary: _stripHtml((json['summary'] ?? '').toString()),
      usedIngredients: _readIngredientNames(json, 'usedIngredients'),
      missedIngredients: _readIngredientNames(json, 'missedIngredients'),
      unusedIngredients: _readIngredientNames(json, 'unusedIngredients'),
      instructions: _readInstructionSteps(json),
    );
  }

  factory RecipeMatch.fromComplexSearchJson(
    Map<String, dynamic> json,
    List<String> pantryIngredients,
  ) {
    final used = <String>[];
    final missed = <String>[];
    final extendedIngredients = json['extendedIngredients'];

    if (extendedIngredients is List) {
      for (final item in extendedIngredients) {
        if (item is Map<String, dynamic>) {
          final name = (item['name'] ?? item['originalName'] ?? '').toString();
          if (name.trim().isEmpty) continue;
          final normalizedName = name.toLowerCase();
          final isOwned = pantryIngredients.any(
            (pantryItem) =>
                normalizedName.contains(pantryItem) ||
                pantryItem.contains(normalizedName),
          );
          if (isOwned) {
            used.add(name);
          } else {
            missed.add(name);
          }
        }
      }
    }

    return RecipeMatch(
      id: _readInt(json['id'], 0),
      title: (json['title'] ?? 'Recipe').toString(),
      image: (json['image'] ?? '').toString(),
      usedIngredientCount: used.length,
      missedIngredientCount: missed.length,
      rating: _ratingFromJson(json),
      readyInMinutes: _readInt(json['readyInMinutes'], 0),
      servings: _readInt(json['servings'], 0),
      calories: _caloriesFromJson(json),
      difficulty: _readDifficulty(json),
      preparationMinutes: _readOptionalInt(json['preparationMinutes']),
      ingredientDetails: _readDetailedIngredients(json),
      summary: _stripHtml((json['summary'] ?? '').toString()),
      usedIngredients: used,
      missedIngredients: missed,
      unusedIngredients: const [],
      instructions: _readInstructionSteps(json),
    );
  }

  factory RecipeMatch.fromRandomJson(Map<String, dynamic> json) {
    final ingredients = _readIngredientNames(json, 'extendedIngredients');

    return RecipeMatch(
      id: _readInt(json['id'], 0),
      title: (json['title'] ?? 'Recipe').toString(),
      image: (json['image'] ?? '').toString(),
      usedIngredientCount: 0,
      missedIngredientCount: 0,
      rating: _ratingFromJson(json),
      readyInMinutes: _readInt(json['readyInMinutes'], 0),
      servings: _readInt(json['servings'], 0),
      calories: _caloriesFromJson(json),
      difficulty: _readDifficulty(json),
      preparationMinutes: _readOptionalInt(json['preparationMinutes']),
      ingredientDetails: _readDetailedIngredients(json),
      summary: _stripHtml((json['summary'] ?? '').toString()),
      usedIngredients: const [],
      missedIngredients: const [],
      unusedIngredients: ingredients,
      instructions: _readInstructionSteps(json),
    );
  }

  RecipeMatch copyWithDetails(Map<String, dynamic> json) {
    final detailed = RecipeMatch.fromRandomJson(json);
    return RecipeMatch(
      id: id,
      title: title.isNotEmpty ? title : detailed.title,
      image: image.isNotEmpty ? image : detailed.image,
      usedIngredientCount: usedIngredientCount,
      missedIngredientCount: missedIngredientCount,
      rating: detailed.rating > 0 ? detailed.rating : rating,
      readyInMinutes: detailed.readyInMinutes > 0
          ? detailed.readyInMinutes
          : readyInMinutes,
      servings: detailed.servings > 0 ? detailed.servings : servings,
      calories: detailed.calories > 0 ? detailed.calories : calories,
      difficulty: detailed.difficulty ?? difficulty,
      preparationMinutes: detailed.preparationMinutes ?? preparationMinutes,
      ingredientDetails: detailed.ingredientDetails.isNotEmpty
          ? detailed.ingredientDetails
          : ingredientDetails,
      summary: detailed.summary.isNotEmpty ? detailed.summary : summary,
      usedIngredients: usedIngredients,
      missedIngredients: missedIngredients,
      unusedIngredients: detailed.unusedIngredients.isNotEmpty
          ? detailed.unusedIngredients
          : unusedIngredients,
      instructions: detailed.instructions.isNotEmpty
          ? detailed.instructions
          : instructions,
    );
  }

  RecipeMatch mergeDetails(RecipeMatch detailed) {
    return RecipeMatch(
      id: id,
      title: title.isNotEmpty ? title : detailed.title,
      image: image.isNotEmpty ? image : detailed.image,
      usedIngredientCount: usedIngredientCount,
      missedIngredientCount: missedIngredientCount,
      rating: detailed.rating > 0 ? detailed.rating : rating,
      readyInMinutes: detailed.readyInMinutes > 0
          ? detailed.readyInMinutes
          : readyInMinutes,
      servings: detailed.servings > 0 ? detailed.servings : servings,
      calories: detailed.calories > 0 ? detailed.calories : calories,
      difficulty: detailed.difficulty ?? difficulty,
      preparationMinutes: detailed.preparationMinutes ?? preparationMinutes,
      ingredientDetails: detailed.ingredientDetails.isNotEmpty
          ? detailed.ingredientDetails
          : ingredientDetails,
      summary: detailed.summary.isNotEmpty ? detailed.summary : summary,
      usedIngredients: usedIngredients,
      missedIngredients: missedIngredients,
      unusedIngredients: detailed.unusedIngredients.isNotEmpty
          ? detailed.unusedIngredients
          : unusedIngredients,
      instructions: detailed.instructions.isNotEmpty
          ? detailed.instructions
          : instructions,
    );
  }
}

class RecipeIngredient {
  const RecipeIngredient({required this.name, this.amount, this.unit = ''});

  final String name;
  final double? amount;
  final String unit;
}
