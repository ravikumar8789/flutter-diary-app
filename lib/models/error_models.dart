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
  final String? stackTrace;
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
    this.stackTrace,
    required this.severity,
    required this.timestamp,
    this.userId,
    this.sessionId,
    this.screenStack,
    this.errorContext,
    this.retryCount = 0,
    this.syncStatus,
  });

  /// Factory constructor for easy creation with common fields
  factory ErrorContext.create({
    required String errorCode,
    required String errorMessage,
    required ErrorSeverity severity,
    String? stackTrace,
    Map<String, dynamic>? errorContext,
    int retryCount = 0,
  }) {
    return ErrorContext(
      errorCode: errorCode,
      errorMessage: errorMessage,
      stackTrace: stackTrace,
      severity: severity.value,
      timestamp: DateTime.now(),
      errorContext: errorContext,
      retryCount: retryCount,
    );
  }

  /// Factory constructor from exception for automatic error extraction
  factory ErrorContext.fromException({
    required String errorCode,
    required ErrorSeverity severity,
    required Object exception,
    StackTrace? stackTrace,
    Map<String, dynamic>? errorContext,
  }) {
    return ErrorContext(
      errorCode: errorCode,
      errorMessage: exception.toString(),
      stackTrace: stackTrace?.toString(),
      severity: severity.value,
      timestamp: DateTime.now(),
      errorContext: errorContext,
    );
  }

  /// Create a copy with modified fields
  ErrorContext copyWith({
    String? errorCode,
    String? errorMessage,
    String? stackTrace,
    String? severity,
    DateTime? timestamp,
    String? userId,
    String? sessionId,
    Map<String, dynamic>? screenStack,
    Map<String, dynamic>? errorContext,
    int? retryCount,
    String? syncStatus,
  }) {
    return ErrorContext(
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      stackTrace: stackTrace ?? this.stackTrace,
      severity: severity ?? this.severity,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
      sessionId: sessionId ?? this.sessionId,
      screenStack: screenStack ?? this.screenStack,
      errorContext: errorContext ?? this.errorContext,
      retryCount: retryCount ?? this.retryCount,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'error_code': errorCode,
      'error_message': errorMessage,
      'stack_trace': stackTrace,
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
