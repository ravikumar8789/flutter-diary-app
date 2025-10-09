import 'package:flutter/material.dart';

class SnackbarUtils {
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static void showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // Auth specific snackbars
  static void showLoginSuccess(BuildContext context, String name) {
    showSuccess(context, 'Welcome back, $name! 🎉');
  }

  static void showLogoutSuccess(BuildContext context) {
    showInfo(context, 'Logged out successfully');
  }

  static void showRegistrationSuccess(BuildContext context) {
    showSuccess(
      context,
      'Account created! Please check your email to verify your account.',
    );
  }

  static void showEmailNotVerified(BuildContext context) {
    showWarning(
      context,
      'Please confirm your email address before signing in. Check your inbox for a verification link.',
    );
  }

  static void showInvalidCredentials(BuildContext context) {
    showError(context, 'Invalid email or password');
  }

  static void showUserNotFound(BuildContext context) {
    showError(context, 'No account found with this email');
  }

  static void showUserAlreadyExists(BuildContext context) {
    showError(context, 'An account with this email already exists');
  }

  static void showWeakPassword(BuildContext context) {
    showError(
      context,
      'Password is too weak. Please choose a stronger password',
    );
  }

  static void showInvalidEmail(BuildContext context) {
    showError(context, 'Please enter a valid email address');
  }

  static void showPasswordResetSent(BuildContext context) {
    showSuccess(context, 'Password reset email sent! Check your inbox');
  }

  static void showNetworkError(BuildContext context) {
    showError(context, 'Network error. Please check your connection');
  }

  static void showGenericError(BuildContext context) {
    showError(context, 'Something went wrong. Please try again');
  }
}
