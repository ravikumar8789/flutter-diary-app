import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName, 'gender': gender},
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _ref.read(authRepositoryProvider).signOut();
    } catch (e) {
      rethrow;
    }
  }
}
