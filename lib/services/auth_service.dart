import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class AuthService {
  static final supabase.SupabaseClient _client =
      supabase.Supabase.instance.client;

  // Get current user
  static supabase.User? get currentUser => _client.auth.currentUser;

  // Get current session
  static supabase.Session? get currentSession => _client.auth.currentSession;

  // Check if user is authenticated
  static bool get isAuthenticated => currentUser != null;

  // Auth state stream
  static Stream<supabase.AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  // Sign in with email and password
  static Future<supabase.AuthResponse> signIn(
    String email,
    String password,
  ) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null && response.user!.emailConfirmedAt == null) {
        throw Exception('Please verify your email before signing in');
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Sign up with email and password
  static Future<supabase.AuthResponse> signUp(
    String email,
    String password, {
    String? displayName,
    String? gender,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName, 'gender': gender},
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // Reset password
  static Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }

  // Resend email verification
  static Future<void> resendVerification(String email) async {
    try {
      await _client.auth.resend(type: supabase.OtpType.signup, email: email);
    } catch (e) {
      rethrow;
    }
  }
}
