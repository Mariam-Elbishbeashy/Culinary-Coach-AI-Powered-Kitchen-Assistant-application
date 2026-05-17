import 'dart:async' show unawaited;

import 'package:culinary_coach_app/features/home/data/models/recipe_match.dart';
import 'package:culinary_coach_app/features/home/data/services/history_recipes_service.dart';
import 'package:culinary_coach_app/features/start_cooking/data/services/cooking_step_media_matcher.dart';
import 'package:culinary_coach_app/features/start_cooking/data/services/openai_cooking_voice_service.dart';
import 'package:flutter/material.dart';

// this is the screen user sees after pressing start cooking
class StartCookingScreen extends StatefulWidget {
  // recipe has all details including instruction steps
  // userId is used to save progress in firestore
  const StartCookingScreen({super.key, required this.recipe, this.userId});

  final RecipeMatch recipe;
  final String? userId;

  @override
  State<StartCookingScreen> createState() => _StartCookingScreenState();
}

class _StartCookingScreenState extends State<StartCookingScreen> {
  // this speaks each step using openai tts or fallback tts
  final OpenAiCookingVoiceService _voiceService = OpenAiCookingVoiceService();
  // this chooses the best gif for the current step text
  final CookingStepMediaMatcher _mediaMatcher = CookingStepMediaMatcher();
  // this saves and restores cooking progress from started_recipes
  final HistoryRecipesService _historyRecipesService = HistoryRecipesService();
  // this keeps selected gif path for each step index to avoid recalculating
  final Map<int, String> _assetByStepIndex = <int, String>{};

  // these are the final cleaned steps shown in this flow
  late final List<String> _steps;
  // this tells which step is currently visible
  int _currentStepIndex = 0;
  // this controls speaking state for ui label
  bool _isSpeaking = false;
  // this controls loading state while gif path is being matched
  bool _isLoadingAsset = false;
  // this turns true only when user reaches final finish action
  bool _didCompleteRecipe = false;
  // this prevents double save on quick back navigation events
  bool _isPersistingExit = false;

  @override
  void initState() {
    super.initState();
    // this prepares instruction list before first render
    _steps = _buildDisplaySteps(widget.recipe.instructions);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // this runs after first frame so async work does not block build
      _initializeFlow();
    });
  }

  // this sets up voice, restores old step if exists, then starts current step
  Future<void> _initializeFlow() async {
    await _setupVoice();
    await _restoreSavedProgressIfAny();
    await _loadGifForCurrentStep();
    await _speakCurrentStep();
  }

  // this prepares tts service one time
  Future<void> _setupVoice() async {
    await _voiceService.init();
  }

  // this normalizes instructions so screen always has usable step list
  List<String> _buildDisplaySteps(List<String> instructions) {
    if (instructions.isEmpty) {
      return const <String>[
        'Instructions are not available for this recipe. Please go back and pick another recipe.',
      ];
    }

    if (instructions.length > 1) {
      return instructions
          .map((step) => step.trim())
          .where((step) => step.isNotEmpty)
          .toList();
    }

    final single = instructions.first.trim();
    if (single.isEmpty) return const <String>['No instructions provided.'];

    final splitByNumbering = single.split(RegExp(r'\s(?=\d+[\)\.\-])'));
    if (splitByNumbering.length > 1) {
      final cleaned = splitByNumbering
          .map(
            (step) => step.replaceFirst(RegExp(r'^\d+[\)\.\-]\s*'), '').trim(),
          )
          .where((step) => step.isNotEmpty)
          .toList();
      if (cleaned.isNotEmpty) return cleaned;
    }

    return [single];
  }

  // this returns text of currently active step
  String get _currentStepText => _steps[_currentStepIndex];

  // this loads saved step from firestore if recipe was started before
  Future<void> _restoreSavedProgressIfAny() async {
    final userId = widget.userId;
    if (userId == null || userId.isEmpty) return;
    final savedStep = await _historyRecipesService.fetchSavedCookingStep(
      userId: userId,
      recipeId: widget.recipe.id,
    );
    if (!mounted || savedStep == null) return;

    final nextIndex = (savedStep - 1).clamp(0, _steps.length - 1);
    setState(() => _currentStepIndex = nextIndex);
  }

  // this loads and caches gif path for current step index
  Future<void> _loadGifForCurrentStep() async {
    if (_assetByStepIndex.containsKey(_currentStepIndex)) return;
    setState(() => _isLoadingAsset = true);
    final matched = await _mediaMatcher.matchForStep(_currentStepText);
    if (!mounted) return;
    setState(() {
      _assetByStepIndex[_currentStepIndex] = matched;
      _isLoadingAsset = false;
    });
  }

  // this speaks current step with step number intro
  Future<void> _speakCurrentStep() async {
    await _voiceService.stop();
    final spokenText =
        'Step ${_currentStepIndex + 1} of ${_steps.length}. $_currentStepText';
    if (mounted) setState(() => _isSpeaking = true);
    await _voiceService.speak(spokenText);
    if (mounted) setState(() => _isSpeaking = false);
  }

  // this moves to next step and saves progress each time
  Future<void> _goToNextStep() async {
    if (_currentStepIndex >= _steps.length - 1) {
      if (!mounted) return;
      await _voiceService.stop();
      // this marks completion when user finishes last step
      _didCompleteRecipe = true;
      await _saveProgress(exitedCookingScreen: true);
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    setState(() => _currentStepIndex += 1);
    await _saveProgress(exitedCookingScreen: false);
    await _loadGifForCurrentStep();
    await _speakCurrentStep();
  }

  // this goes one step back and saves new position
  Future<void> _goToPreviousStep() async {
    if (_currentStepIndex == 0) return;
    await _voiceService.stop();
    setState(() => _currentStepIndex -= 1);
    await _saveProgress(exitedCookingScreen: false);
    await _loadGifForCurrentStep();
    await _speakCurrentStep();
  }

  // this repeats speaking for same step
  Future<void> _repeatStep() async {
    await _speakCurrentStep();
  }

  // this writes progress and completion fields into started_recipes doc
  Future<void> _saveProgress({required bool exitedCookingScreen}) async {
    final userId = widget.userId;
    if (userId == null || userId.isEmpty) return;
    await _historyRecipesService.saveCookingProgress(
      userId: userId,
      recipeId: widget.recipe.id,
      currentStep: _didCompleteRecipe ? _steps.length : _currentStepIndex + 1,
      totalSteps: _steps.length,
      isCompleted: _didCompleteRecipe,
      exitedCookingScreen: exitedCookingScreen,
    );
  }

  // this handles back exit and saves latest progress before leaving
  Future<void> _handleExitFromScreen() async {
    if (_isPersistingExit) return;
    _isPersistingExit = true;
    await _voiceService.stop();
    try {
      await _saveProgress(exitedCookingScreen: true);
    } finally {
      _isPersistingExit = false;
    }
  }

  @override
  void dispose() {
    // this disposes voice resources when screen is removed
    _voiceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stepNumber = _currentStepIndex + 1;
    final totalSteps = _steps.length;
    final currentAsset = _assetByStepIndex[_currentStepIndex];
    final isLastStep = _currentStepIndex == totalSteps - 1;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return PopScope(
      canPop: true,
      // this captures system back gesture and app bar back to save progress
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) return;
        unawaited(_handleExitFromScreen());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F3ED),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF6F3ED),
          elevation: 0,
          title: const Text(
            'Start Cooking',
            style: TextStyle(
              color: Color(0xFF1F1B16),
              fontWeight: FontWeight.w800,
            ),
          ),
          iconTheme: const IconThemeData(color: Color(0xFF1F1B16)),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // this gives a different gif size based on orientation
              final gifHeight = isLandscape
                  ? (constraints.maxHeight * 0.30).clamp(120.0, 170.0)
                  : (constraints.maxHeight * 0.36).clamp(190.0, 250.0);

              // this landscape branch uses scroll to avoid overflow when height is short
              if (isLandscape) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.recipe.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F1B16),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          minHeight: 5,
                          value: totalSteps <= 1 ? 1 : stepNumber / totalSteps,
                          backgroundColor: const Color(0xFFEEE5D8),
                          color: const Color(0xFFE1A441),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Step $stepNumber / $totalSteps',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF7C7060),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: gifHeight,
                        child: Center(
                          child: currentAsset == null || _isLoadingAsset
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Color(0xFFB87313),
                                  ),
                                )
                              : Image.asset(
                                  // this displays selected gif for the step
                                  currentAsset,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                  gaplessPlayback: true,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.image_not_supported_outlined,
                                      color: Color(0xFF8D806E),
                                      size: 36,
                                    );
                                  },
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _currentStepText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF2E2821),
                          height: 1.38,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _currentStepIndex == 0
                                  ? null
                                  : _goToPreviousStep,
                              icon: const Icon(
                                Icons.chevron_left_rounded,
                                size: 16,
                              ),
                              label: const Text('Prev'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF7A4E0A),
                                side: const BorderSide(
                                  color: Color(0xFFD8C4A4),
                                ),
                                minimumSize: const Size.fromHeight(38),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _repeatStep,
                              icon: Icon(
                                _isSpeaking
                                    ? Icons.volume_up_rounded
                                    : Icons.replay,
                                size: 15,
                              ),
                              label: Text(_isSpeaking ? 'Speaking' : 'Repeat'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF7A4E0A),
                                side: const BorderSide(
                                  color: Color(0xFFD8C4A4),
                                ),
                                minimumSize: const Size.fromHeight(38),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _goToNextStep,
                              icon: const Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                              ),
                              label: Text(isLastStep ? 'Finish' : 'Next'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE1A441),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size.fromHeight(38),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }

              // this portrait branch keeps the original centered design
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F1B16),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 5,
                        value: totalSteps <= 1 ? 1 : stepNumber / totalSteps,
                        backgroundColor: const Color(0xFFEEE5D8),
                        color: const Color(0xFFE1A441),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Step $stepNumber / $totalSteps',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF7C7060),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: gifHeight,
                            child: Center(
                              child: currentAsset == null || _isLoadingAsset
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Color(0xFFB87313),
                                      ),
                                    )
                                  : Image.asset(
                                      // this displays selected gif for the step
                                      currentAsset,
                                      fit: BoxFit.contain,
                                      filterQuality: FilterQuality.high,
                                      gaplessPlayback: true,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return const Icon(
                                              Icons
                                                  .image_not_supported_outlined,
                                              color: Color(0xFF8D806E),
                                              size: 36,
                                            );
                                          },
                                    ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _currentStepText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF2E2821),
                              height: 1.38,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _currentStepIndex == 0
                                ? null
                                : _goToPreviousStep,
                            icon: const Icon(
                              Icons.chevron_left_rounded,
                              size: 16,
                            ),
                            label: const Text('Prev'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF7A4E0A),
                              side: const BorderSide(color: Color(0xFFD8C4A4)),
                              minimumSize: const Size.fromHeight(38),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _repeatStep,
                            icon: Icon(
                              _isSpeaking
                                  ? Icons.volume_up_rounded
                                  : Icons.replay,
                              size: 15,
                            ),
                            label: Text(_isSpeaking ? 'Speaking' : 'Repeat'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF7A4E0A),
                              side: const BorderSide(color: Color(0xFFD8C4A4)),
                              minimumSize: const Size.fromHeight(38),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _goToNextStep,
                            icon: const Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                            ),
                            label: Text(isLastStep ? 'Finish' : 'Next'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE1A441),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              minimumSize: const Size.fromHeight(38),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
