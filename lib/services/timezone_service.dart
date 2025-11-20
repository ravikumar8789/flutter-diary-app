import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'error_logging_service.dart';

class TimezoneService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static bool _timezoneInitialized = false;

  /// Initialize timezone database (call once at app startup)
  static void initializeTimezoneDatabase() {
    if (_timezoneInitialized) return;
    try {
      tz_data.initializeTimeZones();
      _timezoneInitialized = true;
    } catch (e) {
      // Already initialized or error - continue
    }
  }

  /// Get device timezone as IANA string (e.g., 'Asia/Kolkata')
  /// Uses offset matching against IANA database
  static Future<String> getDeviceTimezone() async {
    try {
      // Initialize timezone database if not already done
      initializeTimezoneDatabase();

      // Get current timezone offset using timeZoneOffset property
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      final offsetHours = offset.inHours;
      final offsetMinutes = (offset.inMinutes % 60).abs();

      // Try to find matching IANA timezone
      String? ianaTimezone;

      try {
        final locations = tz.timeZoneDatabase.locations;

        // Try common timezones first (fast path)
        final commonTimezones = [
          'Asia/Kolkata',        // IST +5:30
          'America/New_York',     // EST/EDT
          'America/Los_Angeles', // PST/PDT
          'Europe/London',        // GMT/BST
          'Asia/Dubai',           // GST +4:00
          'Asia/Singapore',       // SGT +8:00
          'Asia/Tokyo',           // JST +9:00
          'Australia/Sydney',     // AEDT/AEST
          'Europe/Paris',         // CET/CEST
          'America/Chicago',      // CST/CDT
        ];

        for (final tzName in commonTimezones) {
          try {
            final location = tz.getLocation(tzName);
            final tzTime = tz.TZDateTime.now(location);
            final tzOffset = tzTime.timeZoneOffset;

            if (tzOffset.inHours == offsetHours &&
                (tzOffset.inMinutes % 60).abs() == offsetMinutes) {
              ianaTimezone = tzName;
              break;
            }
          } catch (e) {
            // Continue to next
          }
        }

        // If not found in common, search all locations (slower but comprehensive)
        if (ianaTimezone == null) {
          for (final locationName in locations.keys) {
            try {
              final location = locations[locationName]!;
              final tzTime = tz.TZDateTime.now(location);
              final tzOffset = tzTime.timeZoneOffset;

              if (tzOffset.inHours == offsetHours &&
                  (tzOffset.inMinutes % 60).abs() == offsetMinutes) {
                ianaTimezone = locationName;
                break;
              }
            } catch (e) {
              // Continue
            }
          }
        }
      } catch (e) {
        // Error finding IANA timezone
      }

      // Return detected timezone or UTC fallback
      return ianaTimezone ?? 'UTC';
    } catch (e) {
      await ErrorLoggingService.logLowError(
        errorCode: 'ERRSYS160',
        errorMessage: 'Failed to get device timezone: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {'operation': 'get_device_timezone'},
      );
      return 'UTC'; // Fallback to UTC
    }
  }

  /// Update user timezone in database
  static Future<bool> updateUserTimezone(String userId, String timezone) async {
    try {
      await _supabase
          .from('users')
          .update({'timezone': timezone})
          .eq('id', userId);
      return true;
    } catch (e) {
      await ErrorLoggingService.logMediumError(
        errorCode: 'ERRSYS161',
        errorMessage: 'Failed to update user timezone: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'timezone': timezone,
          'operation': 'update_user_timezone',
        },
      );
      return false;
    }
  }

  /// Initialize timezone for user (get from device and update DB)
  static Future<String> initializeUserTimezone(String userId) async {
    final timezone = await getDeviceTimezone();
    await updateUserTimezone(userId, timezone);
    return timezone;
  }

  /// Check and update timezone if changed (for travelers)
  static Future<void> checkAndUpdateTimezone(String userId) async {
    try {
      // Get current timezone from device
      final deviceTimezone = await getDeviceTimezone();

      // Get current timezone from database
      final userData = await _supabase
          .from('users')
          .select('timezone')
          .eq('id', userId)
          .single();

      final dbTimezone = userData['timezone'] as String?;

      // Update if different (user traveled)
      if (dbTimezone != deviceTimezone) {
        await updateUserTimezone(userId, deviceTimezone);
      }
    } catch (e) {
      // Log but don't block app
      await ErrorLoggingService.logLowError(
        errorCode: 'ERRSYS163',
        errorMessage: 'Startup timezone check failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {'operation': 'startup_timezone_check'},
      );
    }
  }
}

