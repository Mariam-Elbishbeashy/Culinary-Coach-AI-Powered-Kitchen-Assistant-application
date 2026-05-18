// ignore_for_file: deprecated_member_use

import 'package:culinary_coach_app/app/app.dart';
import 'package:culinary_coach_app/firebase_options.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();
  // ProviderScope turns on riverpod for the full app
  // if we remove it, providers will not work anywhere
  runApp(const ProviderScope(child: SmartChefApp()));
}

Future<void> _initializeFirebase() async {
  if (kIsWeb) return;

  if (defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // App Check only in release. Do not activate in debug/profile (no debug
    // provider). Register the app in Firebase Console before enforcing App Check.
    if (kReleaseMode) {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.appAttest,
      );
    }
  }
}
