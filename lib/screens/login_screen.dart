import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'register_screen.dart';
import '../utils/snackbar_utils.dart';
import '../providers/auth_provider.dart';
import '../services/error_logging_service.dart';
import 'home_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Use Riverpod auth controller instead of direct Supabase calls
        await ref
            .read(authControllerProvider)
            .signIn(_emailController.text.trim(), _passwordController.text);

        SnackbarUtils.showLoginSuccess(
          context,
          _emailController.text.split('@')[0],
        );
        // Navigation will be handled by the auth state listener
      } catch (e) {
        String errorCode = 'ERRAUTH001';
        String severity = 'HIGH';

        if (e.toString().contains('Invalid login credentials')) {
          errorCode = 'ERRAUTH001';
        } else if (e.toString().contains('Email not confirmed') ||
            e.toString().contains('email_not_confirmed') ||
            e.toString().contains('verify your email') ||
            e.toString().contains('email not confirmed') ||
            e.toString().contains('confirm your email')) {
          errorCode = 'ERRAUTH002';
        } else if (e.toString().contains('User not found')) {
          errorCode = 'ERRAUTH003';
        } else if (e.toString().contains('Network') ||
            e.toString().contains('timeout')) {
          errorCode = 'ERRAUTH003';
          severity = 'MEDIUM';
        } else if (e.toString().contains('Invalid email')) {
          errorCode = 'ERRAUTH004';
        } else if (e.toString().contains('Account locked') ||
            e.toString().contains('locked')) {
          errorCode = 'ERRAUTH005';
        } else if (e.toString().contains('timeout')) {
          errorCode = 'ERRAUTH006';
        } else if (e.toString().contains('service') ||
            e.toString().contains('Service')) {
          errorCode = 'ERRAUTH007';
        } else if (e.toString().contains('Too many') ||
            e.toString().contains('attempts')) {
          errorCode = 'ERRAUTH008';
        } else if (e.toString().contains('disabled') ||
            e.toString().contains('Disabled')) {
          errorCode = 'ERRAUTH009';
        } else if (e.toString().contains('expired') ||
            e.toString().contains('Expired')) {
          errorCode = 'ERRAUTH010';
        } else {
          errorCode = 'ERRAUTH007';
        }

        // Log error to Supabase
        await ErrorLoggingService.logError(
          errorCode: errorCode,
          errorMessage: e.toString(),
          stackTrace: StackTrace.current.toString(),
          severity: severity,
          errorContext: {
            'email': _emailController.text,
            'attempt_time': DateTime.now().toIso8601String(),
            'login_method': 'email_password',
          },
        );

        // Show user-friendly message
        if (errorCode == 'ERRAUTH001') {
          SnackbarUtils.showInvalidCredentials(context, errorCode);
        } else if (errorCode == 'ERRAUTH002') {
          SnackbarUtils.showEmailNotVerified(context, errorCode);
        } else if (errorCode == 'ERRAUTH003') {
          SnackbarUtils.showUserNotFound(context, errorCode);
        } else if (errorCode == 'ERRAUTH004') {
          SnackbarUtils.showInvalidEmail(context, errorCode);
        } else if (errorCode == 'ERRAUTH005') {
          SnackbarUtils.showAccountLocked(context, errorCode);
        } else if (errorCode == 'ERRAUTH006') {
          SnackbarUtils.showLoginTimeout(context, errorCode);
        } else if (errorCode == 'ERRAUTH007') {
          SnackbarUtils.showAuthServiceError(context, errorCode);
        } else if (errorCode == 'ERRAUTH008') {
          SnackbarUtils.showTooManyAttempts(context, errorCode);
        } else if (errorCode == 'ERRAUTH009') {
          SnackbarUtils.showAccountDisabled(context, errorCode);
        } else if (errorCode == 'ERRAUTH010') {
          SnackbarUtils.showPasswordExpired(context, errorCode);
        } else {
          SnackbarUtils.showGenericError(context, errorCode);
        }
      }
    }
  }

  void _forgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      SnackbarUtils.showWarning(context, 'Please enter your email first');
      return;
    }

    try {
      await supabase.Supabase.instance.client.auth.resetPasswordForEmail(
        _emailController.text.trim(),
      );
      SnackbarUtils.showPasswordResetSent(context);
    } catch (e) {
      SnackbarUtils.showGenericError(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes
    ref.listen(currentUserProvider, (previous, next) {
      next.when(
        data: (user) {
          if (user != null) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
        },
        loading: () {},
        error: (error, stackTrace) {},
      );
    });

    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isTablet ? 48 : 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isTablet ? 500 : double.infinity,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo/Icon
                    Icon(
                      Icons.auto_stories_outlined,
                      size: isTablet ? 80 : 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Welcome Back',
                      style: Theme.of(context).textTheme.displayLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'Sign in to continue your journey',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Email field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Forgot password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _forgotPassword,
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Login button
                    ElevatedButton(
                      onPressed: _login,
                      child: const Text('Sign In'),
                    ),
                    const SizedBox(height: 24),

                    // Register link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
