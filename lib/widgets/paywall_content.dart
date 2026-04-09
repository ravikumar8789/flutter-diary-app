import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../services/premium_service.dart';
import '../providers/premium_provider.dart';
import '../utils/snackbar_utils.dart';
import '../ui/responsive/responsive_info.dart';
import '../ui/responsive/responsive_tokens.dart';

/// Paywall: benefits, plan selection, pay button, restore.
/// Reusable on PremiumScreen, Analytics (weekly/monthly gate).
/// Scrollable middle; sticky Continue + footer (needs bounded height).
///
/// [compactBottomGap]: use above a bottom nav — skips extra bottom safe inset
/// and uses smaller padding so the footer sits closer to the nav bar.
class PaywallContent extends ConsumerStatefulWidget {
  const PaywallContent({super.key, this.compactBottomGap = false});

  final bool compactBottomGap;

  @override
  ConsumerState<PaywallContent> createState() => _PaywallContentState();
}

class _PaywallContentState extends ConsumerState<PaywallContent> {
  Package? _selectedPackage;
  Offering? _offering;
  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _isRestoring = false;

  static const _benefits = [
    (
      'Discover what shaped your week',
      'AI recap of your patterns and highlights',
    ),
    (
      'See how your mood changes over time',
      'Charts and trends across weeks and months',
    ),
    (
      'Find out how habits affect your mood',
      'See which habits help or hurt your mood',
    ),
    ('See what you think about most', 'Your most common topics and themes'),
    (
      'Track your consistency and streaks',
      'Journaling and self-care streaks to stay motivated',
    ),
    (
      'Get personalized recommendations',
      'AI suggestions based on your entries',
    ),
    ('See your monthly story', 'Your journey and growth over the month'),
  ];

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    setState(() => _isLoading = true);
    final offering = await PremiumService.getCurrentOffering();
    if (mounted) {
      setState(() {
        _offering = offering;
        _isLoading = false;
        if (offering != null && offering.availablePackages.isNotEmpty) {
          _selectedPackage = offering.availablePackages.first;
        }
      });
    }
  }

  Future<void> _purchase() async {
    if (_selectedPackage == null) return;
    if (!await PremiumService.canMakePayments()) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Purchases not available');
      }
      return;
    }

    setState(() => _isPurchasing = true);
    try {
      final info = await PremiumService.purchasePackage(_selectedPackage!);
      if (mounted) {
        ref.invalidate(premiumProvider);
        if (info != null) {
          SnackbarUtils.showSuccess(context, 'Welcome to Premium!');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Purchase failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _isRestoring = true);
    try {
      final info = await PremiumService.restorePurchases();
      await PremiumService.invalidateCache();
      if (mounted) {
        ref.invalidate(premiumProvider);
        if (info != null && info.entitlements.active.containsKey('premium')) {
          SnackbarUtils.showSuccess(context, 'Purchases restored');
        } else {
          SnackbarUtils.showInfo(context, 'No purchases to restore');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Restore failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = ResponsiveInfo.of(context);
    final hPad = ResponsiveTokens.screenPaddingHorizontal(info);
    final vTop = ResponsiveTokens.screenPaddingVertical(info);
    final spacingL = ResponsiveTokens.spacingL(info);
    final spacingM = ResponsiveTokens.spacingM(info);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_offering == null || _offering!.availablePackages.isEmpty) {
      return Center(
        child: Padding(
          padding: ResponsiveTokens.screenPadding(info),
          child: Text(
            'No plans available at the moment.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final iconSize = info.value(compact: 64.0, medium: 68.0, expanded: 72.0);
    final premiumIconSize = info.value(
      compact: 36.0,
      medium: 38.0,
      expanded: 40.0,
    );
    final footerBottomPad = widget.compactBottomGap
        ? ResponsiveTokens.spacingXs(info)
        : spacingM;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(hPad, vTop, hPad, spacingM),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: ResponsiveTokens.maxContentWidth(info),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: iconSize,
                            height: iconSize,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.workspace_premium,
                              size: premiumIconSize,
                              color: colorScheme.primary,
                            ),
                          ),
                          SizedBox(height: spacingM),
                          Text(
                            'Get Premium',
                            style: textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: ResponsiveTokens.spacingS(info)),
                          Text(
                            'See what shapes your week, month, and mood.',
                            style: textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: spacingL),
                    ..._benefits.map(
                      (e) => _buildBenefit(context, info, e.$1, e.$2),
                    ),
                    SizedBox(height: spacingL),
                    Container(
                      padding: EdgeInsets.all(spacingM),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(
                          0.5,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: _buildPricingCards(context, info),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Material(
          elevation: 6,
          shadowColor: colorScheme.shadow.withOpacity(0.18),
          color: colorScheme.surface,
          surfaceTintColor: colorScheme.surfaceTint.withOpacity(0.08),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: SafeArea(
            top: false,
            bottom: !widget.compactBottomGap,
            minimum: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                hPad,
                ResponsiveTokens.spacingM(info),
                hPad,
                footerBottomPad,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: ResponsiveTokens.maxContentWidth(info),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        onPressed: _isPurchasing ? null : _purchase,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isPurchasing
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Continue'),
                      ),
                      SizedBox(height: ResponsiveTokens.spacingS(info)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: _isRestoring ? null : _restore,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: _isRestoring
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Restore',
                                    style: textTheme.labelMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                          ),
                          Text(
                            '·',
                            style: textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              // TODO: Open terms URL
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Terms',
                              style: textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Text(
                            '·',
                            style: textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              // TODO: Open privacy URL
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Privacy',
                              style: textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBenefit(
    BuildContext context,
    ResponsiveInfo info,
    String title,
    String description,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveTokens.spacingM(info)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 22, color: colorScheme.primary),
          SizedBox(width: ResponsiveTokens.spacingM(info)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCards(BuildContext context, ResponsiveInfo info) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final packages = _offering!.availablePackages;
    final cardPad = ResponsiveTokens.spacingM(info);

    Package? monthlyPkg;
    Package? annualPkg;
    for (final p in packages) {
      if (p.packageType == PackageType.monthly) monthlyPkg = p;
      if (p.packageType == PackageType.annual) annualPkg = p;
    }

    int? annualDiscountPercent;
    if (monthlyPkg != null && annualPkg != null) {
      final monthlyPrice = monthlyPkg.storeProduct.price;
      final annualPrice = annualPkg.storeProduct.price;
      if (monthlyPrice > 0) {
        final fullYear = monthlyPrice * 12;
        if (fullYear > annualPrice) {
          annualDiscountPercent = ((1 - annualPrice / fullYear) * 100).round();
        }
      }
    }

    final displayPackages = <Package>[];
    if (annualPkg != null) displayPackages.add(annualPkg);
    if (monthlyPkg != null) displayPackages.add(monthlyPkg);
    for (final p in packages) {
      if (p != annualPkg && p != monthlyPkg) displayPackages.add(p);
    }

    if (displayPackages.isEmpty) {
      displayPackages.addAll(packages);
    }

    return Row(
      children: displayPackages.map((pkg) {
        final isSelected = _selectedPackage == pkg;
        final isAnnual = pkg.packageType == PackageType.annual;
        final discount = isAnnual ? annualDiscountPercent : null;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveTokens.spacingXs(info),
            ),
            child: GestureDetector(
              onTap: () => setState(() => _selectedPackage = pkg),
              child: Container(
                padding: EdgeInsets.all(cardPad),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.outline.withOpacity(0.3),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            top: info.value(
                              compact: 1.0,
                              medium: 1.0,
                              expanded: 2.0,
                            ),
                          ),
                          child: Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 20,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(width: ResponsiveTokens.spacingS(info)),
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                _packageLabel(pkg),
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              if (discount != null && discount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$discount % off',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveTokens.spacingS(info)),
                    Text(
                      pkg.storeProduct.priceString,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _packageSubPrice(pkg),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _packageLabel(Package pkg) {
    switch (pkg.packageType) {
      case PackageType.monthly:
        return 'Monthly';
      case PackageType.annual:
        return 'Yearly';
      case PackageType.lifetime:
        return 'Lifetime';
      default:
        return pkg.identifier;
    }
  }

  String _packageSubPrice(Package pkg) {
    switch (pkg.packageType) {
      case PackageType.monthly:
        return 'Billed monthly';
      case PackageType.annual:
        final price = pkg.storeProduct.price;
        if (price > 0) {
          final perMonth = price / 12;
          return 'Only \$${perMonth.toStringAsFixed(2)}/mo';
        }
        return 'Billed yearly';
      case PackageType.lifetime:
        return 'One-time purchase';
      default:
        return '';
    }
  }
}
