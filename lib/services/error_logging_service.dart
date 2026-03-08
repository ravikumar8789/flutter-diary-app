import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/error_models.dart';
import 'database/local_entry_service.dart';

class ErrorLoggingService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Primary method using ErrorContext model
  /// This is the recommended way to log errors
  static Future<void> logError(ErrorContext error) async {
    try {
      // Auto-populate missing fields
      final enrichedError = error.copyWith(
        userId: error.userId ?? _supabase.auth.currentUser?.id,
        sessionId: error.sessionId ?? _generateSessionId(),
        screenStack: error.screenStack ?? _getCurrentScreenStack(),
        syncStatus: error.syncStatus ?? _getCurrentSyncStatus(),
      );

      // Collect additional context
      final additionalContext = _collectErrorContext(
        errorCode: enrichedError.errorCode,
        errorMessage: enrichedError.errorMessage,
        additionalContext: enrichedError.errorContext,
      );

      // Merge additional context into error_context field
      final finalError = enrichedError.copyWith(
        errorContext: {
          ...?enrichedError.errorContext,
          ...additionalContext,
        },
      );

      final payload = finalError.toJson();
      final isOnline = await _isOnline();

      if (isOnline) {
        try {
          await _supabase.from('error_logs').insert(payload);
        } catch (_) {
          await _addErrorLogToSyncQueue(payload);
        }
      } else {
        await _addErrorLogToSyncQueue(payload);
      }
    } catch (e) {
      // CRITICAL: Never throw - error logging must never fail
      if (kDebugMode) {
        print('ERROR: Failed to log error to Supabase: $e');
        print('Original error: ${error.errorCode} - ${error.errorMessage}');
      }
      // Silently fail - don't break app
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

  static Future<bool> _isOnline() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.isNotEmpty &&
          results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  static Future<void> _addErrorLogToSyncQueue(Map<String, dynamic> payload) async {
    try {
      await LocalEntryService().addToSyncQueue(
        entityType: 'error_log',
        entityId: '${DateTime.now().millisecondsSinceEpoch}',
        tableName: 'error_logs',
        operation: 'insert',
        data: payload,
      );
    } catch (_) {
      // Never throw - silently fail
    }
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

  /// Log critical errors - backward compatible (accepts ErrorContext or parameters)
  /// New code should use: logError(ErrorContext.create(...))
  static Future<void> logCriticalError({
    ErrorContext? error,
    String? errorCode,
    String? errorMessage,
    String? stackTrace,
    Map<String, dynamic>? errorContext,
  }) async {
    if (error != null) {
      await logError(error.copyWith(severity: ErrorSeverity.critical.value));
    } else if (errorCode != null && errorMessage != null) {
      await _logErrorLegacy(
        errorCode: errorCode,
        errorMessage: errorMessage,
        stackTrace: stackTrace,
        severity: 'CRITICAL',
        errorContext: errorContext,
      );
    }
  }

  /// Log high priority errors - backward compatible (accepts ErrorContext or parameters)
  /// New code should use: logError(ErrorContext.create(...))
  static Future<void> logHighError({
    ErrorContext? error,
    String? errorCode,
    String? errorMessage,
    String? stackTrace,
    Map<String, dynamic>? errorContext,
  }) async {
    if (error != null) {
      await logError(error.copyWith(severity: ErrorSeverity.high.value));
    } else if (errorCode != null && errorMessage != null) {
      await _logErrorLegacy(
        errorCode: errorCode,
        errorMessage: errorMessage,
        stackTrace: stackTrace,
        severity: 'HIGH',
        errorContext: errorContext,
      );
    }
  }

  /// Log medium priority errors - backward compatible (accepts ErrorContext or parameters)
  /// New code should use: logError(ErrorContext.create(...))
  static Future<void> logMediumError({
    ErrorContext? error,
    String? errorCode,
    String? errorMessage,
    String? stackTrace,
    Map<String, dynamic>? errorContext,
  }) async {
    if (error != null) {
      await logError(error.copyWith(severity: ErrorSeverity.medium.value));
    } else if (errorCode != null && errorMessage != null) {
      await _logErrorLegacy(
        errorCode: errorCode,
        errorMessage: errorMessage,
        stackTrace: stackTrace,
        severity: 'MEDIUM',
        errorContext: errorContext,
      );
    }
  }

  /// Log low priority errors/warnings - backward compatible (accepts ErrorContext or parameters)
  /// New code should use: logError(ErrorContext.create(...))
  static Future<void> logLowError({
    ErrorContext? error,
    String? errorCode,
    String? errorMessage,
    String? stackTrace,
    Map<String, dynamic>? errorContext,
  }) async {
    if (error != null) {
      await logError(error.copyWith(severity: ErrorSeverity.low.value));
    } else if (errorCode != null && errorMessage != null) {
      await _logErrorLegacy(
        errorCode: errorCode,
        errorMessage: errorMessage,
        stackTrace: stackTrace,
        severity: 'LOW',
        errorContext: errorContext,
      );
    }
  }

  /// Internal legacy method for backward compatibility
  static Future<void> _logErrorLegacy({
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
    // Convert to model and call new method
    final error = ErrorContext(
      errorCode: errorCode,
      errorMessage: errorMessage,
      stackTrace: stackTrace,
      severity: severity,
      timestamp: DateTime.now(),
      userId: userId,
      sessionId: sessionId,
      screenStack: screenStack,
      errorContext: errorContext,
      retryCount: retryCount,
      syncStatus: syncStatus,
    );
    await logError(error);
  }
}
