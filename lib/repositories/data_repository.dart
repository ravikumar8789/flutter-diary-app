import 'dart:async';
import '../services/error_logging_service.dart';
import '../models/error_models.dart';

/// Cached data wrapper with expiration
class CachedData {
  final dynamic data;
  final DateTime expiresAt;
  final DateTime createdAt;
  bool _isStale = false; // Marked stale but still valid for SWR

  CachedData(this.data, Duration ttl)
      : expiresAt = DateTime.now().add(ttl),
        createdAt = DateTime.now();

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isStale => _isStale;
  
  void markStale() {
    _isStale = true;
  }
}

/// Centralized data repository with caching and request deduplication
/// 
/// Implements professional caching patterns:
/// - Stale-while-revalidate (SWR)
/// - Debounced batch invalidation
/// - Request deduplication
class DataRepository {
  // In-memory cache
  final Map<String, CachedData> _cache = {};

  // In-flight requests tracking (prevents duplicate queries)
  final Map<String, Future> _inFlightRequests = {};

  // Background refetch tracking (prevents duplicate SWR refetches)
  final Map<String, Future<void>> _backgroundFetches = {};

  // Cache TTL: 5 minutes default
  static const Duration defaultCacheTTL = Duration(minutes: 5);
  
  // Stale threshold: Consider data stale after 2 minutes (but still return it)
  static const Duration staleThreshold = Duration(minutes: 2);

  // Timer for cache cleanup
  Timer? _cacheCleanupTimer;
  
  // Debounced invalidation queue
  final Map<String, DateTime> _pendingInvalidations = {};
  Timer? _invalidationDebounceTimer;
  static const Duration invalidationDebounceDelay = Duration(milliseconds: 300);

  DataRepository() {
    // Clean up expired cache every 1 minute
    _cacheCleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _cleanupExpiredCache();
    });
  }

  /// Fetch data with deduplication and stale-while-revalidate (SWR)
  /// 
  /// Professional pattern:
  /// 1. Returns stale cache immediately if available (SWR)
  /// 2. Refetches in background if stale
  /// 3. Deduplicates in-flight requests
  /// 4. Returns fresh data when available
  Future<T> fetch<T>({
    required String key,
    required Future<T> Function() fetcher,
    Duration? ttl,
    bool allowStale = true, // Enable stale-while-revalidate
  }) async {
    try {
      // 1. Check cache first (SWR pattern)
      if (_cache.containsKey(key)) {
        final cached = _cache[key]!;
        
        if (!cached.isExpired) {
          // Data is fresh - return immediately
          if (!cached.isStale) {
            return cached.data as T;
          }
          
          // Data is stale but valid - return stale, refetch in background (SWR)
          if (allowStale) {
            // Trigger background refetch if not already in-flight
            if (!_inFlightRequests.containsKey(key)) {
              _refetchInBackground(key, fetcher, ttl);
            }
            return cached.data as T;
          }
        } else {
          // Remove expired cache
          _cache.remove(key);
        }
      }

      // 2. Check if request is already in-flight (deduplication)
      if (_inFlightRequests.containsKey(key)) {
        return await _inFlightRequests[key] as T;
      }

      // 3. Make request and track it
      final future = fetcher().then((data) {
        // Cache the result
        _cache[key] = CachedData(data, ttl ?? defaultCacheTTL);
        _inFlightRequests.remove(key);
        return data;
      }).catchError((e) {
        // Remove from in-flight on error
        _inFlightRequests.remove(key);
        throw e;
      });

      _inFlightRequests[key] = future;
      return await future;
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA202',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'cache_key': key,
            'operation': 'fetch',
            'cache_size': _cache.length,
            'in_flight_count': _inFlightRequests.length,
          },
        ),
      );
      rethrow;
    }
  }
  
  /// Background refetch for stale-while-revalidate
  void _refetchInBackground<T>(
    String key,
    Future<T> Function() fetcher,
    Duration? ttl,
  ) {
    if (_backgroundFetches.containsKey(key)) {
      return;
    }

    // Don't track in in-flight requests (this is background only)
    // Don't await - fire and forget
    final backgroundFuture = fetcher().then((data) {
      // Update cache with fresh data
      _cache[key] = CachedData(data, ttl ?? defaultCacheTTL);
    }).catchError((e) {
      // Silently fail background refetch - stale data is still valid
      ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA250',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'cache_key': key,
            'operation': 'background_refetch',
          },
        ),
      );
    }).whenComplete(() {
      _backgroundFetches.remove(key);
    });

    _backgroundFetches[key] = backgroundFuture;
  }

  /// Invalidate specific cache key (debounced)
  /// 
  /// Uses debouncing to batch multiple invalidations together.
  void invalidate(String key) {
    try {
      // Mark for debounced invalidation
      _pendingInvalidations[key] = DateTime.now();
      _scheduleDebouncedInvalidation();
    } catch (e) {
      ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA203',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'cache_key': key,
            'operation': 'invalidate',
          },
        ),
      );
    }
  }
  
  /// Schedule debounced invalidation
  /// 
  /// Batches multiple invalidations together to prevent cascade.
  void _scheduleDebouncedInvalidation() {
    // Cancel existing timer
    _invalidationDebounceTimer?.cancel();
    
    // Schedule new debounced execution
    _invalidationDebounceTimer = Timer(invalidationDebounceDelay, () {
      _executePendingInvalidations();
    });
  }
  
  /// Execute all pending invalidations at once
  void _executePendingInvalidations() {
    try {
      final keysToInvalidate = _pendingInvalidations.keys.toList();
      _pendingInvalidations.clear();
      
      for (final key in keysToInvalidate) {
        // Mark as stale instead of removing (SWR pattern)
        if (_cache.containsKey(key)) {
          _cache[key]!.markStale();
        } else {
          _cache.remove(key);
        }
      }
    } catch (e) {
      ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA251',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'operation': 'execute_pending_invalidations',
          },
        ),
      );
    }
  }
  
  /// Immediate invalidation (for critical operations)
  void invalidateImmediate(String key) {
    try {
      _cache.remove(key);
      _pendingInvalidations.remove(key);
    } catch (e) {
      ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA252',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'cache_key': key,
            'operation': 'invalidate_immediate',
          },
        ),
      );
    }
  }

  /// Invalidate all entries cache for a user (debounced)
  void invalidateEntries(String userId, DateTime? date) {
    try {
      if (date != null) {
        // Invalidate specific date range
        final dateStr = date.toIso8601String().split('T')[0];
        final keys = _cache.keys.where((k) =>
            k.startsWith('entries_${userId}_') &&
            k.contains(dateStr)).toList();
        for (final key in keys) {
          invalidate(key); // Use debounced invalidation
        }
      } else {
        // Invalidate all entries for user
        final keys =
            _cache.keys.where((k) => k.startsWith('entries_${userId}_')).toList();
        for (final key in keys) {
          invalidate(key); // Use debounced invalidation
        }
      }
    } catch (e) {
      ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA204',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'date': date?.toIso8601String(),
            'operation': 'invalidate_entries',
          },
        ),
      );
    }
  }

  /// Invalidate home summary cache for a user (immediate)
  void invalidateHomeSummary(String userId) {
    try {
      final key = 'home_summary_${userId}';
      invalidateImmediate(key); // Use immediate invalidation to prevent race condition
    } catch (e) {
      ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA209',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'operation': 'invalidate_home_summary',
          },
        ),
      );
    }
  }

  /// Invalidate all habits cache for a user (debounced)
  void invalidateHabits(String userId, DateTime? date) {
    try {
      if (date != null) {
        // Invalidate specific date range
        final dateStr = date.toIso8601String().split('T')[0];
        final keys = _cache.keys.where((k) =>
            k.startsWith('habits_${userId}_') &&
            k.contains(dateStr)).toList();
        for (final key in keys) {
          invalidate(key); // Use debounced invalidation
        }
      } else {
        // Invalidate all habits for user
        final keys =
            _cache.keys.where((k) => k.startsWith('habits_${userId}_')).toList();
        for (final key in keys) {
          invalidate(key); // Use debounced invalidation
        }
      }
    } catch (e) {
      ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA205',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'date': date?.toIso8601String(),
            'operation': 'invalidate_habits',
          },
        ),
      );
    }
  }

  /// Invalidate monthly cache for a user
  void invalidateMonthly(String userId, DateTime? monthStart) {
    try {
      if (monthStart != null) {
        // Invalidate specific month
        final monthKey = '${monthStart.year}-${monthStart.month}';
        final analyticsKey = 'monthly_analytics_${userId}_$monthKey';
        _cache.remove(analyticsKey);
      }
      // Always invalidate monthly insights list when any month data changes
      final listKey = 'monthly_insights_list_$userId';
      _cache.remove(listKey);
    } catch (e) {
      ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRCACHE001',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'month_start': monthStart?.toIso8601String(),
            'operation': 'invalidate_monthly',
          },
        ),
      );
    }
  }

  /// Clear all cache
  void clearCache() {
    try {
      _cache.clear();
    } catch (e) {
      ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA206',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'operation': 'clear_cache',
          },
        ),
      );
    }
  }

  /// Clean up expired cache entries
  void _cleanupExpiredCache() {
    try {
      final expiredKeys = _cache.entries
          .where((e) => e.value.isExpired)
          .map((e) => e.key)
          .toList();

      for (final key in expiredKeys) {
        _cache.remove(key);
      }
    } catch (e) {
      ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA207',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'operation': 'cleanup_expired_cache',
          },
        ),
      );
    }
  }

  /// Get cache statistics (for monitoring)
  Map<String, dynamic> getCacheStats() {
    return {
      'cache_size': _cache.length,
      'in_flight_count': _inFlightRequests.length,
      'expired_count': _cache.values.where((c) => c.isExpired).length,
    };
  }

  /// Dispose resources
  void dispose() {
    try {
      _cacheCleanupTimer?.cancel();
      _cacheCleanupTimer = null;
      _invalidationDebounceTimer?.cancel();
      _invalidationDebounceTimer = null;
      _pendingInvalidations.clear();
      _inFlightRequests.clear();
      _backgroundFetches.clear();
      _cache.clear();
    } catch (e) {
      ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA208',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'operation': 'dispose',
          },
        ),
      );
    }
  }
}

