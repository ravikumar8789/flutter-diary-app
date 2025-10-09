import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import '../providers/auth_provider.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);

    print('🔄 AuthWrapper rebuilding...');

    return currentUserAsync.when(
      data: (user) {
        print('🎯 AuthWrapper Decision - User: ${user?.email ?? "NULL"}');

        if (user != null) {
          print('🏠 Navigating to HomeScreen');
          return const HomeScreen();
        } else {
          print('🔑 Navigating to LoginScreen');
          return const LoginScreen();
        }
      },
      loading: () {
        print('⏳ AuthWrapper Loading');
        return const AuthLoadingScreen();
      },
      error: (error, stackTrace) {
        print('❌ AuthWrapper Error: $error');
        return const LoginScreen();
      },
    );
  }
}

class AuthLoadingScreen extends StatelessWidget {
  const AuthLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading...'),
          ],
        ),
      ),
    );
  }
}
