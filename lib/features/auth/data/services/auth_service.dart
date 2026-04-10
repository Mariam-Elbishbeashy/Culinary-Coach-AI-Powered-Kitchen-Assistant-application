import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;
}

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  // Web client ID from Firebase google-services.json (client_type: 3).
  // Passing it explicitly avoids runtime lookup failures on some setups.
  static const String _androidServerClientId =
      '308730893669-dph9hlvnglp8m9n356qph85sd5bnkog3.apps.googleusercontent.com';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static bool _isGoogleInitialized = false;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final resolvedEmail = credential.user?.email ?? email;
      final split = _splitName(
        credential.user?.displayName ?? _fallbackNameFromEmail(resolvedEmail),
      );
      await _saveUserRecordSafely(
        uid: credential.user?.uid,
        firstName: split.firstName,
        lastName: split.lastName,
        email: resolvedEmail,
        birthDate: null,
        gender: null,
        authProvider: _resolveAuthProvider(credential.user),
        overwriteNames: false,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapAuthError(e));
    } catch (_) {
      throw const AuthFailure('Something went wrong. Please try again.');
    }
  }

  Future<UserCredential> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final displayName = '$firstName $lastName'.trim();
      await credential.user?.updateDisplayName(displayName);
      await _saveUserRecordSafely(
        uid: credential.user?.uid,
        firstName: firstName,
        lastName: lastName,
        email: email,
        birthDate: null,
        gender: null,
        authProvider: 'password',
        overwriteNames: true,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapAuthError(e));
    } catch (_) {
      throw const AuthFailure('Something went wrong. Please try again.');
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapAuthError(e));
    } catch (_) {
      throw const AuthFailure('Could not send reset email. Please try again.');
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      await _initializeGoogleSignInIfNeeded();
      final googleUser = await _googleSignIn.authenticate();

      final googleAuth = googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw const AuthFailure('Google sign-in failed. Missing ID token.');
      }
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final split = _splitName(userCredential.user?.displayName ?? 'Chef');
      await _saveUserRecordSafely(
        uid: userCredential.user?.uid,
        firstName: split.firstName,
        lastName: split.lastName,
        email: userCredential.user?.email ?? '',
        birthDate: null,
        gender: null,
        authProvider: 'google',
        overwriteNames: false,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapAuthError(e));
    } on GoogleSignInException catch (e) {
      throw AuthFailure(_mapGoogleSignInError(e));
    } on AuthFailure {
      rethrow;
    } catch (e) {
      throw AuthFailure('Google sign-in failed: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapAuthError(e));
    } catch (_) {
      throw const AuthFailure('Could not sign out. Please try again.');
    }

    // Google sign-out should not block app logout if it fails.
    if (_isGoogleInitialized) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Intentionally ignored.
      }
    }
  }

  Future<void> ensureUserRecordForCurrentSession() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final resolvedEmail = user.email ?? '';
    final split = _splitName(user.displayName ?? _fallbackNameFromEmail(resolvedEmail));
    await _saveUserRecordSafely(
      uid: user.uid,
      firstName: split.firstName,
      lastName: split.lastName,
      email: resolvedEmail,
      birthDate: null,
      gender: null,
      authProvider: _resolveAuthProvider(user),
      overwriteNames: false,
    );
  }

  Future<void> _initializeGoogleSignInIfNeeded() async {
    if (_isGoogleInitialized) return;
    await _googleSignIn.initialize(serverClientId: _androidServerClientId);
    _isGoogleInitialized = true;
  }

  Future<void> _saveUserRecord({
    required String? uid,
    required String? firstName,
    required String? lastName,
    required String email,
    required DateTime? birthDate,
    required String? gender,
    required String authProvider,
    required bool overwriteNames,
  }) async {
    if (uid == null || uid.isEmpty) return;

    final doc = _firestore.collection('users').doc(uid);
    final existing = await doc.get();
    final existingData = existing.data() ?? const <String, dynamic>{};
    final payload = <String, dynamic>{
      'uid': uid,
      'email': email,
      'birthDate': birthDate == null ? null : Timestamp.fromDate(birthDate),
      'gender': gender,
      'authProvider': authProvider,
      'updatedAt': FieldValue.serverTimestamp(),
      'fullName': FieldValue.delete(),
    };

    final shouldSetFirstName =
        overwriteNames || !existingData.containsKey('firstName');
    final shouldSetLastName = overwriteNames || !existingData.containsKey('lastName');

    if (shouldSetFirstName) {
      payload['firstName'] = (firstName == null || firstName.trim().isEmpty)
          ? null
          : firstName.trim();
    }
    if (shouldSetLastName) {
      payload['lastName'] = (lastName == null || lastName.trim().isEmpty)
          ? null
          : lastName.trim();
    }

    await doc.set(payload, SetOptions(merge: true));
  }

  Future<void> _saveUserRecordSafely({
    required String? uid,
    required String? firstName,
    required String? lastName,
    required String email,
    required DateTime? birthDate,
    required String? gender,
    required String authProvider,
    required bool overwriteNames,
  }) async {
    try {
      await _saveUserRecord(
        uid: uid,
        firstName: firstName,
        lastName: lastName,
        email: email,
        birthDate: birthDate,
        gender: gender,
        authProvider: authProvider,
        overwriteNames: overwriteNames,
      );
    } catch (_) {
      // Non-blocking: auth flow should continue even if Firestore sync fails.
    }
  }

  String _resolveAuthProvider(User? user) {
    if (user == null) return 'password';
    for (final provider in user.providerData) {
      if (provider.providerId != 'firebase' && provider.providerId.isNotEmpty) {
        return provider.providerId;
      }
    }
    return 'password';
  }

  String _fallbackNameFromEmail(String email) {
    final localPart = email.split('@').first.trim();
    if (localPart.isEmpty) return 'Chef';
    final words = localPart
        .split(RegExp(r'[._-]+'))
        .where((part) => part.trim().isNotEmpty)
        .map((part) {
          final value = part.trim();
          if (value.isEmpty) return value;
          return value[0].toUpperCase() + value.substring(1).toLowerCase();
        })
        .toList();
    if (words.isEmpty) return 'Chef';
    return words.join(' ');
  }

  ({String? firstName, String? lastName}) _splitName(String rawName) {
    final value = rawName.trim();
    if (value.isEmpty) return (firstName: null, lastName: null);
    final parts = value.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return (firstName: null, lastName: null);
    if (parts.length == 1) return (firstName: parts.first, lastName: null);
    return (
      firstName: parts.first,
      lastName: parts.sublist(1).join(' '),
    );
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email format is invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'network-request-failed':
        return 'No internet connection. Check your network.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  String _mapGoogleSignInError(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Google sign-in was cancelled.';
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google Sign-In is not configured correctly in Firebase/Android setup.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google sign-in UI is unavailable right now. Try again.';
      case GoogleSignInExceptionCode.interrupted:
        return 'Google sign-in was interrupted. Please retry.';
      default:
        final details = e.description?.trim();
        if (details != null && details.isNotEmpty) {
          return 'Google sign-in failed: $details';
        }
        return 'Google sign-in failed. Please try again.';
    }
  }
}
