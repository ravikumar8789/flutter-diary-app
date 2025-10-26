import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../models/models.dart';
import '../utils/snackbar_utils.dart';
import '../services/error_logging_service.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  Gender _selectedGender = Gender.unspecified;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final authController = ref.read(authControllerProvider);

        await authController.signUp(
          _emailController.text.trim(),
          _passwordController.text,
          displayName: _nameController.text.trim(),
          gender: _selectedGender.name,
        );

        if (mounted) {
          SnackbarUtils.showRegistrationSuccess(context);
          // Show email verification message
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Check Your Email'),
              content: const Text(
                'We\'ve sent you a verification link. Please check your email and click the link to verify your account.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop(); // Go back to login
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          String errorCode = 'ERRAUTH011';
          String severity = 'HIGH';

          if (e.toString().contains('User already registered')) {
            errorCode = 'ERRAUTH011';
          } else if (e.toString().contains('Password should be at least')) {
            errorCode = 'ERRAUTH012';
          } else if (e.toString().contains('Invalid email')) {
            errorCode = 'ERRAUTH013';
          } else if (e.toString().contains('timeout') ||
              e.toString().contains('Timeout')) {
            errorCode = 'ERRAUTH014';
            severity = 'MEDIUM';
          } else if (e.toString().contains('Invalid name') ||
              e.toString().contains('name')) {
            errorCode = 'ERRAUTH015';
          } else if (e.toString().contains('terms') ||
              e.toString().contains('Terms')) {
            errorCode = 'ERRAUTH016';
          } else if (e.toString().contains('age') ||
              e.toString().contains('Age')) {
            errorCode = 'ERRAUTH017';
          } else if (e.toString().contains('service') ||
              e.toString().contains('Service')) {
            errorCode = 'ERRAUTH018';
          } else if (e.toString().contains('email') &&
              e.toString().contains('send')) {
            errorCode = 'ERRAUTH019';
          } else if (e.toString().contains('creation') ||
              e.toString().contains('Creation')) {
            errorCode = 'ERRAUTH020';
          } else {
            errorCode = 'ERRAUTH018';
          }

          // Log error to Supabase
          await ErrorLoggingService.logError(
            errorCode: errorCode,
            errorMessage: e.toString(),
            stackTrace: StackTrace.current.toString(),
            severity: severity,
            errorContext: {
              'email': _emailController.text,
              'name': _nameController.text,
              'gender': _selectedGender.name,
              'registration_time': DateTime.now().toIso8601String(),
            },
          );

          // Show user-friendly message
          if (errorCode == 'ERRAUTH011') {
            SnackbarUtils.showUserAlreadyExists(context, errorCode);
          } else if (errorCode == 'ERRAUTH012') {
            SnackbarUtils.showWeakPassword(context, errorCode);
          } else if (errorCode == 'ERRAUTH013') {
            SnackbarUtils.showInvalidEmail(context, errorCode);
          } else if (errorCode == 'ERRAUTH014') {
            SnackbarUtils.showRegistrationTimeout(context, errorCode);
          } else if (errorCode == 'ERRAUTH015') {
            SnackbarUtils.showInvalidName(context, errorCode);
          } else if (errorCode == 'ERRAUTH016') {
            SnackbarUtils.showTermsNotAccepted(context, errorCode);
          } else if (errorCode == 'ERRAUTH017') {
            SnackbarUtils.showAgeVerification(context, errorCode);
          } else if (errorCode == 'ERRAUTH018') {
            SnackbarUtils.showServiceError(context, errorCode);
          } else if (errorCode == 'ERRAUTH019') {
            SnackbarUtils.showEmailSendingFailed(context, errorCode);
          } else if (errorCode == 'ERRAUTH020') {
            SnackbarUtils.showAccountCreationFailed(context, errorCode);
          } else {
            SnackbarUtils.showGenericError(context, errorCode);
          }
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title
                    Text(
                      'Create Account',
                      style: Theme.of(context).textTheme.displayLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'Start your journaling journey today',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Name field
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

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

                    // Gender field
                    DropdownButtonFormField<Gender>(
                      value: _selectedGender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: Gender.values.map((gender) {
                        return DropdownMenuItem(
                          value: gender,
                          child: Text(
                            gender.value == 'unspecified'
                                ? 'Prefer not to say'
                                : gender.value.toUpperCase(),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedGender = value!;
                        });
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
                          return 'Please enter a password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Confirm password field
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: !_isConfirmPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmPasswordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _isConfirmPasswordVisible =
                                  !_isConfirmPasswordVisible;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Register button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign Up'),
                    ),
                    const SizedBox(height: 24),

                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Sign In',
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
