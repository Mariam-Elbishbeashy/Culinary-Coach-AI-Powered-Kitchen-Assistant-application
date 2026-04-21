import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:http_parser/http_parser.dart';

class IngredientModel {
  final String name;
  final String imageUrl;
  final String category;

  const IngredientModel({
    required this.name,
    required this.imageUrl,
    required this.category,
  });
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  File? _image;
  bool isAnalyzing = false;
  List<IngredientModel>? scannedIngredients;
  String? errorMessage;
  final ImagePicker _picker = ImagePicker();

  // LogMeal API credentials
  static const String logMealApiToken = '45fa82180add2a3d2b6db4f47ff2a257279567c8';

  // Common ingredients database for matching
  final Map<String, List<String>> _ingredientsDatabase = {
    'Vegetables': [
      'tomato', 'onion', 'garlic', 'potato', 'carrot', 'cucumber', 'lettuce',
      'spinach', 'broccoli', 'cauliflower', 'cabbage', 'celery', 'pepper',
      'bell pepper', 'chili', 'eggplant', 'zucchini', 'pumpkin', 'squash',
      'artichoke', 'asparagus', 'green beans', 'peas', 'corn', 'mushroom',
      'radish', 'beetroot', 'leek', 'okra', 'molokhia'
    ],
    'Fruits': [
      'apple', 'banana', 'orange', 'mango', 'grape', 'strawberry', 'blueberry',
      'raspberry', 'blackberry', 'watermelon', 'cantaloupe', 'honeydew',
      'pineapple', 'peach', 'pear', 'plum', 'apricot', 'cherry', 'kiwi',
      'lemon', 'lime', 'grapefruit', 'pomegranate', 'fig', 'date', 'guava'
    ],
    'Grains': [
      'rice', 'pasta', 'noodle', 'spaghetti', 'macaroni', 'bread', 'wheat',
      'oat', 'barley', 'quinoa', 'couscous', 'bulgur', 'freekeh', 'corn',
      'flour', 'semolina', 'vermicelli'
    ],
    'Legumes': [
      'bean', 'lentil', 'chickpea', 'hummus', 'fava bean', 'kidney bean',
      'black bean', 'white bean', 'soybean', 'tofu', 'tempeh', 'pea'
    ],
    'Meat': [
      'chicken', 'beef', 'lamb', 'pork', 'turkey', 'duck', 'rabbit', 'goat',
      'camel', 'veal', 'sausage', 'bacon', 'ham', 'meatball', 'steak'
    ],
    'Seafood': [
      'fish', 'salmon', 'tuna', 'tilapia', 'shrimp', 'prawn', 'crab', 'lobster',
      'calamari', 'squid', 'octopus', 'mussel', 'clam', 'oyster', 'sardine',
      'mackerel', 'cod', 'sea bass', 'mullet'
    ],
    'Dairy': [
      'milk', 'cheese', 'yogurt', 'butter', 'cream', 'ghee', 'labneh', 'feta',
      'ricotta', 'mozzarella', 'parmesan', 'cheddar', 'goat cheese'
    ],
    'Spices & Condiments': [
      'salt', 'pepper', 'cumin', 'coriander', 'cinnamon', 'turmeric', 'ginger',
      'garlic powder', 'onion powder', 'paprika', 'chili powder', 'curry',
      'oregano', 'thyme', 'rosemary', 'basil', 'mint', 'parsley', 'cilantro',
      'dill', 'saffron', 'cardamom', 'clove', 'nutmeg', 'vanilla', 'sugar',
      'honey', 'oil', 'olive oil', 'vinegar', 'soy sauce', 'hot sauce',
      'ketchup', 'mustard', 'mayonnaise', 'tahini', 'molasses', 'syrup'
    ]
  };

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600 ? 2 : (screenWidth < 900 ? 3 : 4);
    final childAspectRatio = screenWidth < 600 ? 0.85 : 0.9;

    return Scaffold(
      backgroundColor: const Color(0xFFF3E8DF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3E8DF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF3A2214)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scan Ingredients',
          style: TextStyle(
            color: Color(0xFF3A2214),
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Image display area
              Container(
                width: double.infinity,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(13),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _image == null
                    ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 80,
                      color: const Color(0xFFCB6B2E).withAlpha(100),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No image selected',
                      style: TextStyle(
                        color: Color(0xFF3A2214),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Take a photo of ingredients or a dish',
                      style: TextStyle(
                        color: const Color(0xFF3A2214).withAlpha(128),
                        fontSize: 12,
                      ),
                    ),
                  ],
                )
                    : ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.file(
                    _image!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 250,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Buttons row
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      color: const Color(0xFFCB6B2E),
                      onTap: () => _checkCameraPermissionAndPickImage(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      color: const Color(0xFFDD8E1E),
                      onTap: () => _checkStoragePermissionAndPickImage(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Analyze button
              if (_image != null && scannedIngredients == null)
                Container(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isAnalyzing ? null : _analyzeFoodImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCB6B2E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: isAnalyzing
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Text(
                      'Identify Food & Ingredients',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

              // Error message
              if (errorMessage != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withAlpha(50)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Scanned Ingredients Grid
              if (scannedIngredients != null && scannedIngredients!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: const Color(0xFF5A9A44),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Detected Ingredients',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3A2214),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${scannedIngredients!.length} ingredients',
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFFCB6B2E).withAlpha(180),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: childAspectRatio,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: scannedIngredients!.length,
                        itemBuilder: (context, index) {
                          final ingredient = scannedIngredients![index];
                          return _IngredientCard(ingredient: ingredient);
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                final ingredientsList = scannedIngredients!
                                    .map((e) => e.name)
                                    .toList();
                                Navigator.pop(context, ingredientsList);
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFCB6B2E)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text(
                                'Use These Ingredients',
                                style: TextStyle(color: Color(0xFFCB6B2E)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  scannedIngredients = null;
                                  _image = null;
                                  errorMessage = null;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFCB6B2E),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Scan New Image'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // Permission handling
  Future<void> _checkCameraPermissionAndPickImage() async {
    PermissionStatus status = await Permission.camera.request();

    if (status.isGranted) {
      await _pickImage(ImageSource.camera);
    } else if (status.isDenied) {
      setState(() {
        errorMessage = 'Camera permission is required to take photos';
      });
    } else if (status.isPermanentlyDenied) {
      _showPermissionDialog('Camera');
    }
  }

  Future<void> _checkStoragePermissionAndPickImage() async {
    PermissionStatus status;

    if (Platform.isAndroid) {
      status = await Permission.photos.request();
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
    } else {
      status = await Permission.photos.request();
    }

    if (status.isGranted) {
      await _pickImage(ImageSource.gallery);
    } else if (status.isPermanentlyDenied) {
      _showPermissionDialog('Gallery');
    } else {
      setState(() {
        errorMessage = 'Gallery permission is required';
      });
    }
  }

  void _showPermissionDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$permissionName Permission Required'),
          content: Text(
            'This app needs $permissionName permission to scan ingredients. Please enable it in app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          scannedIngredients = null;
          errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error picking image: $e';
      });
    }
  }

  // ==================== IMPROVED INGREDIENT DETECTION ====================

  Future<void> _analyzeFoodImage() async {
    if (_image == null) return;

    setState(() {
      isAnalyzing = true;
      errorMessage = null;
    });

    try {
      var uri = Uri.parse('https://api.logmeal.com/v2/recognition/complete');

      var request = http.MultipartRequest('POST', uri);

      request.headers.addAll({
        'Authorization': 'Bearer $logMealApiToken',
      });

      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          _image!.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      print("STATUS: ${response.statusCode}");
      print("BODY: $responseBody");

      if (response.statusCode == 200) {
        final data = json.decode(responseBody);

        // Extract ingredients from dish names
        final detectedIngredients = await _extractIngredientsFromResults(data);

        setState(() {
          scannedIngredients = detectedIngredients;
          isAnalyzing = false;
        });

      } else {
        throw Exception("API Error ${response.statusCode}");
      }

    } catch (e) {
      setState(() {
        errorMessage = 'Analysis failed: ${e.toString()}';
        isAnalyzing = false;
      });
    }
  }

  Future<List<IngredientModel>> _extractIngredientsFromResults(Map<String, dynamic> data) async {
    Set<String> uniqueIngredients = {};

    // Get dish names from recognition results
    List<String> dishNames = [];
    if (data['recognition_results'] != null) {
      for (var item in data['recognition_results']) {
        final dishName = item['name']?.toString().toLowerCase();
        if (dishName != null && dishName.isNotEmpty) {
          dishNames.add(dishName);
          print("Detected dish: $dishName");
        }
      }
    }

    // Extract ingredients from each dish name
    for (var dishName in dishNames) {
      final ingredients = _parseDishNameToIngredients(dishName);
      uniqueIngredients.addAll(ingredients);
    }

    // Also try to get ingredients from API if available
    if (data['recognition_results'] != null) {
      for (var item in data['recognition_results']) {
        if (item['ingredients'] != null) {
          for (var ing in item['ingredients']) {
            final ingName = ing['name']?.toString();
            if (ingName != null && ingName.isNotEmpty) {
              uniqueIngredients.add(ingName);
            }
          }
        }
      }
    }

    // Convert to IngredientModel list
    final ingredientsList = uniqueIngredients.map((name) {
      return IngredientModel(
        name: _capitalizeName(name),
        imageUrl: _getIngredientImageUrl(name),
        category: _getIngredientCategory(name),
      );
    }).toList();

    // Sort alphabetically
    ingredientsList.sort((a, b) => a.name.compareTo(b.name));

    return ingredientsList;
  }

  List<String> _parseDishNameToIngredients(String dishName) {
    Set<String> ingredients = {};
    final dishLower = dishName.toLowerCase();

    // Common dish mappings
    final Map<String, List<String>> dishMappings = {
      'hummus': ['chickpea', 'tahini', 'garlic', 'lemon', 'olive oil'],
      'falafel': ['chickpea', 'parsley', 'garlic', 'onion', 'cumin'],
      'koshari': ['rice', 'lentil', 'pasta', 'chickpea', 'tomato sauce', 'onion'],
      'molokhia': ['molokhia', 'garlic', 'coriander', 'chicken broth'],
      'mahshi': ['rice', 'onion', 'tomato', 'parsley', 'dill', 'eggplant', 'zucchini', 'cabbage'],
      'tagine': ['meat', 'onion', 'garlic', 'cumin', 'turmeric', 'saffron', 'olive'],
      'couscous': ['couscous', 'vegetable', 'chickpea', 'meat'],
      'pasta': ['pasta', 'tomato sauce', 'garlic', 'onion', 'basil'],
      'rice': ['rice'],
      'salad': ['lettuce', 'tomato', 'cucumber', 'onion', 'olive oil'],
      'soup': ['broth', 'vegetable', 'salt', 'pepper'],
      'curry': ['curry powder', 'coconut milk', 'onion', 'garlic', 'ginger'],
      'stew': ['meat', 'potato', 'carrot', 'onion', 'broth'],
      'roast': ['meat', 'potato', 'carrot', 'rosemary', 'thyme'],
      'grill': ['meat', 'salt', 'pepper', 'olive oil'],
      'sandwich': ['bread', 'meat', 'lettuce', 'tomato', 'mayonnaise'],
      'pizza': ['dough', 'tomato sauce', 'cheese', 'topping'],
      'burger': ['bun', 'beef patty', 'lettuce', 'tomato', 'onion', 'pickle'],
      'taco': ['tortilla', 'meat', 'lettuce', 'cheese', 'salsa'],
      'sushi': ['rice', 'seaweed', 'fish', 'vegetable', 'soy sauce'],
    };

    // Check for exact dish matches
    for (var entry in dishMappings.entries) {
      if (dishLower.contains(entry.key)) {
        ingredients.addAll(entry.value);
        print("Matched dish '${entry.key}' -> ingredients: ${entry.value}");
      }
    }

    // Also try to extract individual ingredient words
    final words = dishLower.split(RegExp(r'[\s,]+'));
    for (var word in words) {
      // Check if word matches any known ingredient
      for (var category in _ingredientsDatabase.values) {
        for (var ingredient in category) {
          if (word.contains(ingredient) || ingredient.contains(word)) {
            if (word.length > 3 && ingredient.length > 3) {
              ingredients.add(ingredient);
              print("Extracted ingredient '$ingredient' from word '$word'");
            }
          }
        }
      }
    }

    // If no ingredients found, add the dish name as is
    if (ingredients.isEmpty) {
      ingredients.add(dishName);
    }

    return ingredients.toList();
  }

  String _getIngredientCategory(String ingredientName) {
    final lowerName = ingredientName.toLowerCase();

    for (var entry in _ingredientsDatabase.entries) {
      for (var keyword in entry.value) {
        if (lowerName.contains(keyword)) {
          return entry.key;
        }
      }
    }

    return 'Other';
  }

  String _getIngredientImageUrl(String ingredientName) {
    final formattedName = ingredientName.replaceAll(' ', '-');
    return "https://www.themealdb.com/images/ingredients/$formattedName.png";
  }

  String _capitalizeName(String name) {
    return name.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}

// Ingredient Card Widget
class _IngredientCard extends StatelessWidget {
  const _IngredientCard({
    required this.ingredient,
  });

  final IngredientModel ingredient;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final imageSize = screenWidth < 600 ? 70.0 : 80.0;
    final fontSize = screenWidth < 600 ? 12.0 : 13.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFCB6B2E).withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: imageSize,
            height: imageSize,
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8DF).withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                ingredient.imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.restaurant,
                    size: imageSize * 0.6,
                    color: const Color(0xFFCB6B2E).withOpacity(0.7),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFCB6B2E)),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              ingredient.name,
              style: TextStyle(
                color: const Color(0xFF3A2214),
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFCB6B2E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              ingredient.category,
              style: TextStyle(
                color: const Color(0xFFCB6B2E),
                fontSize: screenWidth < 600 ? 9 : 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}