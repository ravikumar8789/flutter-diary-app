import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/error_models.dart';
import '../services/error_logging_service.dart';
import '../services/premium_service.dart';
import '../services/timezone_service.dart';

import 'premium_provider.dart';

// FIXED: Add StreamController to force stream updates
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

class AuthRepository {
  final _supabase = Supabase.instance.client;
  final _authStreamController = StreamController<AuthState>.broadcast();

  AuthRepository() {
    // FIXED: Emit initial state immediately
    final currentSession = _supabase.auth.currentSession;
    _authStreamController.add(
      AuthState(
        currentSession != null
            ? AuthChangeEvent.signedIn
            : AuthChangeEvent.signedOut,
        currentSession,
      ),
    );

    // Listen to Supabase auth changes and forward them
    _supabase.auth.onAuthStateChange.listen((authState) {
      _authStreamController.add(authState);
    });
  }

  User? get currentUser => _supabase.auth.currentUser;

  // FIXED: Use our controlled stream instead of direct Supabase stream
  Stream<AuthState> authStateChanges() => _authStreamController.stream;

  Future<void> signOut() async {
    await _supabase.auth.signOut();

    // FIXED: MANUALLY trigger auth state change after signout
    _authStreamController.add(AuthState(AuthChangeEvent.signedOut, null));
  }

  void dispose() {
    _authStreamController.close();
  }
}

// FIXED: Current user provider that actually works
final currentUserProvider = StreamProvider<User?>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);

  // Create a stream that emits the current user immediately, then listens to changes
  return Stream<User?>.value(authRepo.currentUser).asyncExpand((_) {
    return authRepo.authStateChanges().map((authState) {
      return authState.session?.user;
    });
  });
});

// FIXED: Simple auth controller
final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref);
});

class AuthController {
  final Ref _ref;
  AuthController(this._ref);

  Future<void> signUp(
    String email,
    String password, {
    String? displayName,
    String? gender,
  }) async {
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName, 'gender': gender},
      );

      // Initialize timezone after successful signup
      if (response.user != null) {
        // Don't await - let it run in background
        TimezoneService.initializeUserTimezone(response.user!.id).catchError((
          e,
        ) {
          // Log but don't block signup
          ErrorLoggingService.logLowError(
            error: ErrorContext.fromException(
              errorCode: 'ERRSYS162',
              severity: ErrorSeverity.low,
              exception: e,
              stackTrace: StackTrace.current,
              errorContext: {
                'user_id': response.user!.id,
                'operation': 'signup_timezone_init',
              },
            ),
          );
          return 'UTC'; // Return fallback value
        });
      }
    } catch (e) {
      // Log error
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS130',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'email': email,
            'display_name': displayName,
            'gender': gender,
            'operation': 'auth_provider_sign_up',
          },
        ),
      );
      rethrow;
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        await PremiumService.logIn(response.user!.id);
      }
    } catch (e) {
      // Log error
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS131',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {'email': email, 'operation': 'auth_provider_sign_in'},
        ),
      );
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await PremiumService.logOut();
      await _ref.read(authRepositoryProvider).signOut();
      _ref.invalidate(premiumProvider);
    } catch (e) {
      // Log error
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS132',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {'operation': 'auth_provider_sign_out'},
        ),
      );
      rethrow;
    }
  }
}
