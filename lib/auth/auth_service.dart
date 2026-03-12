import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();

  static GoTrueClient get _auth => Supabase.instance.client.auth;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: const String.fromEnvironment(
      'GOOGLE_WEB_CLIENT_ID',
      defaultValue:
          '187361659101-t4ddosvvllvpbln81olnnf73ql62euqv.apps.googleusercontent.com',
    ),
  );

  static Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.signUp(email: email, password: password);
  }

  static Future<void> sendPasswordResetEmail(String email) async {
    await _auth.resetPasswordForEmail(
      email,
      redirectTo: kIsWeb ? null : 'io.supabase.flutter://login-callback/',
    );
  }

  static Future<void> updatePassword(String newPassword) async {
    await _auth.updateUser(UserAttributes(password: newPassword));
  }

  static Future<void> verifyRecoveryOtp({
    required String email,
    required String token,
  }) async {
    await _auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.recovery,
    );
  }

  static Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      await _auth.signInWithOAuth(OAuthProvider.google);
      return;
    }

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw const AuthException('Google sign-in was cancelled.');
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('Google sign-in failed: missing ID token.');
    }

    await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: googleAuth.accessToken,
    );
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore Google local sign-out errors and continue Supabase sign-out.
    }
    await _auth.signOut();
  }
}
