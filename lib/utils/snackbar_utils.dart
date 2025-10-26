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

  static void showError(
    BuildContext context,
    String message, [
    String? errorCode,
  ]) {
    final displayMessage = errorCode != null
        ? '$message ($errorCode)'
        : message;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(displayMessage),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static void showWarning(
    BuildContext context,
    String message, [
    String? errorCode,
  ]) {
    final displayMessage = errorCode != null
        ? '$message ($errorCode)'
        : message;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(displayMessage),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
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

  static void showPasswordResetSent(BuildContext context) {
    showSuccess(context, 'Password reset email sent! Check your inbox');
  }

  // New error methods with error codes
  static void showInvalidCredentials(BuildContext context, String errorCode) {
    showError(context, 'Invalid email or password', errorCode);
  }

  static void showEmailNotVerified(BuildContext context, String errorCode) {
    showWarning(
      context,
      'Please confirm your email address before signing in. Check your inbox for a verification link.',
      errorCode,
    );
  }

  static void showUserNotFound(BuildContext context, String errorCode) {
    showError(context, 'No account found with this email', errorCode);
  }

  static void showNetworkError(BuildContext context, String errorCode) {
    showError(
      context,
      'Network error. Please check your connection',
      errorCode,
    );
  }

  static void showInvalidEmail(BuildContext context, String errorCode) {
    showError(context, 'Please enter a valid email address', errorCode);
  }

  static void showAccountLocked(BuildContext context, String errorCode) {
    showError(context, 'Account is locked. Please contact support', errorCode);
  }

  static void showLoginTimeout(BuildContext context, String errorCode) {
    showError(context, 'Login timeout. Please try again', errorCode);
  }

  static void showAuthServiceError(BuildContext context, String errorCode) {
    showError(
      context,
      'Authentication service error. Please try again',
      errorCode,
    );
  }

  static void showTooManyAttempts(BuildContext context, String errorCode) {
    showError(
      context,
      'Too many login attempts. Please try again later',
      errorCode,
    );
  }

  static void showAccountDisabled(BuildContext context, String errorCode) {
    showError(
      context,
      'Account is disabled. Please contact support',
      errorCode,
    );
  }

  static void showPasswordExpired(BuildContext context, String errorCode) {
    showError(
      context,
      'Password has expired. Please reset your password',
      errorCode,
    );
  }

  static void showUserAlreadyExists(BuildContext context, String errorCode) {
    showError(context, 'An account with this email already exists', errorCode);
  }

  static void showWeakPassword(BuildContext context, String errorCode) {
    showError(
      context,
      'Password is too weak. Please choose a stronger password',
      errorCode,
    );
  }

  static void showRegistrationTimeout(BuildContext context, String errorCode) {
    showError(context, 'Registration timeout. Please try again', errorCode);
  }

  static void showInvalidName(BuildContext context, String errorCode) {
    showError(context, 'Invalid name. Please enter a valid name', errorCode);
  }

  static void showTermsNotAccepted(BuildContext context, String errorCode) {
    showError(context, 'Please accept the terms and conditions', errorCode);
  }

  static void showAgeVerification(BuildContext context, String errorCode) {
    showError(
      context,
      'Age verification required. Please verify your age',
      errorCode,
    );
  }

  static void showServiceError(BuildContext context, String errorCode) {
    showError(context, 'Service error. Please try again', errorCode);
  }

  static void showEmailSendingFailed(BuildContext context, String errorCode) {
    showError(context, 'Failed to send email. Please try again', errorCode);
  }

  static void showAccountCreationFailed(
    BuildContext context,
    String errorCode,
  ) {
    showError(context, 'Account creation failed. Please try again', errorCode);
  }

  static void showGenericError(BuildContext context, [String? errorCode]) {
    showError(context, 'Something went wrong. Please try again', errorCode);
  }
}
