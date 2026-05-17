import 'dart:convert';

import 'package:flutter/services.dart';

// this service tries to choose the best gif for each cooking step text
class CookingStepMediaMatcher {
  CookingStepMediaMatcher();

  // this is the folder where all start cooking gifs exist
  static const String _assetPrefix = 'assets/images/start-coocking-assets/';
  // this is the safe gif we use when matching is not clear
  static const String _fallbackAsset =
      'assets/images/start-coocking-assets/stir_ingredients_in_a_bowl.gif';
  // this list is a backup so gifs still work even if asset manifest reading fails
  static const List<String> _knownGifAssets = <String>[
    'assets/images/start-coocking-assets/Food_prepAddingIngredients_sauce_salt_paper_andStir.gif',
    'assets/images/start-coocking-assets/Toaster.gif',
    'assets/images/start-coocking-assets/Weight machine.gif',
    'assets/images/start-coocking-assets/egg_on_pan.gif',
    'assets/images/start-coocking-assets/frying_pan_on_stove.gif',
    'assets/images/start-coocking-assets/girl_cutting_with_knife.gif',
    'assets/images/start-coocking-assets/pot_on_stove.gif',
    'assets/images/start-coocking-assets/stir_ingredients_in_a_bowl.gif',
    'assets/images/start-coocking-assets/stir_on_pot_over_stove.gif',
    'assets/images/start-coocking-assets/water_boiling.gif',
  ];

  // this cache stores gif paths so we do not read manifest every time
  List<String>? _cachedAssets;

  // this is the main method called from the screen to get one gif path for one step
  Future<String> matchForStep(String stepText) async {
    final assets = await _loadAssets();
    if (assets.isEmpty) return _fallbackAsset;

    final normalizedStep = _normalize(stepText);
    if (normalizedStep.isEmpty) return assets.first;

    String bestAsset = assets.first;
    var bestScore = -1;
    for (final asset in assets) {
      final score = _scoreAsset(step: normalizedStep, assetPath: asset);
      if (score > bestScore) {
        bestScore = score;
        bestAsset = asset;
      }
    }
    return bestAsset;
  }

  // this loads gif paths from flutter asset manifest and falls back to known list if needed
  Future<List<String>> _loadAssets() async {
    final cached = _cachedAssets;
    if (cached != null) return cached;

    try {
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final decoded = jsonDecode(manifestJson);
      if (decoded is! Map<String, dynamic>) {
        _cachedAssets = List<String>.from(_knownGifAssets);
        return _cachedAssets!;
      }

      final assets =
          decoded.keys
              .where((path) => path.startsWith(_assetPrefix))
              .where((path) => path.toLowerCase().endsWith('.gif'))
              .toList()
            ..sort();

      _cachedAssets = assets.isEmpty
          ? List<String>.from(_knownGifAssets)
          : assets;
      return _cachedAssets!;
    } catch (_) {
      _cachedAssets = List<String>.from(_knownGifAssets);
      return _cachedAssets!;
    }
  }

  // this gives a score for one gif based on words in the cooking step
  int _scoreAsset({required String step, required String assetPath}) {
    final assetName = assetPath.split('/').last;
    final normalizedAsset = _normalize(assetName);
    final stepTokens = _tokenize(step);
    final assetTokens = _tokenize(normalizedAsset);

    var score = 0;

    for (final token in stepTokens) {
      if (assetTokens.contains(token)) score += 7;
    }

    // this map gives extra hints so similar words can still match the right gif
    final lexicalHint = <String, List<String>>{
      'chop': ['cut', 'knife', 'cutting'],
      'cut': ['cut', 'knife', 'cutting'],
      'slice': ['cut', 'knife', 'cutting'],
      'dice': ['cut', 'knife', 'cutting'],
      'mince': ['cut', 'knife', 'cutting'],
      'mix': ['stir', 'bowl', 'ingredients'],
      'stir': ['stir', 'pot', 'bowl'],
      'whisk': ['stir', 'bowl'],
      'boil': ['boil', 'water', 'pot'],
      'simmer': ['boil', 'water', 'pot'],
      'fry': ['frying', 'pan', 'stove'],
      'saute': ['frying', 'pan', 'stove'],
      'sear': ['frying', 'pan', 'stove'],
      'grill': ['frying', 'pan', 'stove'],
      'toast': ['toaster'],
      'bake': ['toaster', 'oven'],
      'egg': ['egg', 'pan'],
      'steak': ['frying', 'pan'],
      'season': ['salt', 'pepper', 'ingredients'],
      'add': ['adding', 'ingredients', 'sauce', 'salt'],
      'measure': ['weight', 'machine'],
      'weight': ['weight', 'machine'],
      'pot': ['pot', 'stove'],
      'pan': ['pan', 'stove'],
    };

    for (final entry in lexicalHint.entries) {
      if (!stepTokens.contains(entry.key)) continue;
      for (final hint in entry.value) {
        if (assetTokens.contains(hint)) score += 6;
      }
    }

    if (step.contains('preheat') && assetTokens.contains('toaster')) {
      score += 12;
    }
    if (step.contains('water') && assetTokens.contains('boiling')) {
      score += 12;
    }
    if (step.contains('bowl') && assetTokens.contains('bowl')) {
      score += 10;
    }
    if (step.contains('stove') && assetTokens.contains('stove')) {
      score += 8;
    }
    if (step.contains('grill') && assetTokens.contains('frying')) {
      score += 11;
    }

    // this prevents egg gif from showing when instruction is not about eggs
    final hasEggInStep =
        stepTokens.contains('egg') || stepTokens.contains('eggs');
    final hasEggInAsset =
        assetTokens.contains('egg') || assetTokens.contains('eggs');
    if (hasEggInAsset && !hasEggInStep) {
      score -= 28;
    }
    if (hasEggInStep && hasEggInAsset) {
      score += 16;
    }

    return score;
  }

  // this cleans text so matching is easier and more consistent
  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // this splits cleaned text into unique words for quick matching
  Set<String> _tokenize(String text) {
    return _normalize(
      text,
    ).split(' ').where((token) => token.isNotEmpty).toSet();
  }
}
