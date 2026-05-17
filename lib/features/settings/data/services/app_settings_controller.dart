import 'package:flutter/foundation.dart';

class AppSettingsController {
  AppSettingsController._();

  static final ValueNotifier<bool> darkModeEnabled = ValueNotifier<bool>(false);

  static void setDarkMode(bool enabled) {
    if (darkModeEnabled.value == enabled) return;
    darkModeEnabled.value = enabled;
  }
}
