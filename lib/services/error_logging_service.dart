import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class ErrorLoggingService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Log error with full context
  static Future<void> logError({
    required String errorCode,
    required String errorMessage,
    String? stackTrace,
    required String severity,
    String? userId,
    String? sessionId,
    Map<String, dynamic>? screenStack,
    Map<String, dynamic>? errorContext,
    int retryCount = 0,
    String? syncStatus,
  }) async {
    try {
      // Collect comprehensive error context
      final context = _collectErrorContext(
        errorCode: errorCode,
        errorMessage: errorMessage,
        additionalContext: errorContext,
      );

      await _supabase.from('error_logs').insert({
        'error_code': errorCode,
        'error_message': errorMessage,
        'stack_trace': stackTrace,
        'error_severity': severity,
        'user_id': userId ?? _supabase.auth.currentUser?.id,
        'session_id': sessionId ?? _generateSessionId(),
        'screen_stack': screenStack ?? _getCurrentScreenStack(),
        'error_context': context,
        'retry_count': retryCount,
        'sync_status': syncStatus ?? _getCurrentSyncStatus(),
      });

      if (kDebugMode) {
        print('✅ Error logged successfully: $errorCode');
      }
    } catch (e) {
      // Fallback: Log to console if Supabase fails
      if (kDebugMode) {
        print('❌ Error logging failed: $e');
        print('Error Code: $errorCode');
        print('Error Message: $errorMessage');
        print('Severity: $severity');
      }
    }
  }

  // Helper method to collect comprehensive error context
  static Map<String, dynamic> _collectErrorContext({
    required String errorCode,
    required String errorMessage,
    Map<String, dynamic>? additionalContext,
  }) {
    return {
      'error_code': errorCode,
      'error_message': errorMessage,
      'timestamp': DateTime.now().toIso8601String(),
      'app_version': '1.0.0',
      'platform': Platform.operatingSystem,
      'platform_version': Platform.operatingSystemVersion,
      'is_debug': kDebugMode,
      'device_info': _getDeviceInfo(),
      'user_actions': _getRecentUserActions(),
      'screen_stack': _getCurrentScreenStack(),
      'network_status': _getNetworkStatus(),
      'sync_status': _getCurrentSyncStatus(),
      ...?additionalContext,
    };
  }

  // Generate unique session ID
  static String _generateSessionId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  // Get current screen stack (simplified for now)
  static Map<String, dynamic> _getCurrentScreenStack() {
    return {
      'current_screen': 'Unknown', // Will be enhanced with navigation tracking
      'navigation_depth': 0,
      'screen_history': [],
    };
  }

  // Get current sync status
  static String _getCurrentSyncStatus() {
    // This will be enhanced with actual sync status
    return 'unknown';
  }

  // Get device information
  static Map<String, dynamic> _getDeviceInfo() {
    return {
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
      'is_debug': kDebugMode,
    };
  }

  // Get recent user actions (simplified)
  static List<String> _getRecentUserActions() {
    return ['app_started', 'user_interaction'];
  }

  // Get network status (simplified)
  static String _getNetworkStatus() {
    return 'unknown'; // Will be enhanced with connectivity service
  }

  // Log critical errors with immediate attention
  static Future<void> logCriticalError({
    required String errorCode,
    required String errorMessage,
    String? stackTrace,
    Map<String, dynamic>? errorContext,
  }) async {
    await logError(
      errorCode: errorCode,
      errorMessage: errorMessage,
      stackTrace: stackTrace,
      severity: 'CRITICAL',
      errorContext: errorContext,
    );
  }

  // Log high priority errors
  static Future<void> logHighError({
    required String errorCode,
    required String errorMessage,
    String? stackTrace,
    Map<String, dynamic>? errorContext,
  }) async {
    await logError(
      errorCode: errorCode,
      errorMessage: errorMessage,
      stackTrace: stackTrace,
      severity: 'HIGH',
      errorContext: errorContext,
    );
  }

  // Log medium priority errors
  static Future<void> logMediumError({
    required String errorCode,
    required String errorMessage,
    String? stackTrace,
    Map<String, dynamic>? errorContext,
  }) async {
    await logError(
      errorCode: errorCode,
      errorMessage: errorMessage,
      stackTrace: stackTrace,
      severity: 'MEDIUM',
      errorContext: errorContext,
    );
  }

  // Log low priority errors/warnings
  static Future<void> logLowError({
    required String errorCode,
    required String errorMessage,
    String? stackTrace,
    Map<String, dynamic>? errorContext,
  }) async {
    await logError(
      errorCode: errorCode,
      errorMessage: errorMessage,
      stackTrace: stackTrace,
      severity: 'LOW',
      errorContext: errorContext,
    );
  }
}
