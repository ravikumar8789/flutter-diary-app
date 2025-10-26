enum ErrorSeverity {
  critical('CRITICAL'), // App crashes, data loss
  high('HIGH'), // Authentication failures, sync failures
  medium('MEDIUM'), // UI errors, validation failures
  low('LOW'); // Minor warnings, info messages

  const ErrorSeverity(this.value);
  final String value;
}

class ErrorContext {
  final String errorCode;
  final String errorMessage;
  final String severity;
  final DateTime timestamp;
  final String? userId;
  final String? sessionId;
  final Map<String, dynamic>? screenStack;
  final Map<String, dynamic>? errorContext;
  final int retryCount;
  final String? syncStatus;

  const ErrorContext({
    required this.errorCode,
    required this.errorMessage,
    required this.severity,
    required this.timestamp,
    this.userId,
    this.sessionId,
    this.screenStack,
    this.errorContext,
    this.retryCount = 0,
    this.syncStatus,
  });

  Map<String, dynamic> toJson() {
    return {
      'error_code': errorCode,
      'error_message': errorMessage,
      'error_severity': severity,
      'created_at': timestamp.toIso8601String(),
      'user_id': userId,
      'session_id': sessionId,
      'screen_stack': screenStack,
      'error_context': errorContext,
      'retry_count': retryCount,
      'sync_status': syncStatus,
    };
  }
}
