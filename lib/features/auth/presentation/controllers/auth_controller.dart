import 'package:culinary_coach_app/features/auth/data/services/auth_service.dart';
import 'package:flutter/foundation.dart';

class AuthController extends ChangeNotifier {
  AuthController({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> login({required String email, required String password}) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.signIn(email: email.trim(), password: password.trim());
      return true;
    } on AuthFailure catch (e) {
      _setError(e.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String confirmPassword,
    required String firstName,
    required String lastName,
  }) async {
    final emailValue = email.trim();
    final passwordValue = password.trim();
    final confirmPasswordValue = confirmPassword.trim();
    final firstNameValue = firstName.trim();
    final lastNameValue = lastName.trim();

    if (firstNameValue.isEmpty || lastNameValue.isEmpty) {
      _setError('Please enter first name and last name.');
      return false;
    }
    if (emailValue.isEmpty ||
        passwordValue.isEmpty ||
        confirmPasswordValue.isEmpty) {
      _setError('Please fill in all fields.');
      return false;
    }
    if (passwordValue != confirmPasswordValue) {
      _setError('Passwords do not match.');
      return false;
    }

    _setLoading(true);
    _setError(null);
    try {
      await _authService.signUp(
        firstName: firstNameValue,
        lastName: lastNameValue,
        email: emailValue,
        password: passwordValue,
      );
      return true;
    } on AuthFailure catch (e) {
      _setError(e.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.signInWithGoogle();
      return true;
    } on AuthFailure catch (e) {
      _setError(e.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.signOut();
    } on AuthFailure catch (e) {
      _setError(e.message);
    } catch (_) {
      _setError('Could not sign out. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    final value = email.trim();
    if (value.isEmpty) {
      _setError('Please enter your email first.');
      return false;
    }

    _setLoading(true);
    _setError(null);
    try {
      await _authService.sendPasswordResetEmail(email: value);
      return true;
    } on AuthFailure catch (e) {
      _setError(e.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void clearError() => _setError(null);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }
}
