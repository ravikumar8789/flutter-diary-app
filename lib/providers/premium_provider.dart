import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/premium_service.dart';

/// Premium state
class PremiumState {
  final bool isPremium;
  final CustomerInfo? customerInfo;
  final bool isLoading;
  final String? error;

  PremiumState({
    this.isPremium = false,
    this.customerInfo,
    this.isLoading = false,
    this.error,
  });

  DateTime? get premiumExpiresAt {
    final ent = customerInfo?.entitlements.active['premium'];
    final dateStr = ent?.expirationDate;
    if (dateStr == null || dateStr.isEmpty) return null;
    return DateTime.tryParse(dateStr);
  }

  String? get productId =>
      customerInfo?.entitlements.active['premium']?.productIdentifier;
}

/// Premium provider – exposes isPremium and CustomerInfo.
final premiumProvider =
    FutureProvider.autoDispose<PremiumState>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    return PremiumState(isPremium: false);
  }

  ref.keepAlive();

  try {
    final info = await PremiumService.getCustomerInfo();
    if (info == null) {
      return PremiumState(isPremium: false);
    }
    final ent = info.entitlements.active['premium'];
    if (ent == null) {
      return PremiumState(isPremium: false, customerInfo: info);
    }

    final expStr = ent.expirationDate?.trim();
    DateTime? exp;
    if (expStr != null && expStr.isNotEmpty) {
      exp = DateTime.tryParse(expStr);
    }

    final now = DateTime.now();
    final isPremium = exp == null
        ? true
        : exp.isAfter(now)
            ? true
            : ent.billingIssueDetectedAt != null;

    return PremiumState(isPremium: isPremium, customerInfo: info);
  } catch (e) {
    return PremiumState(isPremium: false, error: e.toString());
  }
});
