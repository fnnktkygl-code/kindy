import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'pigio_logger.dart';

/// Pigio+ subscription entitlements.
enum PigioEntitlement {
  /// Core premium: ad-free, analytics, monthly Plumes stipend, exclusive wardrobe slot.
  plus,
  /// Occasion Pass: seasonal battle pass with premium track.
  occasionPass,
}

/// RevenueCat-backed subscription & IAP service for Pigio.
///
/// Call [init] once at app startup. Then use [isPremium] / [hasOccasionPass]
/// to gate features, and [purchasePigioPlusMonthly] / [purchasePigioPlusYearly]
/// to trigger purchase flows.
class SubscriptionService {
  SubscriptionService._();

  static const _rcApiKeyIos = String.fromEnvironment('REVENUECAT_IOS_KEY');
  static const _rcApiKeyAndroid = String.fromEnvironment('REVENUECAT_ANDROID_KEY');

  // Product identifiers (configured in RevenueCat dashboard)
  static const kPigioPlusMonthly = 'pigio_plus_monthly';
  static const kPigioPlusYearly = 'pigio_plus_yearly';
  static const kOccasionPass = 'pigio_occasion_pass';
  static const kPlumes100 = 'pigio_plumes_100';
  static const kPlumes500 = 'pigio_plumes_500';
  static const kPlumes1200 = 'pigio_plumes_1200';
  static const kGiftPigioPlusMonth = 'pigio_plus_gift_1m';

  // Entitlement identifiers (configured in RevenueCat dashboard)
  static const _entitlementPlus = 'pigio_plus';
  static const _entitlementOccasionPass = 'occasion_pass';

  static CustomerInfo? _customerInfo;
  static final _statusController = StreamController<bool>.broadcast();

  /// Stream that emits `true` when premium status changes.
  static Stream<bool> get premiumStatusStream => _statusController.stream;

  /// Whether the user has an active Pigio+ entitlement.
  static bool get isPremium =>
      _customerInfo?.entitlements.active.containsKey(_entitlementPlus) ?? false;

  /// Whether the user has an active Occasion Pass.
  static bool get hasOccasionPass =>
      _customerInfo?.entitlements.active.containsKey(_entitlementOccasionPass) ?? false;

  /// The user's expiration date for Pigio+ (null if not subscribed).
  static DateTime? get plusExpirationDate {
    final ent = _customerInfo?.entitlements.active[_entitlementPlus];
    return ent?.expirationDate != null ? DateTime.tryParse(ent!.expirationDate!) : null;
  }

  /// Initialize RevenueCat. Call once from app bootstrap.
  static Future<void> init({String? userId}) async {
    final apiKey = defaultTargetPlatform == TargetPlatform.iOS
        ? _rcApiKeyIos
        : _rcApiKeyAndroid;
    if (apiKey.isEmpty) {
      log.warn('Subscription', 'RevenueCat API key not configured');
      return;
    }

    await Purchases.configure(
      PurchasesConfiguration(apiKey)..appUserID = userId,
    );

    // Listen for customer info changes
    Purchases.addCustomerInfoUpdateListener((info) {
      final wasPremium = isPremium;
      _customerInfo = info;
      if (isPremium != wasPremium) {
        _statusController.add(isPremium);
      }
    });

    try {
      _customerInfo = await Purchases.getCustomerInfo();
    } catch (e) {
      log.warn('Subscription', 'Failed to fetch customer info', e);
    }
  }

  /// Login / identify user after auth.
  static Future<void> identify(String userId) async {
    try {
      final result = await Purchases.logIn(userId);
      _customerInfo = result.customerInfo;
      _statusController.add(isPremium);
    } catch (e) {
      log.warn('Subscription', 'Failed to identify user', e);
    }
  }

  /// Logout user (resets to anonymous).
  static Future<void> logout() async {
    try {
      _customerInfo = await Purchases.logOut();
    } catch (_) {}
  }

  /// Fetch available offerings (products + pricing).
  static Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      log.warn('Subscription', 'Failed to fetch offerings', e);
      return null;
    }
  }

  /// Purchase Pigio+ monthly subscription.
  static Future<bool> purchasePigioPlusMonthly() =>
      _purchaseProduct(kPigioPlusMonthly);

  /// Purchase Pigio+ yearly subscription.
  static Future<bool> purchasePigioPlusYearly() =>
      _purchaseProduct(kPigioPlusYearly);

  /// Purchase the seasonal Occasion Pass.
  static Future<bool> purchaseOccasionPass() =>
      _purchaseProduct(kOccasionPass);

  /// Purchase a Plumes pack (consumable IAP).
  static Future<bool> purchasePlumes(String productId) =>
      _purchaseProduct(productId);

  /// Gift a 1-month Pigio+ subscription to another user.
  static Future<bool> purchaseGiftSubscription() =>
      _purchaseProduct(kGiftPigioPlusMonth);

  /// Restore purchases (e.g. after reinstall).
  static Future<void> restorePurchases() async {
    try {
      _customerInfo = await Purchases.restorePurchases();
      _statusController.add(isPremium);
    } catch (e) {
      log.warn('Subscription', 'Restore failed', e);
    }
  }

  static Future<bool> _purchaseProduct(String productId) async {
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) return false;

      // Find the package matching the product
      Package? pkg;
      for (final p in current.availablePackages) {
        if (p.storeProduct.identifier == productId) {
          pkg = p;
          break;
        }
      }
      if (pkg == null) return false;

      _customerInfo = await Purchases.purchasePackage(pkg);
      _statusController.add(isPremium);
      return true;
    } on PurchasesErrorCode {
      return false;
    } catch (e) {
      log.warn('Subscription', 'Purchase failed for $productId', e);
      return false;
    }
  }
}
