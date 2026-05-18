// ignore_for_file: avoid_print, deprecated_member_use, unnecessary_underscores
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:culinary_coach_app/features/filter/data/models/ingredient_model.dart';
import 'package:culinary_coach_app/features/filter/data/services/ingredient_service.dart';
import 'package:culinary_coach_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:image/image.dart' as img;

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  File? _image;
  bool isAnalyzing = false;
  List<IngredientModel>? scannedIngredients; // Only matched ingredients
  List<DetectedIngredient>? allDetected; // For debugging only
  String? errorMessage;
  final IngredientService _ingredientService = IngredientService();

  final ImagePicker _picker = ImagePicker();

  // Run with:
  // flutter run --dart-define=OPENAI_API_KEY=your_api_key_here
  static const String apiKey = String.fromEnvironment('OPENAI_API_KEY');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildCameraPreview(),
          _buildGradientOverlay(),
          _buildTopBar(),
          _buildScannerOverlay(),
          _buildBottomControls(),

          if (isAnalyzing)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(
                    "Analyzing image...",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),

          if (scannedIngredients != null && scannedIngredients!.isNotEmpty)
            _buildResultsSheet(),

          if (scannedIngredients != null && scannedIngredients!.isEmpty)
            _buildNoResultsMessage(),

          if (errorMessage != null) _buildErrorSnackbar(),
        ],
      ),
    );
  }

  // ================= UI =================

  Widget _buildCameraPreview() {
    return SizedBox.expand(
      child: _image == null
          ? Image.asset("assets/images/salad.jpg", fit: BoxFit.cover)
          : Image.file(
              _image!,
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.center,
          colors: [Colors.black.withOpacity(0.7), Colors.transparent],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 50,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _circleButton(Icons.arrow_back, () => Navigator.pop(context)),
          _circleButton(
            Icons.settings,
            () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return Center(
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: const Color(0xFFFF7A00), width: 2),
        ),
        child: const Center(
          child: Icon(Icons.graphic_eq, color: Color(0xFFFF7A00), size: 50),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 40,
      left: 20,
      right: 20,
      child: Column(
        children: [
          const Text(
            "Place ingredient in the frame to identify it.",
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.photo, color: Colors.white),
                onPressed: _pickFromGallery,
              ),

              GestureDetector(
                onTap: _pickFromCamera,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF7A00),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera, color: Colors.white),
                ),
              ),

              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _image = null;
                    scannedIngredients = null;
                    errorMessage = null;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSheet() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDarkMode ? const Color(0xFF1F1F1F) : Colors.white;
    final titleColor = isDarkMode ? const Color(0xFFF2F2F2) : Colors.black;
    final subtitleColor = isDarkMode ? const Color(0xFFBEBEBE) : Colors.grey[600];
    final tileBg = isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100];
    final itemTextColor = isDarkMode ? const Color(0xFFE3E3E3) : Colors.black;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 350,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Detected Ingredients",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const Spacer(),
                Text(
                  "${scannedIngredients!.length} items",
                  style: TextStyle(fontSize: 14, color: subtitleColor),
                ),
              ],
            ),
            const SizedBox(height: 15),

            Expanded(
              child: GridView.builder(
                itemCount: scannedIngredients!.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.8,
                ),
                itemBuilder: (_, i) {
                  final ing = scannedIngredients![i];
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tileBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ing.imageUrl.isNotEmpty
                            ? Image.network(
                                ing.imageUrl,
                                height: 50,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.food_bank, size: 40),
                              )
                            : const Icon(Icons.food_bank, size: 40),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        ing.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: itemTextColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, scannedIngredients);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A00),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Add to Selected Ingredients',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsMessage() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      bottom: 100,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1F1F1F) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              "No matching ingredients found",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? const Color(0xFFF2F2F2) : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Try taking another photo with better lighting or different angle",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? const Color(0xFFBEBEBE) : Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _image = null;
                  scannedIngredients = null;
                  errorMessage = null;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A00),
                foregroundColor: Colors.white,
              ),
              child: const Text("Try Again"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorSnackbar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage ?? 'An error occurred'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Dismiss',
            onPressed: () {
              setState(() => errorMessage = null);
            },
          ),
        ),
      );
    });
    return const SizedBox.shrink();
  }

  // ================= IMAGE PICKING =================

  Future<void> _pickFromCamera() async {
    await Permission.camera.request();
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
    );
    if (file != null) {
      final processedImage = await _prepareImage(File(file.path));
      setState(() {
        _image = processedImage;
        scannedIngredients = null;
        errorMessage = null;
      });
      _analyzeImage();
    }
  }

  Future<void> _pickFromGallery() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (file != null) {
      final processedImage = await _prepareImage(File(file.path));
      setState(() {
        _image = processedImage;
        scannedIngredients = null;
        errorMessage = null;
      });
      _analyzeImage();
    }
  }

  // ================= IMAGE PREPARATION =================

  Future<File> _prepareImage(File originalFile) async {
    try {
      final bytes = await originalFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        return originalFile;
      }

      print(
        'Original image: ${image.width}x${image.height}, ${bytes.length / 1024} KB',
      );

      const int maxDimension = 4096;
      img.Image processedImage = image;

      if (image.width > maxDimension || image.height > maxDimension) {
        if (image.width >= image.height) {
          final targetWidth = maxDimension;
          final targetHeight = (image.height * maxDimension / image.width)
              .round();
          processedImage = img.copyResize(
            image,
            width: targetWidth,
            height: targetHeight,
          );
          print('Resized to: ${processedImage.width}x${processedImage.height}');
        } else {
          final targetHeight = maxDimension;
          final targetWidth = (image.width * maxDimension / image.height)
              .round();
          processedImage = img.copyResize(
            image,
            width: targetWidth,
            height: targetHeight,
          );
          print('Resized to: ${processedImage.width}x${processedImage.height}');
        }
      }

      final jpegBytes = img.encodeJpg(processedImage, quality: 95);
      final tempFile = File(originalFile.path);
      await tempFile.writeAsBytes(jpegBytes);

      print('Final image size: ${jpegBytes.length / 1024} KB');
      return tempFile;
    } catch (e) {
      print('Error preparing image: $e');
      return originalFile;
    }
  }

  // ================= AI ANALYSIS =================

  Future<void> _analyzeImage() async {
    if (_image == null) return;

    setState(() {
      isAnalyzing = true;
      errorMessage = null;
    });

    try {
      final bytes = await _image!.readAsBytes();
      final base64Image = base64Encode(bytes);

      print('Sending image to API: ${bytes.length / 1024} KB');

      final response = await http.post(
        Uri.parse("https://api.openai.com/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "gpt-4o",
          "messages": [
            {
              "role": "user",
              "content": [
                {
                  "type": "text",
                  "text":
                      """Analyze this image and list EVERY ingredient you can see.

CRITICAL RULES:
1. Be SPECIFIC with names (e.g., "cherry tomato" not just "tomato")
2. Include ALL visible food items
3. If uncertain about an ingredient, still include it with your best guess
4. List common ingredient names that would exist in a standard cooking database

Return ONLY a JSON array of objects. Each object must have 'name' field.
Example: [{"name": "cherry tomatoes"}, {"name": "fresh basil"}, {"name": "garlic"}]

NO additional text, NO markdown, NO explanations.""",
                },
                {
                  "type": "image_url",
                  "image_url": {
                    "url": "data:image/jpeg;base64,$base64Image",
                    "detail": "high",
                  },
                },
              ],
            },
          ],
          "max_tokens": 1500,
          "temperature": 0.2,
        }),
      );

      if (response.statusCode != 200) {
        print('API Error: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('API Error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];

      print('Raw API Response: $content');

      // Clean and parse the response
      String cleanedContent = content.trim();

      if (cleanedContent.startsWith('```json')) {
        cleanedContent = cleanedContent.substring(7);
      }
      if (cleanedContent.startsWith('```')) {
        cleanedContent = cleanedContent.substring(3);
      }
      if (cleanedContent.endsWith('```')) {
        cleanedContent = cleanedContent.substring(0, cleanedContent.length - 3);
      }

      cleanedContent = cleanedContent.trim();

      final List<dynamic> detectedItems = jsonDecode(cleanedContent);

      if (detectedItems.isEmpty) {
        throw Exception('No ingredients detected in the image');
      }

      print('AI detected ${detectedItems.length} items');

      // Create a list of detected items
      final List<DetectedIngredient> detectedIngredients = [];
      for (var item in detectedItems) {
        detectedIngredients.add(
          DetectedIngredient(
            name: normalizeIngredientName(item['name'].toString()),
            color: '', // Not needed for filtering
            confidence: 'medium',
          ),
        );
        print('AI detected: ${item['name']}');
      }

      // Store all detected for debugging (optional)
      allDetected = detectedIngredients;

      // Fetch all ingredients from Firestore
      final allIngredients = await _ingredientService.getAllIngredients().first;
      print('Database has ${allIngredients.length} ingredients');

      // ONLY keep ingredients that exist in database
      final List<IngredientModel> matchedIngredients = [];
      final Set<String> addedIngredientIds = {};

      for (var detected in detectedIngredients) {
        IngredientModel? bestMatch;
        double bestScore = 0;
        String matchReason = '';

        for (IngredientModel ingredient in allIngredients) {
          final dbName = normalizeIngredientName(ingredient.name);
          double score = calculateMatchScore(detected.name, dbName);

          if (score > bestScore) {
            bestScore = score;
            bestMatch = ingredient;
            matchReason = getMatchReason(detected.name, dbName, score);
          }
        }

        // Only add if match score is above threshold AND not already added
        // Items NOT in database are SILENTLY IGNORED (never shown to user)
        if (bestMatch != null &&
            bestScore > 0.55 &&
            !addedIngredientIds.contains(bestMatch.id)) {
          matchedIngredients.add(bestMatch);
          addedIngredientIds.add(bestMatch.id);
          print(
            '✓ MATCHED (will show): "${detected.name}" -> ${bestMatch.name} (Score: $bestScore, Reason: $matchReason)',
          );
        } else if (bestMatch != null && bestScore <= 0.55) {
          print(
            '✗ REJECTED (low score): "${detected.name}" -> ${bestMatch.name} (Score: $bestScore)',
          );
        } else {
          print(
            '✗ REJECTED (not in DB): "${detected.name}" - No matching ingredient found',
          );
        }
      }

      if (matchedIngredients.isEmpty) {
        print('No ingredients could be matched to database');
        setState(() {
          scannedIngredients = []; // Empty list triggers "no results" message
          isAnalyzing = false;
        });
        return;
      }

      print(
        'Successfully matched ${matchedIngredients.length} ingredients from database',
      );

      setState(() {
        scannedIngredients = matchedIngredients;
        isAnalyzing = false;
      });
    } catch (e) {
      print('Error analyzing image: $e');
      setState(() {
        errorMessage = _getUserFriendlyError(e);
        isAnalyzing = false;
      });
    }
  }

  // ================= HELPER FUNCTIONS =================

  String normalizeIngredientName(String name) {
    return name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(
          RegExp(
            r'\b(fresh|raw|ripe|whole|sliced|diced|minced|chopped|organic|dried|frozen|canned)\b',
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  double calculateMatchScore(String detected, String dbName) {
    // Exact match
    if (dbName == detected) return 1.0;

    // Contains match
    if (dbName.contains(detected)) return 0.9;
    if (detected.contains(dbName)) return 0.8;

    // Word boundary matching
    final detectedWords = detected.split(' ');
    final dbWords = dbName.split(' ');

    for (String word in detectedWords) {
      if (dbWords.contains(word) && word.length > 2) {
        return 0.7;
      }
    }

    // Plural/singular
    final singularDetected = detected.endsWith('s')
        ? detected.substring(0, detected.length - 1)
        : detected;
    final singularDb = dbName.endsWith('s')
        ? dbName.substring(0, dbName.length - 1)
        : dbName;
    if (singularDetected == singularDb) return 0.85;

    // Common variations
    if (detected == 'tomato' && dbName == 'cherry tomato') return 0.65;
    if (detected == 'tomato' && dbName == 'roma tomato') return 0.65;
    if (detected == 'lettuce' && dbName.contains('lettuce')) return 0.75;
    if (detected.contains('pepper') && dbName.contains('pepper')) return 0.7;
    if (detected.contains('apple') && dbName.contains('apple')) return 0.7;
    if (detected == 'zucchini' && dbName == 'courgette') return 0.6;
    if (detected == 'eggplant' && dbName == 'aubergine') return 0.6;

    return 0.0;
  }

  String getMatchReason(String detected, String dbName, double score) {
    if (dbName == detected) return 'exact match';
    if (dbName.contains(detected)) return 'detected name contained in DB';
    if (detected.contains(dbName)) return 'DB name contained in detected';
    if (score >= 0.7) return 'word match';
    if (score >= 0.8) return 'singular/plural match';
    return 'fuzzy match';
  }

  String _getUserFriendlyError(dynamic error) {
    String errorStr = error.toString().toLowerCase();
    print('Error details: $errorStr');

    if (errorStr.contains('401') || errorStr.contains('unauthorized')) {
      return '⚠️ Invalid API key. Please check your OpenAI API key configuration.';
    } else if (errorStr.contains('429')) {
      return '⚠️ Rate limit exceeded. Please wait a moment and try again.';
    } else if (errorStr.contains('500') || errorStr.contains('503')) {
      return '⚠️ Server error. Please try again in a few moments.';
    } else if (errorStr.contains('no ingredients detected')) {
      return '📷 No ingredients detected. Try taking a clearer photo with better lighting.';
    } else if (errorStr.contains('socket') || errorStr.contains('network')) {
      return '🌐 Network error. Please check your internet connection.';
    } else if (errorStr.contains('timeout')) {
      return '⏱️ Request timeout. Please try again.';
    } else {
      return '❌ Failed to analyze image: ${error.toString().replaceFirst('Exception:', '')}';
    }
  }
}

// Helper class
class DetectedIngredient {
  final String name;
  final String color;
  final String confidence;

  DetectedIngredient({
    required this.name,
    required this.color,
    required this.confidence,
  });
}
