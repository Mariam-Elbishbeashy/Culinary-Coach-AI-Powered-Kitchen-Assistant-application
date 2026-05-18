import 'package:flutter_riverpod/flutter_riverpod.dart';

// think of this as a shared variable for the whole app
// it stores true/false for dark mode in one central place
// any screen can read it, and any screen can update it
final darkModeProvider = StateProvider<bool>((ref) => false);
