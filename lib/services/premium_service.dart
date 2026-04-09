import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'error_logging_service.dart';
import '../models/error_models.dart';

/// Premium / RevenueCat service.
/// Handles SDK config, login, offerings, purchase, and premium check.
/// See bc/PAYMENT-FEATURE docs for setup.
class PremiumService {
  static const String _entitlementId = 'premium';
  static const String _defaultOfferingId = 'default';

  static bool _isConfigured = false;

  /// Configure RevenueCat SDK. Call once at app start (after dotenv loaded).
  /// Requires REVENUECAT_API_KEY in .env (or REVENUECAT_ANDROID_KEY / REVENUECAT_IOS_KEY).
  static Future<void> configure() async {
    if (_isConfigured) return;

    final apiKey = _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return; // No key – premium disabled
    }

    try {
      await Purchases.setLogLevel(LogLevel.info);
      final config = PurchasesConfiguration(apiKey);
      await Purchases.configure(config);
      _isConfigured = true;
    } catch (e, st) {
      await ErrorLoggingService.logMediumError(
        error: ErrorContext.fromException(
          errorCode: 'ERRPREMIUM001',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: st,
          errorContext: {'operation': 'premium_configure'},
        ),
      );
    }
  }

  static String? _getApiKey() {
    if (Platform.isAndroid) {
      return dotenv.env['REVENUECAT_ANDROID_KEY'] ??
          dotenv.env['REVENUECAT_API_KEY'];
    }
    if (Platform.isIOS) {
      return dotenv.env['REVENUECAT_IOS_KEY'] ??
          dotenv.env['REVENUECAT_API_KEY'];
    }
    return dotenv.env['REVENUECAT_API_KEY'];
  }

  /// Log in with Supabase user ID. Call after auth.
  /// app_user_id = Supabase user ID for webhook sync.
  static Future<void> logIn(String supabaseUserId) async {
    if (!_isConfigured) return;

    try {
      await Purchases.logIn(supabaseUserId);
    } catch (e, st) {
      await ErrorLoggingService.logMediumError(
        error: ErrorContext.fromException(
          errorCode: 'ERRPREMIUM002',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: st,
          errorContext: {
            'operation': 'premium_log_in',
            'user_id': supabaseUserId,
          },
        ),
      );
    }
  }

  /// Log out. Call on auth logout.
  static Future<void> logOut() async {
    if (!_isConfigured) return;

    try {
      await Purchases.logOut();
    } catch (e, st) {
      await ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRPREMIUM003',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: st,
          errorContext: {'operation': 'premium_log_out'},
        ),
      );
    }
  }

  /// Get current customer info (for expiry, product details).
  static Future<CustomerInfo?> getCustomerInfo() async {
    if (!_isConfigured) return null;

    try {
      return await Purchases.getCustomerInfo();
    } catch (e, st) {
      await ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRPREMIUM008',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: st,
          errorContext: {'operation': 'premium_get_customer_info'},
        ),
      );
      return null;
    }
  }

  /// Check if user has premium entitlement.
  static Future<bool> isPremium() async {
    if (!_isConfigured) return false;

    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(_entitlementId);
    } catch (e, st) {
      await ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRPREMIUM004',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: st,
          errorContext: {'operation': 'premium_check'},
        ),
      );
      return false;
    }
  }

  /// Get offerings (packages: monthly, annual).
  static Future<Offerings?> getOfferings() async {
    if (!_isConfigured) return null;

    try {
      return await Purchases.getOfferings();
    } catch (e, st) {
      await ErrorLoggingService.logMediumError(
        error: ErrorContext.fromException(
          errorCode: 'ERRPREMIUM005',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: st,
          errorContext: {'operation': 'premium_get_offerings'},
        ),
      );
      return null;
    }
  }

  /// Get current offering (default or by id).
  static Future<Offering?> getCurrentOffering({String? offeringId}) async {
    final offerings = await getOfferings();
    if (offerings == null) return null;

    if (offeringId != null) {
      return offerings.all[offeringId];
    }
    return offerings.current ?? offerings.all[_defaultOfferingId];
  }

  /// Purchase a package. Returns CustomerInfo on success.
  static Future<CustomerInfo?> purchasePackage(Package package) async {
    if (!_isConfigured) return null;

    try {
      final result = await Purchases.purchasePackage(package);
      return result.customerInfo;
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError) {
        return null; // User cancelled
      }
      await ErrorLoggingService.logMediumError(
        error: ErrorContext.fromException(
          errorCode: 'ERRPREMIUM006',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'operation': 'premium_purchase',
            'package': package.identifier,
          },
        ),
      );
      rethrow;
    } catch (e, st) {
      await ErrorLoggingService.logMediumError(
        error: ErrorContext.fromException(
          errorCode: 'ERRPREMIUM006',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: st,
          errorContext: {
            'operation': 'premium_purchase',
            'package': package.identifier,
          },
        ),
      );
      rethrow;
    }
  }

  /// Restore purchases. Returns CustomerInfo.
  static Future<CustomerInfo?> restorePurchases() async {
    if (!_isConfigured) return null;

    try {
      return await Purchases.restorePurchases();
    } catch (e, st) {
      await ErrorLoggingService.logMediumError(
        error: ErrorContext.fromException(
          errorCode: 'ERRPREMIUM007',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: st,
          errorContext: {'operation': 'premium_restore'},
        ),
      );
      rethrow;
    }
  }

  /// Invalidate customer info cache (e.g. after restore).
  static Future<void> invalidateCache() async {
    if (!_isConfigured) return;

    try {
      await Purchases.invalidateCustomerInfoCache();
    } catch (_) {
      // Ignore
    }
  }

  /// Check if billing is supported (can make purchases).
  static Future<bool> canMakePayments() async {
    if (!_isConfigured) return false;

    try {
      return await Purchases.canMakePayments();
    } catch (_) {
      return false;
    }
  }
}
