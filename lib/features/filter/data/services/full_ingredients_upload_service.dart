// lib/features/filter/data/services/full_ingredients_upload_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:culinary_coach_app/features/filter/data/domain/halal_ingredients_database.dart';

class FullIngredientsUploadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'full_ingredients';

  /// Generate unique ID from ingredient name
  String _generateId(String name) {
    return name
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll("'", '')
        .replaceAll('-', '_')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll('/', '_')
        .replaceAll('\\', '_')
        .replaceAll(',', '');
  }

  /// Generate search query string
  String _generateSearchQuery(CompleteHalalIngredient ingredient) {
    final parts = [
      ingredient.name.toLowerCase(),
      ingredient.nameArabic.toLowerCase(),
      ingredient.category.toLowerCase(),
      ingredient.categoryArabic.toLowerCase(),
      ingredient.region.toLowerCase(),
      ...ingredient.commonUses.map((use) => use.toLowerCase()),
      ingredient.season.toLowerCase(),
    ];
    return parts.join(' ');
  }

  /// Generate image URL
  String _generateImageUrl(CompleteHalalIngredient ingredient) {
    final keyword = ingredient.imageKeyword.toLowerCase().replaceAll(' ', '_');
    final category = ingredient.category.toLowerCase().replaceAll(' ', '_');
    return 'https://your-cdn.com/ingredients/$category/$keyword.jpg';
  }

  /// Get Egyptian pricing based on ingredient
  double _getEgyptianPrice(CompleteHalalIngredient ingredient) {
    final name = ingredient.name;
    final category = ingredient.category;

    // ==================== VEGETABLES ====================
    if (category == 'Vegetables') {
      final Map<String, double> vegPrices = {
        'Molokhia': 15.0, 'Jute Leaves': 15.0, 'Spinach': 12.0, 'Lettuce': 8.0,
        'Arugula': 8.0, 'Watercress': 5.0, 'Kale': 40.0, 'Swiss Chard': 10.0,
        'Collard Greens': 15.0, 'Mustard Greens': 12.0, 'Potato': 12.0,
        'Sweet Potato': 15.0, 'Carrot': 7.0, 'Radish': 5.0, 'Turnip': 6.0,
        'Beetroot': 8.0, 'Parsnip': 25.0, 'Celery Root': 20.0, 'Horseradish': 30.0,
        'Onion': 8.0, 'Red Onion': 10.0, 'White Onion': 8.0, 'Shallot': 40.0,
        'Garlic': 60.0, 'Leeks': 15.0, 'Scallions': 10.0, 'Celery': 10.0,
        'Asparagus': 50.0, 'Fennel': 25.0, 'Bamboo Shoots': 40.0, 'Hearts of Palm': 60.0,
        'Cabbage': 10.0, 'Red Cabbage': 12.0, 'Cauliflower': 15.0, 'Broccoli': 20.0,
        'Brussels Sprouts': 30.0, 'Kohlrabi': 15.0, 'Broccolini': 35.0, 'Romanesco': 30.0,
        'Tomato': 10.0, 'Cherry Tomato': 20.0, 'Roma Tomato': 12.0, 'Eggplant': 10.0,
        'Japanese Eggplant': 15.0, 'Bell Pepper': 15.0, 'Green Bell Pepper': 12.0,
        'Red Bell Pepper': 18.0, 'Yellow Bell Pepper': 18.0, 'Orange Bell Pepper': 18.0,
        'Chili Pepper': 20.0, 'Jalapeno': 30.0, 'Serrano Pepper': 35.0, 'Habanero': 40.0,
        'Poblano Pepper': 35.0, 'Zucchini': 10.0, 'Yellow Squash': 12.0, 'Pumpkin': 8.0,
        'Butternut Squash': 15.0, 'Acorn Squash': 15.0, 'Spaghetti Squash': 20.0,
        'Delicata Squash': 18.0, 'Kabocha Squash': 18.0, 'Okra': 20.0, 'Artichoke': 25.0,
        'Jerusalem Artichoke': 30.0, 'Baby Corn': 25.0, 'White Mushroom': 40.0,
        'Cremini Mushroom': 50.0, 'Portobello Mushroom': 60.0, 'Shiitake Mushroom': 80.0,
        'Oyster Mushroom': 70.0, 'Enoki Mushroom': 45.0, 'Morel Mushroom': 300.0,
        'Truffle': 800.0, 'Grape Leaves': 15.0, 'Water Chestnuts': 30.0,
      };
      return vegPrices[name] ?? 12.0;
    }

    // ==================== FRUITS ====================
    if (category == 'Fruits') {
      final Map<String, double> fruitPrices = {
        'Orange': 10.0, 'Lemon': 20.0, 'Lime': 15.0, 'Grapefruit': 15.0,
        'Mandarin': 12.0, 'Clementine': 15.0, 'Tangerine': 12.0, 'Pomelo': 25.0,
        'Bergamot': 30.0, 'Mango': 30.0, 'Guava': 15.0, 'Banana': 25.0,
        'Pineapple': 60.0, 'Papaya': 35.0, 'Dragon Fruit': 80.0, 'Passion Fruit': 50.0,
        'Lychee': 60.0, 'Rambutan': 70.0, 'Mangosteen': 100.0, 'Star Fruit': 40.0,
        'Kiwi': 50.0, 'Persimmon': 45.0, 'Coconut': 25.0, 'Peach': 25.0,
        'Nectarine': 30.0, 'Plum': 25.0, 'Apricot': 20.0, 'Cherry': 80.0,
        'Sour Cherry': 70.0, 'Apple': 40.0, 'Green Apple': 40.0, 'Pear': 45.0,
        'Asian Pear': 60.0, 'Quince': 30.0, 'Strawberry': 35.0, 'Blueberry': 120.0,
        'Raspberry': 130.0, 'Blackberry': 110.0, 'Cranberry': 100.0, 'Gooseberry': 80.0,
        'Elderberry': 90.0, 'Mulberry': 40.0, 'Watermelon': 15.0, 'Cantaloupe': 12.0,
        'Honeydew': 20.0, 'Galia Melon': 18.0, 'Pomegranate': 25.0, 'Fig': 30.0,
        'Date': 80.0, 'Medjool Date': 150.0, 'Deglet Noor Date': 100.0, 'Grape': 20.0,
        'Red Grape': 25.0, 'Green Grape': 20.0, 'Black Grape': 25.0, 'Jujube': 60.0,
        'Loquat': 35.0, 'Prickly Pear': 10.0, 'Medlar': 40.0, 'Raisins': 60.0,
        'Dried Apricots': 80.0, 'Dried Figs': 90.0, 'Dried Dates': 70.0,
        'Dried Cranberries': 100.0, 'Dried Cherries': 120.0, 'Prunes': 70.0,
      };
      return fruitPrices[name] ?? 20.0;
    }

    // ==================== LEGUMES ====================
    if (category == 'Legumes') {
      final Map<String, double> legumePrices = {
        'Green Beans': 15.0, 'Yellow Beans': 15.0, 'Fava Beans': 25.0, 'Chickpeas': 40.0,
        'Brown Lentils': 35.0, 'Red Lentils': 38.0, 'Green Lentils': 40.0, 'Black Lentils': 50.0,
        'French Lentils': 45.0, 'Yellow Lentils': 38.0, 'White Beans': 30.0, 'Kidney Beans': 35.0,
        'Black Beans': 40.0, 'Black Eyed Peas': 32.0, 'Split Peas': 30.0, 'Lupin Beans': 25.0,
        'Soybeans': 35.0, 'Edamame': 60.0, 'Mung Beans': 40.0, 'Adzuki Beans': 45.0,
        'Peas': 20.0, 'Snow Peas': 35.0, 'Sugar Snap Peas': 40.0,
      };
      return legumePrices[name] ?? 35.0;
    }

    // ==================== GRAINS ====================
    if (category == 'Grains') {
      final Map<String, double> grainPrices = {
        'White Rice': 25.0, 'Brown Rice': 35.0, 'Basmati Rice': 60.0, 'Jasmine Rice': 50.0,
        'Arborio Rice': 70.0, 'Sushi Rice': 55.0, 'Wild Rice': 120.0, 'Black Rice': 80.0,
        'Red Rice': 65.0, 'Whole Wheat': 15.0, 'Bulgur Wheat': 20.0, 'Couscous': 25.0,
        'Freekeh': 30.0, 'Farro': 45.0, 'Spelt': 40.0, 'Kamut': 50.0, 'Einkorn': 45.0,
        'Emmer Wheat': 45.0, 'Semolina': 15.0, 'Vermicelli': 20.0, 'Barley': 18.0,
        'Oats': 40.0, 'Rolled Oats': 35.0, 'Steel Cut Oats': 45.0, 'Quinoa': 120.0,
        'Red Quinoa': 130.0, 'Black Quinoa': 140.0, 'Amaranth': 80.0, 'Buckwheat': 50.0,
        'Millet': 25.0, 'Sorghum': 20.0, 'Teff': 90.0, 'Rye': 25.0, 'Triticale': 30.0,
        'All-Purpose Flour': 12.0, 'Bread Flour': 15.0, 'Cake Flour': 18.0, 'Pastry Flour': 16.0,
        'Whole Wheat Flour': 15.0, 'Almond Flour': 200.0, 'Coconut Flour': 150.0,
        'Chickpea Flour': 60.0, 'Rice Flour': 25.0, 'Corn Flour': 15.0, 'Cornmeal': 15.0,
        'Polenta': 25.0, 'Corn': 10.0, 'Spaghetti': 18.0, 'Penne': 18.0, 'Macaroni': 15.0,
        'Fettuccine': 20.0, 'Lasagna Noodles': 22.0, 'Orzo': 20.0, 'Ramen Noodles': 12.0,
        'Udon Noodles': 25.0, 'Soba Noodles': 35.0, 'Rice Noodles': 25.0,
      };
      return grainPrices[name] ?? 25.0;
    }

    // ==================== BREADS ====================
    if (category == 'Breads') {
      final Map<String, double> breadPrices = {
        'Pita Bread': 5.0, 'White Bread': 10.0, 'Whole Wheat Bread': 15.0, 'Sourdough Bread': 30.0,
        'Rye Bread': 25.0, 'Baguette': 15.0, 'Croissant': 20.0, 'Brioche': 35.0,
        'Ciabatta': 25.0, 'Focaccia': 30.0, 'English Muffin': 15.0, 'Bagel': 20.0,
      };
      return breadPrices[name] ?? 15.0;
    }

    // ==================== SPICES ====================
    if (category == 'Spices') {
      final Map<String, double> spicePrices = {
        'Cumin Seeds': 15.0, 'Coriander Seeds': 12.0, 'Black Peppercorns': 40.0,
        'White Peppercorns': 50.0, 'Green Peppercorns': 45.0, 'Cinnamon Sticks': 20.0,
        'Cinnamon Powder': 20.0, 'Cloves': 60.0, 'Green Cardamom': 120.0, 'Black Cardamom': 100.0,
        'Nutmeg': 80.0, 'Mace': 90.0, 'Turmeric Powder': 15.0, 'Turmeric Root': 25.0,
        'Saffron Threads': 450.0, 'Saffron Powder': 420.0, 'Ginger Root': 20.0,
        'Ginger Powder': 25.0, 'Fenugreek Seeds': 20.0, 'Star Anise': 50.0, 'Anise Seeds': 25.0,
        'Caraway Seeds': 25.0, 'Fennel Seeds': 20.0, 'Nigella Seeds': 35.0, 'Mustard Seeds': 20.0,
        'Brown Mustard Seeds': 20.0, 'Yellow Mustard Seeds': 18.0, 'Celery Seeds': 30.0,
        'Dill Seeds': 30.0, 'Cumin Powder': 18.0, 'Coriander Powder': 15.0, 'Paprika': 15.0,
        'Smoked Paprika': 25.0, 'Hot Paprika': 18.0, 'Chili Powder': 15.0, 'Cayenne Pepper': 18.0,
        'Red Pepper Flakes': 15.0, 'Black Pepper Powder': 35.0, 'White Pepper Powder': 45.0,
        'Curry Powder': 25.0, 'Sumac': 25.0,
      };
      return spicePrices[name] ?? 20.0;
    }

    // ==================== SPICE BLENDS ====================
    if (category == 'Spice Blends') {
      final Map<String, double> blendPrices = {
        'Garam Masala': 40.0, 'Baharat': 30.0, 'Ras El Hanout': 45.0, 'Za\'atar': 50.0,
      };
      return blendPrices[name] ?? 35.0;
    }

    // ==================== HERBS (COMPLETE) ====================
    if (category == 'Herbs') {
      final Map<String, double> herbPrices = {
        // Dried herbs (100g)
        'Dried Mint': 25.0, 'Dried Oregano': 30.0, 'Dried Thyme': 25.0,
        'Dried Rosemary': 35.0, 'Dried Basil': 30.0, 'Dried Parsley': 20.0,
        'Dried Cilantro': 25.0, 'Dried Dill': 28.0, 'Bay Leaves': 15.0,
        'Sage': 25.0, 'Marjoram': 25.0, 'Tarragon': 30.0, 'Savory': 25.0,
        'Lovage': 20.0, 'Lemon Verbena': 20.0, 'Lemongrass': 15.0,
        'Curry Leaves': 25.0, 'Kaffir Lime Leaves': 30.0, 'Fenugreek Leaves': 20.0,
        // Fresh herbs (bunch)
        'Fresh Mint': 5.0, 'Peppermint': 5.0, 'Spearmint': 5.0,
        'Fresh Basil': 10.0, 'Thai Basil': 12.0, 'Holy Basil': 10.0,
        'Fresh Parsley': 5.0, 'Flat Leaf Parsley': 6.0, 'Curly Parsley': 5.0,
        'Fresh Cilantro': 5.0, 'Fresh Dill': 7.0, 'Fresh Thyme': 6.0,
        'Lemon Thyme': 7.0, 'Fresh Rosemary': 8.0, 'Fresh Oregano': 7.0,
        'Greek Oregano': 8.0, 'Fresh Sage': 7.0, 'Fresh Marjoram': 7.0,
        'Fresh Tarragon': 8.0, 'Fresh Chives': 8.0, 'Fresh Chervil': 9.0,
        'Fresh Savory': 7.0,
      };
      return herbPrices[name] ?? 5.0;
    }

    // ==================== NUTS ====================
    if (category == 'Nuts') {
      final Map<String, double> nutPrices = {
        'Almonds': 220.0, 'Blanched Almonds': 230.0, 'Slivered Almonds': 240.0, 'Ground Almonds': 250.0,
        'Walnuts': 250.0, 'English Walnuts': 260.0, 'Black Walnuts': 300.0, 'Pecans': 300.0,
        'Hazelnuts': 260.0, 'Filberts': 260.0, 'Cashews': 280.0, 'Raw Cashews': 270.0,
        'Roasted Cashews': 290.0, 'Pistachios': 320.0, 'Shelled Pistachios': 340.0, 'Pine Nuts': 380.0,
        'Peanuts': 60.0, 'Raw Peanuts': 50.0, 'Roasted Peanuts': 65.0, 'Brazil Nuts': 350.0,
        'Macadamia Nuts': 450.0, 'Chestnuts': 120.0, 'Coconut Flakes': 80.0, 'Shredded Coconut': 75.0,
        'Desiccated Coconut': 70.0,
      };
      return nutPrices[name] ?? 200.0;
    }

    // ==================== SEEDS ====================
    if (category == 'Seeds') {
      final Map<String, double> seedPrices = {
        'Sesame Seeds': 40.0, 'White Sesame Seeds': 40.0, 'Black Sesame Seeds': 50.0,
        'Poppy Seeds': 80.0, 'Sunflower Seeds': 40.0, 'Pumpkin Seeds': 80.0,
        'Flax Seeds': 60.0, 'Chia Seeds': 150.0, 'Hemp Seeds': 180.0,
      };
      return seedPrices[name] ?? 70.0;
    }

    // ==================== DAIRY ====================
    if (category == 'Dairy') {
      final Map<String, double> dairyPrices = {
        'Milk': 25.0, 'Whole Milk': 28.0, 'Skim Milk': 25.0, 'Yogurt': 15.0,
        'Greek Yogurt': 30.0, 'Labneh': 40.0, 'Butter': 120.0, 'Ghee': 150.0,
        'Cream': 35.0, 'Heavy Cream': 50.0, 'Sour Cream': 40.0, 'Cream Cheese': 60.0,
        'Cheese': 80.0, 'Feta Cheese': 80.0, 'Halloumi Cheese': 120.0, 'Mozzarella Cheese': 100.0,
        'Parmesan Cheese': 200.0, 'Cheddar Cheese': 150.0, 'Ricotta Cheese': 70.0, 'Goat Cheese': 140.0,
        'Brie Cheese': 180.0, 'Camembert Cheese': 190.0, 'Gouda Cheese': 120.0,
        'Edam Cheese': 100.0, 'Provolone Cheese': 130.0, 'Manchego Cheese': 160.0,
        'Swiss Cheese': 140.0, 'Blue Cheese': 150.0, 'Roquefort Cheese': 180.0,
        'Gorgonzola Cheese': 160.0, 'Mascarpone Cheese': 120.0, 'Fontina Cheese': 140.0,
        'Asiago Cheese': 130.0, 'Monterey Jack Cheese': 110.0, 'Pepper Jack Cheese': 115.0,
        'Havarti Cheese': 125.0, 'Colby Jack Cheese': 105.0, 'Queso Fresco': 80.0, 'Paneer': 100.0,
      };
      return dairyPrices[name] ?? 50.0;
    }

    // ==================== DAIRY ALTERNATIVES ====================
    if (category == 'Dairy Alternatives') {
      final Map<String, double> altPrices = {
        'Almond Milk': 60.0, 'Soy Milk': 40.0, 'Oat Milk': 50.0, 'Coconut Milk': 35.0,
        'Rice Milk': 35.0, 'Cashew Milk': 55.0, 'Hemp Milk': 65.0, 'Macadamia Milk': 70.0,
      };
      return altPrices[name] ?? 50.0;
    }

    // ==================== EGGS ====================
    if (category == 'Eggs') {
      final Map<String, double> eggPrices = {
        'Eggs': 60.0, 'Egg Whites': 40.0, 'Egg Yolks': 35.0, 'Quail Eggs': 80.0, 'Duck Eggs': 100.0,
      };
      return eggPrices[name] ?? 60.0;
    }

    // ==================== MEAT ====================
    if (category == 'Meat') {
      final Map<String, double> meatPrices = {
        'Chicken': 120.0, 'Chicken Breast': 140.0, 'Chicken Thigh': 110.0,
        'Chicken Drumstick': 100.0, 'Chicken Wings': 80.0, 'Chicken Leg Quarters': 45.0,
        'Ground Chicken': 130.0, 'Chicken Liver': 40.0, 'Chicken Gizzards': 35.0,
        'Whole Chicken': 120.0, 'Cornish Hen': 90.0, 'Turkey': 140.0,
        'Turkey Breast': 160.0, 'Ground Turkey': 130.0, 'Turkey Thigh': 120.0,
        'Duck': 180.0, 'Duck Breast': 200.0, 'Quail': 120.0, 'Pigeon': 120.0, 'Goose': 250.0,
        'Beef': 250.0, 'Ground Beef': 220.0, 'Beef Steak': 280.0, 'Beef Roast': 260.0,
        'Beef Brisket': 200.0, 'Beef Ribeye': 350.0, 'Beef Sirloin': 300.0, 'Beef Tenderloin': 400.0,
        'Beef Chuck': 180.0, 'Beef Shank': 150.0, 'Beef Rump': 220.0, 'Beef Flank': 230.0,
        'Beef Short Ribs': 280.0, 'Beef Liver': 50.0, 'Beef Tongue': 120.0, 'Beef Heart': 80.0,
        'Beef Kidney': 60.0, 'Beef Tripe': 40.0, 'Beef Oxtail': 180.0, 'Beef Bones (for broth)': 30.0,
        'Veal': 300.0, 'Veal Cutlet': 320.0, 'Lamb': 300.0, 'Ground Lamb': 280.0,
        'Lamb Chops': 320.0, 'Lamb Shoulder': 250.0, 'Lamb Leg': 280.0, 'Lamb Rack': 400.0,
        'Lamb Shank': 220.0, 'Lamb Ribs': 240.0, 'Lamb Liver': 60.0, 'Lamb Brain': 70.0,
        'Lamb Kidneys': 65.0, 'Mutton': 260.0, 'Goat Meat': 180.0, 'Goat Chops': 200.0,
        'Ground Goat': 190.0, 'Rabbit': 150.0, 'Camel Meat': 200.0, 'Buffalo Meat': 220.0,
        'Venison (Deer)': 280.0, 'Halal Beef Sausage': 120.0, 'Halal Chicken Sausage': 100.0,
        'Halal Turkey Sausage': 110.0, 'Halal Beef Bacon': 150.0, 'Halal Turkey Bacon': 120.0,
        'Halal Pepperoni': 140.0, 'Halal Salami': 130.0, 'Halal Pastrami': 160.0,
        'Halal Hot Dogs': 80.0, 'Halal Beef Burger Patties': 100.0, 'Halal Chicken Nuggets': 90.0,
      };
      return meatPrices[name] ?? 200.0;
    }

    // ==================== SEAFOOD ====================
    if (category == 'Seafood') {
      final Map<String, double> seafoodPrices = {
        'Salmon': 350.0, 'Tilapia': 80.0, 'Sea Bass': 160.0, 'Sea Bream': 140.0,
        'Mullet': 100.0, 'Sardines': 40.0, 'Mackerel': 60.0, 'Tuna': 200.0,
        'Cod': 150.0, 'Haddock': 140.0, 'Halibut': 300.0, 'Trout': 120.0,
        'Catfish': 70.0, 'Snapper': 180.0, 'Grouper': 200.0, 'Sole': 130.0,
        'Flounder': 110.0, 'Shrimp': 220.0, 'Prawns': 280.0, 'Lobster': 450.0,
        'Crab': 150.0, 'Snow Crab': 250.0, 'King Crab': 400.0, 'Calamari': 180.0,
        'Squid': 160.0, 'Octopus': 200.0, 'Mussels': 60.0, 'Clams': 50.0,
        'Oysters': 80.0, 'Scallops': 200.0, 'Crayfish': 120.0, 'Anchovies': 30.0,
        'Swordfish': 250.0, 'Mahi Mahi': 220.0, 'Barramundi': 180.0, 'Eel': 150.0,
      };
      return seafoodPrices[name] ?? 120.0;
    }

    // ==================== OILS ====================
    if (category == 'Oils') {
      final Map<String, double> oilPrices = {
        'Olive Oil': 120.0, 'Extra Virgin Olive Oil': 180.0, 'Vegetable Oil': 40.0,
        'Canola Oil': 50.0, 'Sunflower Oil': 45.0, 'Corn Oil': 50.0, 'Sesame Oil': 80.0,
        'Coconut Oil': 120.0, 'Avocado Oil': 250.0, 'Grapeseed Oil': 100.0, 'Peanut Oil': 60.0,
        'Palm Oil': 35.0, 'Vinegar': 15.0, 'Apple Cider Vinegar': 40.0, 'White Vinegar': 10.0,
        'Balsamic Vinegar': 80.0, 'Red Wine Vinegar': 50.0, 'Rice Vinegar': 45.0,
      };
      return oilPrices[name] ?? 50.0;
    }

    // ==================== SWEETENERS ====================
    if (category == 'Sweeteners') {
      final Map<String, double> sweetenerPrices = {
        'Honey': 200.0, 'Sugar': 25.0, 'Brown Sugar': 35.0, 'Powdered Sugar': 30.0,
        'Date Syrup': 120.0, 'Pomegranate Molasses': 80.0, 'Maple Syrup': 250.0,
        'Agave Syrup': 150.0, 'Stevia': 100.0, 'Coconut Sugar': 60.0, 'Molasses': 40.0,
      };
      return sweetenerPrices[name] ?? 40.0;
    }

    // ==================== BROTHS ====================
    if (category == 'Broths') {
      final Map<String, double> brothPrices = {
        'Chicken Broth': 30.0, 'Beef Broth': 35.0, 'Vegetable Broth': 20.0,
        'Bone Broth': 50.0, 'Lamb Broth': 40.0,
      };
      return brothPrices[name] ?? 30.0;
    }

    // ==================== SAUCES (COMPLETE) ====================
    if (category == 'Sauces') {
      final Map<String, double> saucePrices = {
        'Tomato Sauce': 15.0, 'Tomato Paste': 10.0, 'Marinara Sauce': 25.0,
        'Alfredo Sauce': 40.0, 'Pesto Sauce': 60.0, 'BBQ Sauce': 35.0,
        'Hot Sauce': 20.0, 'Soy Sauce (Halal)': 25.0, 'Teriyaki Sauce (Halal)': 30.0,
        'Worcestershire Sauce (Halal)': 35.0, 'Mayonnaise': 30.0, 'Ketchup': 15.0,
        'Mustard': 15.0, 'Dijon Mustard': 25.0, 'Honey Mustard': 22.0,
        'Tahini': 40.0, 'Tzatziki Sauce': 35.0, 'Hollandaise Sauce': 45.0,
        'Béchamel Sauce': 25.0, 'Cheese Sauce': 35.0, 'Enchilada Sauce': 30.0,
        'Salsa': 18.0, 'Pico de Gallo': 15.0, 'Guacamole': 40.0,
        'Hummus': 35.0, 'Baba Ghanoush': 30.0, 'Muhammara': 35.0,
        'Toum (Garlic Sauce)': 20.0, 'Ranch Dressing': 25.0, 'Caesar Dressing': 28.0,
        'Thousand Island Dressing': 25.0, 'Vinaigrette': 18.0, 'Balsamic Vinaigrette': 22.0,
        'Curry Sauce': 35.0, 'Coconut Curry Sauce': 40.0, 'Sweet Chili Sauce': 20.0,
        'Plum Sauce': 18.0, 'Duck Sauce': 15.0, 'Harissa': 25.0,
        'Sriracha': 22.0, 'Chimichurri': 30.0,
      };
      return saucePrices[name] ?? 30.0;
    }

    // ==================== CANNED GOODS ====================
    if (category == 'Canned Goods') {
      final Map<String, double> cannedPrices = {
        'Canned Tuna': 40.0, 'Canned Salmon': 60.0, 'Canned Sardines': 25.0,
        'Canned Beans': 15.0, 'Canned Chickpeas': 15.0, 'Canned Lentils': 15.0,
        'Canned Corn': 12.0, 'Canned Tomatoes': 12.0, 'Canned Tomato Paste': 8.0,
        'Canned Coconut Milk': 25.0, 'Canned Pumpkin': 20.0, 'Canned Olives': 25.0,
        'Canned Mushrooms': 15.0,
      };
      return cannedPrices[name] ?? 20.0;
    }

    // ==================== BAKING ====================
    if (category == 'Baking') {
      final Map<String, double> bakingPrices = {
        'All-Purpose Flour': 12.0, 'Bread Flour': 15.0, 'Cake Flour': 18.0,
        'Pastry Flour': 16.0, 'Whole Wheat Flour': 15.0, 'Almond Flour': 200.0,
        'Coconut Flour': 150.0, 'Granulated Sugar': 25.0, 'Brown Sugar': 35.0,
        'Powdered Sugar': 30.0, 'Coconut Sugar': 60.0, 'Baking Powder': 15.0,
        'Baking Soda': 8.0, 'Yeast': 10.0, 'Active Dry Yeast': 12.0, 'Instant Yeast': 15.0,
        'Vanilla Extract': 50.0, 'Vanilla Bean': 80.0, 'Vanilla Powder': 45.0,
        'Almond Extract': 40.0, 'Lemon Extract': 35.0, 'Chocolate': 60.0,
        'Dark Chocolate': 70.0, 'Milk Chocolate': 55.0, 'White Chocolate': 65.0,
        'Chocolate Chips': 50.0, 'Cocoa Powder': 40.0, 'Unsweetened Cocoa Powder': 45.0,
        'Dutch Process Cocoa': 55.0, 'Unsalted Butter': 120.0, 'Margarine': 40.0,
        'Shortening': 35.0, 'Buttermilk': 30.0, 'Gelatin (Halal Beef)': 80.0,
        'Agar Agar': 100.0, 'Pectin': 60.0, 'Food Coloring': 30.0, 'Sprinkles': 25.0,
      };
      return bakingPrices[name] ?? 30.0;
    }

    // ==================== FROZEN FOODS ====================
    if (category == 'Frozen Foods') {
      final Map<String, double> frozenPrices = {
        'Frozen Mixed Vegetables': 25.0, 'Frozen Peas': 18.0, 'Frozen Corn': 15.0,
        'Frozen Broccoli': 22.0, 'Frozen Cauliflower': 20.0, 'Frozen Spinach': 18.0,
        'Frozen Green Beans': 20.0, 'Frozen French Fries': 25.0, 'Frozen Hash Browns': 22.0,
        'Frozen Mixed Berries': 60.0, 'Frozen Strawberries': 50.0, 'Frozen Mango': 55.0,
        'Frozen Pineapple': 45.0, 'Frozen Chicken Nuggets': 90.0, 'Frozen Chicken Wings': 80.0,
        'Frozen Beef Patties': 100.0, 'Frozen Fish Fillets': 70.0, 'Frozen Shrimp': 180.0,
        'Frozen Pizza': 50.0, 'Frozen Lasagna': 60.0, 'Frozen Spring Rolls': 40.0,
        'Frozen Samosas': 45.0, 'Ice Cream': 60.0, 'Frozen Yogurt': 50.0,
        'Frozen Dough': 25.0, 'Frozen Pie Crust': 30.0,
      };
      return frozenPrices[name] ?? 35.0;
    }

    // ==================== MIDDLE EASTERN ====================
    if (category == 'Middle Eastern') {
      final Map<String, double> middleEasternPrices = {
        'Rose Water': 25.0, 'Orange Blossom Water': 25.0, 'Mastic (Arabic Gum)': 80.0,
        'Rose Petals (Dried)': 40.0, 'Ashta (Clotted Cream)': 50.0, 'Kunafa Dough': 30.0,
        'Qatayef Dough': 25.0, 'Knafeh Noodles': 20.0, 'Halva (Halwa)': 60.0,
        'Baklava Phyllo Dough': 25.0, 'Dried Limes (Loomi)': 60.0, 'Rose Hip Syrup': 40.0,
        'Carob Molasses': 35.0,
      };
      return middleEasternPrices[name] ?? 40.0;
    }

    // ==================== ASIAN ====================
    if (category == 'Asian') {
      final Map<String, double> asianPrices = {
        'Halal Soy Sauce': 25.0, 'Miso Paste (Halal)': 45.0, 'Gochujang (Korean Chili Paste)': 50.0,
        'Tamarind Paste': 30.0, 'Tamarind Concentrate': 35.0, 'Halal Fish Sauce': 35.0,
        'Oyster Sauce (Halal)': 30.0, 'Hoisin Sauce (Halal)': 28.0, 'Sriracha Sauce': 40.0,
        'Mirin (Halal)': 35.0, 'Sake (Halal - No Alcohol)': 40.0, 'Dashi (Halal Kelp Broth)': 25.0,
        'Nori (Seaweed Sheets)': 30.0, 'Wakame Seaweed': 25.0, 'Kombu Seaweed': 28.0,
        'Panko Breadcrumbs': 25.0, 'Rice Paper': 20.0, 'Glass Noodles (Cellophane)': 20.0,
        'Galangal Root': 30.0, 'Pandan Leaves': 15.0, 'Thai Chili Peppers': 20.0,
        'Tofu (Firm)': 25.0, 'Tofu (Soft/Silken)': 22.0, 'Tempeh': 35.0,
      };
      return asianPrices[name] ?? 25.0;
    }

    // ==================== BREAKFAST (COMPLETE) ====================
    if (category == 'Breakfast') {
      final Map<String, double> breakfastPrices = {
        // Basic cereals
        'Corn Flakes': 40.0, 'Wheat Cereal': 45.0, 'Oatmeal': 35.0,
        'Granola': 60.0, 'Muesli': 55.0,
        // Brand cereals
        'Rice Krispies': 45.0, 'Froot Loops': 50.0, 'Frosted Flakes': 48.0,
        'Cocoa Puffs': 52.0, 'Cinnamon Toast Crunch': 50.0, 'Lucky Charms': 55.0,
        'Honey Bunches of Oats': 48.0, 'Special K': 55.0, 'Cheerios': 45.0,
        'Wheat Biscuits (Weetabix)': 40.0, 'Shredded Wheat': 38.0, 'Bran Flakes': 42.0,
        'Raisin Bran': 45.0, 'Cereal': 50.0,
        // Mixes
        'Pancake Mix': 25.0, 'Waffle Mix': 28.0, 'French Toast Mix': 22.0,
        // Spreads
        'Fruit Jam': 35.0, 'Nutella (Halal)': 80.0, 'Peanut Butter': 60.0,
        'Almond Butter': 100.0, 'Za\'atar with Olive Oil': 35.0,
      };
      return breakfastPrices[name] ?? 30.0;
    }

    // ==================== SNACKS (COMPLETE) ====================
    if (category == 'Snacks') {
      final Map<String, double> snackPrices = {
        // Chips
        'Potato Chips': 15.0, 'Tortilla Chips': 20.0, 'Pretzels': 18.0,
        'Crackers': 12.0, 'Saltine Crackers': 10.0, 'Graham Crackers': 15.0,
        'Rice Cakes': 15.0,
        // Popcorn
        'Popcorn': 10.0, 'Microwave Popcorn': 15.0,
        // Cheese snacks
        'Cheese Puffs': 18.0, 'Doritos': 20.0, 'Cheetos': 18.0, 'Pringles': 25.0,
        // Bars
        'Granola Bars': 25.0, 'Protein Bars': 35.0, 'Energy Bars': 30.0,
        // Mixes
        'Trail Mix': 50.0, 'Dried Fruits Mix': 40.0, 'Roasted Chickpeas': 30.0,
        'Vegetable Chips': 25.0, 'Kale Chips': 35.0,
        // Jerky
        'Beef Jerky (Halal)': 80.0, 'Turkey Jerky (Halal)': 75.0,
        // Nuts & Seeds
        'Nuts Mix': 50.0, 'Sunflower Seeds': 15.0, 'Pumpkin Seeds': 20.0,
        // Cookies
        'Cookies': 25.0, 'Chocolate Chip Cookies': 25.0, 'Oreo Cookies': 22.0,
        'Digestive Biscuits': 18.0, 'Wafer Cookies': 15.0,
        // Candy & Sweets
        'Chocolate Bars': 20.0, 'Candy': 15.0, 'Gummy Bears': 15.0,
        'Lollipops': 10.0, 'Gum': 5.0, 'Mints': 5.0, 'Cinnamon Mints': 8.0,
        'Fruit Snacks': 12.0, 'Fruit Roll-Ups': 10.0, 'Rice Krispies Treats': 18.0,
        'Pop-Tarts': 25.0, 'Pudding Cups': 12.0, 'Yogurt Tubes': 15.0,
        'Cheese Sticks': 20.0, 'Hummus Snack Pack': 15.0,
      };
      return snackPrices[name] ?? 20.0;
    }

    // ==================== BEVERAGES (COMPLETE) ====================
    if (category == 'Beverages') {
      final Map<String, double> beveragePrices = {
        // Water
        'Sparkling Water': 10.0, 'Tonic Water': 12.0, 'Coconut Water': 20.0,
        'Aloe Vera Juice': 25.0,
        // Juices
        'Orange Juice': 25.0, 'Apple Juice': 20.0, 'Grape Juice': 22.0,
        'Cranberry Juice': 30.0, 'Grapefruit Juice': 25.0, 'Pineapple Juice': 28.0,
        'Pomegranate Juice': 35.0, 'Mango Juice': 30.0, 'Peach Juice': 25.0,
        'Carrot Juice': 15.0, 'Beet Juice': 18.0, 'Celery Juice': 15.0,
        'Lemonade': 15.0, 'Watermelon Juice': 12.0,
        // Soft Drinks
        'Soda': 8.0, 'Cola': 8.0, 'Diet Soda': 8.0, 'Ginger Ale': 10.0,
        'Root Beer': 12.0,
        // Energy & Sports
        'Energy Drink': 25.0, 'Sports Drink': 20.0,
        // Coffee
        'Coffee Beans': 60.0, 'Ground Coffee': 50.0, 'Instant Coffee': 40.0,
        'Turkish Coffee': 35.0, 'Arabic Coffee (Qahwa)': 40.0, 'Decaf Coffee': 55.0,
        'Cold Brew Coffee': 45.0,
        // Tea
        'Tea Bags': 20.0, 'Loose Leaf Tea': 25.0, 'Black Tea': 18.0,
        'Green Tea': 22.0, 'Matcha Powder': 80.0, 'White Tea': 30.0,
        'Oolong Tea': 28.0, 'Chai Tea': 25.0, 'Rooibos Tea': 24.0,
        'Yerba Mate': 35.0, 'Kombucha': 30.0, 'Herbal Tea': 20.0,
        'Chamomile Tea': 25.0, 'Peppermint Tea': 20.0, 'Hibiscus Tea (Karkadeh)': 15.0,
        // Hot Drinks
        'Hot Chocolate Mix': 25.0, 'Sahlab (Salep)': 30.0,
        // Middle Eastern Drinks
        'Tamr Hindi (Tamarind Drink)': 12.0, 'Sobia (Egyptian Coconut Drink)': 15.0,
        'Erq Soos (Liquorice Drink)': 10.0, 'Fresh Sugarcane Juice': 8.0,
        'Horchata': 18.0,
        // Plant-based Milks
        'Almond Milk': 60.0, 'Soy Milk': 40.0, 'Oat Milk': 50.0,
        'Coconut Milk': 35.0, 'Rice Milk': 35.0, 'Cashew Milk': 55.0,
        'Hemp Milk': 65.0, 'Macadamia Milk': 70.0,
        // Smoothie Ingredients
        'Smoothie': 30.0, 'Acai Berry': 45.0,
        // Syrups
        'Simple Syrup': 15.0, 'Grenadine': 20.0, 'Rose Syrup': 25.0,
        'Mint Syrup': 22.0, 'Caramel Syrup': 25.0, 'Vanilla Syrup': 25.0,
        'Hazelnut Syrup': 28.0, 'Chocolate Syrup': 22.0,
        // Powdered Mixes
        'Lemonade Powder': 12.0, 'Iced Tea Mix': 15.0, 'Orange Drink Mix': 10.0,
        // Protein & Nutritional
        'Whey Protein': 80.0, 'Plant Protein Powder': 90.0, 'Meal Replacement Shake': 50.0,
        'Protein Shake Mix': 80.0, 'Green Powder': 60.0, 'Spirulina Powder': 50.0,
        'Wheatgrass Powder': 45.0, 'Maca Powder': 40.0, 'Cacao Nibs': 35.0,
      };
      return beveragePrices[name] ?? 15.0;
    }

    // Default fallback price
    return 30.0;
  }

  /// Get Egyptian unit based on category
  String _getEgyptianUnit(CompleteHalalIngredient ingredient) {
    final category = ingredient.category;
    final name = ingredient.name;

    // Special cases
    if (name == 'Saffron Threads' || name == 'Saffron Powder') return 'gram';
    if (category == 'Spices' || category == 'Spice Blends') return '100g';
    if (category == 'Herbs' && !name.contains('Dried')) return 'bunch';
    if (category == 'Herbs' && name.contains('Dried')) return '100g';
    if (category == 'Eggs') return 'dozen';
    if (category == 'Breads') return 'loaf';
    if (category == 'Oils' && name.contains('Vinegar')) return 'liter';
    if (category == 'Oils') return 'liter';
    if (category == 'Sweeteners' && (name.contains('Syrup') || name.contains('Molasses'))) return 'liter';
    if (category == 'Sweeteners' && name == 'Honey') return 'kg';
    if (category == 'Broths') return 'liter';
    if (category == 'Canned Goods') return 'can';

    // Baking
    if (category == 'Baking') {
      if (name.contains('Flour') || name.contains('Sugar')) return 'kg';
      if (name.contains('Extract') || name.contains('Vanilla')) return '50ml';
      if (name.contains('Powder') && (name.contains('Baking') || name.contains('Cocoa'))) return '100g';
      if (name.contains('Chocolate')) return '100g';
      if (name.contains('Butter') || name.contains('Margarine')) return '200g';
      return '500g';
    }

    // Frozen Foods
    if (category == 'Frozen Foods') {
      if (name.contains('Ice Cream') || name.contains('Frozen Yogurt')) return 'liter';
      return '400g';
    }

    // Middle Eastern
    if (category == 'Middle Eastern') {
      if (name.contains('Water')) return '250ml';
      if (name.contains('Paste') || name.contains('Dough')) return '300g';
      return '200g';
    }

    // Asian
    if (category == 'Asian') {
      if (name.contains('Sauce') || name.contains('Paste')) return '300ml';
      if (name.contains('Tofu')) return '300g';
      return '250g';
    }

    // Sauces
    if (category == 'Sauces') {
      if (name.contains('Dressing') || name.contains('Vinaigrette')) return '250ml';
      if (name.contains('Paste') || name.contains('Guacamole') || name.contains('Hummus')) return '200g';
      return '300ml';
    }

    // Breakfast
    if (category == 'Breakfast') {
      if (name.contains('Cereal') || name == 'Granola' || name == 'Muesli') return '400g';
      if (name.contains('Mix')) return '500g';
      if (name.contains('Jam') || name.contains('Butter')) return '200g';
      return '250g';
    }

    // Snacks
    if (category == 'Snacks') {
      if (name.contains('Chips') || name.contains('Crackers')) return '100g';
      if (name.contains('Bars')) return '40g';
      if (name.contains('Jerky')) return '50g';
      if (name.contains('Cookies') || name.contains('Oreo')) return '150g';
      if (name.contains('Pringles')) return '150g';
      if (name.contains('Popcorn')) return '100g';
      if (name.contains('Gum') || name.contains('Mints')) return 'pack';
      return '100g';
    }

    // Beverages
    if (category == 'Beverages') {
      if (name.contains('Juice') || name.contains('Soda') || name.contains('Water')) return 'liter';
      if (name.contains('Coffee') || name.contains('Tea')) return '200g';
      if (name.contains('Powder') || name.contains('Mix')) return '250g';
      if (name.contains('Syrup')) return '250ml';
      if (name.contains('Protein') || name.contains('Maca') || name.contains('Spirulina')) return '300g';
      return '500ml';
    }

    // Main categories switch
    switch (category) {
      case 'Vegetables':
        const vegHeads = {'Lettuce', 'Cabbage', 'Cauliflower', 'Broccoli'};
        const vegBunches = {'Parsley', 'Cilantro', 'Dill', 'Mint'};
        if (vegHeads.contains(name)) return 'head';
        if (vegBunches.contains(name)) return 'bunch';
        return 'kg';
      case 'Fruits':
        return name == 'Coconut' ? 'each' : 'kg';
      case 'Legumes':
      case 'Grains':
      case 'Nuts':
      case 'Seeds':
      case 'Meat':
      case 'Seafood':
        return 'kg';
      case 'Dairy':
        if (name == 'Milk') return 'liter';
        if (name == 'Yogurt' || name == 'Labneh') return '500g';
        if (name == 'Butter' || name == 'Ghee') return 'kg';
        if (name.contains('Cheese')) return 'kg';
        return 'kg';
      case 'Dairy Alternatives':
        return 'liter';
      default:
        return 'kg';
    }
  }

  /// Get numeric value for unit
  double _getUnitValue(String unit) {
    switch (unit) {
      case 'kg': return 1.0;
      case 'gram': return 0.001;
      case '100g': return 0.1;
      case '500g': return 0.5;
      case 'liter': return 1.0;
      case '500ml': return 0.5;
      case '250ml': return 0.25;
      case 'can': return 0.4;
      case 'bunch': return 0.2;
      case 'head': return 0.5;
      case 'dozen': return 12.0;
      case 'loaf': return 0.5;
      case 'each': return 1.0;
      case '40g': return 0.04;
      case '50g': return 0.05;
      case '50ml': return 0.05;
      case '150g': return 0.15;
      case '200g': return 0.2;
      case '250g': return 0.25;
      case '300g': return 0.3;
      case '400g': return 0.4;
      case 'pack': return 1.0;
      default: return 1.0;
    }
  }

  /// Convert ingredient to Firestore map
  Map<String, dynamic> _ingredientToMap(CompleteHalalIngredient ingredient, {String? imageUrl}) {
    final id = _generateId(ingredient.name);
    final price = _getEgyptianPrice(ingredient);
    final unit = _getEgyptianUnit(ingredient);
    final finalImageUrl = imageUrl ?? _generateImageUrl(ingredient);

    return {
      'id': id,
      'name': ingredient.name,
      'nameArabic': ingredient.nameArabic,
      'category': ingredient.category,
      'categoryArabic': ingredient.categoryArabic,
      'isHalal': ingredient.isHalal,
      'halalStatusNote': ingredient.halalStatusNote,
      'commonUses': ingredient.commonUses,
      'season': ingredient.season,
      'region': ingredient.region,
      'imageKeyword': ingredient.imageKeyword,
      'imageUrl': finalImageUrl,
      'searchQuery': _generateSearchQuery(ingredient),
      'price': price,
      'currency': 'EGP',
      'unit': unit,
      'formattedPrice': '${price.toStringAsFixed(2)} EGP',
      'pricePerUnit': price / _getUnitValue(unit),
      'country': 'Egypt',
      'market': 'Local Egyptian Market',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'quantity': 1.0,
      'isChecked': false,
    };
  }

  /// Upload ALL ingredients to Firestore
  Future<UploadResult> uploadAllIngredients({
    Map<String, String>? customImageUrls,
    int batchSize = 50,
    Function(int current, int total)? onProgress,
  }) async {
    final ingredients = CompleteHalalIngredientsDatabase.getAllIngredients();
    final total = ingredients.length;
    print('🇪🇬 Starting upload of $total ingredients to $_collectionName...');

    // Print category breakdown
    final categoryCounts = <String, int>{};
    for (var ing in ingredients) {
      categoryCounts[ing.category] = (categoryCounts[ing.category] ?? 0) + 1;
    }
    print('📊 Category breakdown:');
    categoryCounts.forEach((cat, count) {
      print('   $cat: $count');
    });

    // Test write access first
    try {
      final testRef = _firestore.collection(_collectionName).doc('_test_write');
      await testRef.set({'test': true, 'timestamp': FieldValue.serverTimestamp()});
      await testRef.delete();
      print('✅ Firestore write access confirmed');
    } catch (e) {
      print('❌ Firestore write error: $e');
      return UploadResult(successCount: 0, failCount: total, errors: ['Firestore write access denied: $e']);
    }

    int successCount = 0;
    int failCount = 0;
    List<String> errors = [];

    for (var i = 0; i < ingredients.length; i += batchSize) {
      final end = (i + batchSize) < ingredients.length ? i + batchSize : ingredients.length;
      final batch = _firestore.batch();

      for (var j = i; j < end; j++) {
        final ingredient = ingredients[j];
        final id = _generateId(ingredient.name);

        String? customImageUrl;
        if (customImageUrls != null && customImageUrls.containsKey(ingredient.name)) {
          customImageUrl = customImageUrls[ingredient.name];
        }

        final data = _ingredientToMap(ingredient, imageUrl: customImageUrl);
        final docRef = _firestore.collection(_collectionName).doc(id);
        batch.set(docRef, data);
      }

      try {
        await batch.commit();
        successCount += (end - i);
        print('✅ Batch ${(i / batchSize).ceil()}: ${end - i} ingredients ($successCount/$total)');
        if (onProgress != null) onProgress(successCount, total);
      } catch (e) {
        failCount += (end - i);
        errors.add('Batch ${(i / batchSize).ceil()} failed: $e');
        print('❌ Failed batch: $e');
      }
    }

    print('\n🎉 UPLOAD COMPLETE!');
    print('✅ Success: $successCount | ❌ Failed: $failCount | 📊 Total: $total');

    return UploadResult(
      successCount: successCount,
      failCount: failCount,
      errors: errors,
    );
  }

  /// Check if collection is populated
  Future<bool> isCollectionPopulated() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).limit(1).get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking collection: $e');
      return false;
    }
  }

  /// Get ingredient count
  Future<int> getIngredientCount() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting count: $e');
      return 0;
    }
  }
}

/// Upload result class
class UploadResult {
  final int successCount;
  final int failCount;
  final List<String> errors;

  UploadResult({
    required this.successCount,
    required this.failCount,
    this.errors = const [],
  });

  bool get isSuccess => failCount == 0;
}