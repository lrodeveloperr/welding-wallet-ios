import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart'
    as play_wrappers;
import 'package:in_app_purchase_android/in_app_purchase_android.dart'
    as play_iap;
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart'
    as storekit_iap;
import 'package:url_launcher/url_launcher.dart';

import 'domain/welding_gas_wallet_core_v1_1.dart';

/// The package name registered for Welding Gas Wallet in Google Play.
const String weldingGasWalletAndroidPackageName =
    'com.goodusestudios.weldinggaswallet';

/// A successful Google Play check creates only a short, renewable cache lease.
///
/// This is deliberately *not* the subscription expiry. Google Play's client
/// purchase API does not provide a trustworthy subscription expiry. The app
/// must refresh this lease at launch and whenever it resumes, and production
/// release remains gated on closed-track testing plus server-side verification.
const Duration androidLastVerifiedContinuityWindow = Duration(hours: 24);

/// A fail-closed error from the native store adapter.
class BillingGatewayException implements Exception {
  const BillingGatewayException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'BillingGatewayException($code): $message';
}

/// Classifies a store batch emitted for a user-initiated purchase.
///
/// A purchased/restored exact product proceeds to cryptographic verification.
/// Every other terminal state remains a non-entitling, typed outcome; none is
/// allowed to masquerade as a successful free entitlement.
PurchaseOutcome? classifyInitiatedPurchaseOutcome(
  Iterable<(String, PurchaseStatus)> updates,
  String expectedProductId,
) {
  final relevant = updates
      .where(
        (update) =>
            update.$1 == expectedProductId ||
            (update.$1.isEmpty &&
                (update.$2 == PurchaseStatus.canceled ||
                    update.$2 == PurchaseStatus.error)),
      )
      .map((update) => update.$2)
      .toList(growable: false);
  if (relevant.any(
    (status) =>
        status == PurchaseStatus.purchased ||
        status == PurchaseStatus.restored,
  )) {
    return null;
  }
  if (relevant.contains(PurchaseStatus.pending)) {
    return PurchaseOutcome.pending;
  }
  if (relevant.contains(PurchaseStatus.canceled)) {
    return PurchaseOutcome.cancelled;
  }
  return PurchaseOutcome.failed;
}

class PlaySubscriptionPlanEvidence {
  const PlaySubscriptionPlanEvidence({
    required this.productId,
    required this.basePlanId,
    required this.offerId,
    required this.offerTags,
    required this.offerTokenMatches,
    required this.hasInstallmentPlan,
    required this.pricingPhaseCount,
    required this.billingPeriod,
    required this.priceAmountMicros,
    required this.formattedPriceMatches,
    required this.currencyMatches,
    required this.recurrenceMode,
    required this.billingCycleCount,
  });

  final String productId;
  final String basePlanId;
  final String? offerId;
  final List<String> offerTags;
  final bool offerTokenMatches;
  final bool hasInstallmentPlan;
  final int pricingPhaseCount;
  final String billingPeriod;
  final int priceAmountMicros;
  final bool formattedPriceMatches;
  final bool currencyMatches;
  final play_wrappers.RecurrenceMode recurrenceMode;
  final int billingCycleCount;
}

bool matchesLockedPlaySubscriptionContract(
  PlaySubscriptionPlanEvidence evidence,
) {
  final expected = switch (evidence.productId) {
    ProductIds.androidAnnual => ('annual', 'P1Y'),
    ProductIds.androidMonthly => ('monthly', 'P1M'),
    _ => null,
  };
  return expected != null &&
      evidence.basePlanId == expected.$1 &&
      evidence.offerId == null &&
      evidence.offerTags.isEmpty &&
      evidence.offerTokenMatches &&
      !evidence.hasInstallmentPlan &&
      evidence.pricingPhaseCount == 1 &&
      evidence.billingPeriod == expected.$2 &&
      evidence.priceAmountMicros > 0 &&
      evidence.formattedPriceMatches &&
      evidence.currencyMatches &&
      evidence.recurrenceMode ==
          play_wrappers.RecurrenceMode.infiniteRecurring &&
      evidence.billingCycleCount == 0;
}

abstract interface class PlaySignatureVerifier {
  Future<bool> validatePublicKey(String licenseKeyBase64);

  Future<bool> verify({
    required String licenseKeyBase64,
    required String signedData,
    required String signatureBase64,
  });
}

/// Android-only JCA bridge. No cryptographic implementation is linked into
/// the shared Dart snapshot or iOS binary.
class AndroidJcaPlaySignatureVerifier implements PlaySignatureVerifier {
  const AndroidJcaPlaySignatureVerifier();

  static const MethodChannel _channel = MethodChannel(
    'com.goodusestudios.weldinggaswallet/play_signature',
  );

  @override
  Future<bool> validatePublicKey(String licenseKeyBase64) async {
    try {
      return await _channel.invokeMethod<bool>(
            'validatePlayPublicKey',
            <String, String>{'licenseKeyBase64': licenseKeyBase64},
          ) ??
          false;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> verify({
    required String licenseKeyBase64,
    required String signedData,
    required String signatureBase64,
  }) async {
    try {
      return await _channel.invokeMethod<bool>(
            'verifyPlaySignature',
            <String, String>{
              'licenseKeyBase64': licenseKeyBase64,
              'signedData': signedData,
              'signatureBase64': signatureBase64,
            },
          ) ??
          false;
    } on Object {
      return false;
    }
  }
}

/// Verifies the signed Google Play payload and delegates only the RSA/SHA-1
/// primitive to the Android host's JCA implementation.
///
/// Google Play Console supplies the public license key as base64-encoded X.509
/// SubjectPublicKeyInfo DER. The public key is safe to ship in the application;
/// the corresponding private key remains with Google. Exact package, token,
/// product and purchase-state checks stay in Dart and all failures deny access.
class GooglePlayPurchaseVerifier {
  GooglePlayPurchaseVerifier(
    String licenseKeyBase64, {
    PlaySignatureVerifier signatureVerifier =
        const AndroidJcaPlaySignatureVerifier(),
  })  : _licenseKeyBase64 = _normalizePublicKey(licenseKeyBase64),
        _signatureVerifier = signatureVerifier;

  final String _licenseKeyBase64;
  final PlaySignatureVerifier _signatureVerifier;
  bool _keyValidated = false;

  Future<bool> validateKey() async {
    if (_keyValidated) return true;
    _keyValidated = await _signatureVerifier.validatePublicKey(
      _licenseKeyBase64,
    );
    return _keyValidated;
  }

  Future<bool> verify({
    required String originalJson,
    required String signatureBase64,
    required String expectedProductId,
    required String expectedPackageName,
    required String expectedPurchaseToken,
  }) async {
    if (originalJson.trim().isEmpty ||
        originalJson.length > 1048576 ||
        signatureBase64.trim().isEmpty ||
        signatureBase64.length > 32768 ||
        expectedPurchaseToken.trim().isEmpty) {
      return false;
    }

    try {
      final Object? decoded = jsonDecode(originalJson);
      if (decoded is! Map<String, Object?>) return false;
      if (decoded['packageName'] != expectedPackageName ||
          decoded['purchaseToken'] != expectedPurchaseToken) {
        return false;
      }

      // Current Play Billing purchase JSON uses `productId`. Accept an exact,
      // signed singleton product list as a forward-compatible representation,
      // but never infer the product from an unsigned wrapper field alone.
      final Object? signedProductId = decoded['productId'];
      final Object? signedProducts =
          decoded['products'] ?? decoded['productIds'];
      final productMatches = signedProductId == expectedProductId ||
          (signedProductId == null &&
              signedProducts is List<Object?> &&
              signedProducts.length == 1 &&
              signedProducts.single == expectedProductId);
      if (!productMatches) return false;

      final Object? purchaseState = decoded['purchaseState'];
      if (purchaseState is! num || purchaseState.toInt() != 0) return false;
      if (!await validateKey()) return false;
      return await _signatureVerifier.verify(
        licenseKeyBase64: _licenseKeyBase64,
        signedData: originalJson,
        signatureBase64: signatureBase64,
      );
    } on FormatException {
      return false;
    } on ArgumentError {
      return false;
    } on StateError {
      return false;
    } on Object catch (_) {
      // Malformed payload, channel, signature, or key material must never
      // escape this verification boundary as an accidental grant.
      return false;
    }
  }

  static String _normalizePublicKey(String value) {
    final normalized = value.replaceAll(RegExp(r'\s'), '');
    if (normalized.isEmpty) {
      throw const BillingGatewayException(
        'play_license_key_missing',
        'PLAY_LICENSE_KEY_BASE64 is required for Google Play verification.',
      );
    }
    if (normalized.length > 32768) {
      throw const BillingGatewayException(
        'play_license_key_invalid',
        'PLAY_LICENSE_KEY_BASE64 exceeds the supported size.',
      );
    }
    try {
      // Validate canonical base64 before handing it to the Android host.
      base64Decode(normalized);
    } on FormatException {
      throw const BillingGatewayException(
        'play_license_key_invalid',
        'PLAY_LICENSE_KEY_BASE64 is not valid base64.',
      );
    }

    return normalized;
  }
}

/// Returns the platform subscription-management destination.
///
/// Google Play's product-specific URL is used only after this process has
/// verified an exact owned product. Before that, Settings opens the account's
/// general subscriptions page rather than guessing a SKU.
Uri subscriptionManagementUri({
  required StorePlatform platform,
  String? verifiedAndroidProductId,
  String androidPackageName = weldingGasWalletAndroidPackageName,
}) {
  if (platform == StorePlatform.ios) {
    return Uri.parse('https://apps.apple.com/account/subscriptions');
  }

  final productId = verifiedAndroidProductId?.trim();
  if (productId == null ||
      !ProductIds.forPlatform(StorePlatform.android).contains(productId)) {
    return Uri.parse('https://play.google.com/store/account/subscriptions');
  }
  return Uri.https(
    'play.google.com',
    '/store/account/subscriptions',
    <String, String>{
      'sku': productId,
      'package': androidPackageName,
    },
  );
}

/// Production native-store gateway.
///
/// Android grants require all of the following: the concrete Google Play
/// purchase type, a purchased/restored exact SKU, a signed payload matching the
/// SKU/package/token, a valid RSA/SHA-1 signature using the compile-time Play
/// license key, and a successful acknowledgement (or prior acknowledgement).
/// Generic purchase status alone never grants Pro.
///
/// iOS uses the endorsed StoreKit 2 implementation and accepts only its
/// concrete, verified transaction type with non-empty verification material.
class InAppPurchaseBillingGateway
    implements StoreBillingGateway, StoreEntitlementUpdateGateway {
  InAppPurchaseBillingGateway({
    required this.platform,
    required Clock clock,
    InAppPurchase? store,
    String androidPackageName = weldingGasWalletAndroidPackageName,
    Duration purchaseResultTimeout = const Duration(minutes: 2),
    Duration restoreResultTimeout = const Duration(seconds: 30),
  })  : _clock = clock,
        _store = store ?? InAppPurchase.instance,
        _androidPackageName = androidPackageName,
        _purchaseResultTimeout = purchaseResultTimeout,
        _restoreResultTimeout = restoreResultTimeout {
    // Subscribe immediately: stores can redeliver unfinished transactions as
    // soon as the plugin starts, before a paywall is visible. Every batch is
    // retained until an explicit purchase/restore reconciliation claims it;
    // the broadcast relay is therefore not the source of truth.
    _storeSubscription = _store.purchaseStream.listen(
      _onStoreBatch,
      onError: (Object error, StackTrace stackTrace) {
        if (!_disposed) _updates.addError(error, stackTrace);
      },
    );
  }

  static const String _compiledPlayLicenseKeyBase64 =
      String.fromEnvironment('PLAY_LICENSE_KEY_BASE64');

  @override
  final StorePlatform platform;

  final Clock _clock;
  final InAppPurchase _store;
  final String _androidPackageName;
  final Duration _purchaseResultTimeout;
  final Duration _restoreResultTimeout;
  final StreamController<List<PurchaseDetails>> _updates =
      StreamController<List<PurchaseDetails>>.broadcast(sync: true);
  final StreamController<void> _entitlementRefreshRequests =
      StreamController<void>.broadcast(sync: true);
  late final StreamSubscription<List<PurchaseDetails>> _storeSubscription;
  final List<List<PurchaseDetails>> _unclaimedStoreBatches =
      <List<PurchaseDetails>>[];
  final Map<String, ProductDetails> _productDetails =
      <String, ProductDetails>{};

  GooglePlayPurchaseVerifier? _playVerifier;
  String? _lastVerifiedAndroidProductId;
  bool _operationInProgress = false;
  bool _disposed = false;

  @override
  Stream<void> get entitlementRefreshRequests =>
      _entitlementRefreshRequests.stream;

  @override
  Future<List<StoreProduct>> loadProducts() async {
    _assertNotDisposed();
    if (!await _store.isAvailable()) {
      throw const BillingGatewayException(
        'store_unavailable',
        'The device store is currently unavailable.',
      );
    }

    final expected = ProductIds.forPlatform(platform);
    final response = await _store.queryProductDetails(expected.toSet());
    if (response.error != null) {
      throw BillingGatewayException(
        'product_query_failed',
        'The store could not load products (${response.error!.code}).',
      );
    }

    final returnedIds = response.productDetails.map((value) => value.id).toSet();
    final missingIds = <String>{
      ...response.notFoundIDs,
      ...expected.where((id) => !returnedIds.contains(id)),
    };
    if (missingIds.isNotEmpty) {
      throw BillingGatewayException(
        'products_missing',
        'The store is missing required products: ${missingIds.join(', ')}.',
      );
    }

    _productDetails.clear();
    for (final id in expected) {
      final candidates = response.productDetails
          .where((details) => details.id == id && details.price.trim().isNotEmpty)
          .toList(growable: false);
      if (candidates.isEmpty) {
        throw BillingGatewayException(
          'product_price_missing',
          'The store did not return a localized price for $id.',
        );
      }
      _productDetails[id] = _preferredProduct(candidates);
    }

    return expected.map((id) {
      final details = _productDetails[id]!;
      return StoreProduct(
        id: id,
        localizedPrice: details.price,
        // Store titles are localized by App Store Connect / Play Console.
        localizedPeriodLabel: details.title,
        isDefault: platform == StorePlatform.android
            ? id == ProductIds.androidAnnual
            : id == ProductIds.iosLifetime,
      );
    }).toList(growable: false);
  }

  @override
  Future<Entitlement> purchaseVerified(String productId) async {
    try {
      return await _runExclusive<Entitlement>(() async {
        _requireAllowedProduct(productId);
        if (platform == StorePlatform.android) {
          final verifier = _requirePlayVerifier();
          if (!await verifier.validateKey()) {
            throw const BillingGatewayException(
              'play_license_key_invalid',
              'The Android host rejected the Google Play public key.',
            );
          }
        }

        if (!_productDetails.containsKey(productId)) {
          await loadProducts();
        }
        final product = _productDetails[productId];
        if (product == null) {
          throw const BillingGatewayException(
            'product_unavailable',
            'The selected product is not available from the store.',
          );
        }

        final waiter = _PurchaseBatchWaiter(
          _updates.stream,
          (batch) => _isPurchaseResolutionBatch(batch, productId),
        );
        try {
          final PurchaseParam purchaseParam;
          if (platform == StorePlatform.android &&
              product is play_iap.GooglePlayProductDetails) {
            purchaseParam = play_iap.GooglePlayPurchaseParam(
              productDetails: product,
              offerToken: product.offerToken,
            );
          } else {
            purchaseParam = PurchaseParam(productDetails: product);
          }

          final launched = await _store.buyNonConsumable(
            purchaseParam: purchaseParam,
          );
          if (!launched) {
            throw const PurchaseOutcomeException(PurchaseOutcome.failed);
          }

          final batch = await waiter.future.timeout(
            _purchaseResultTimeout,
            onTimeout: () => throw const BillingGatewayException(
              'purchase_result_timeout',
              'The store did not return a purchase result in time.',
            ),
          );
          _claimStoreBatch(batch);
          final flowOutcome = classifyInitiatedPurchaseOutcome(
            batch.map((details) => (details.productID, details.status)),
            productId,
          );
          if (flowOutcome != null) {
            throw PurchaseOutcomeException(flowOutcome);
          }
          final entitlement = await _resolveVerifiedEntitlement(
            batch,
            expectedProductId: productId,
          );
          if (!entitlement.isProAt(_clock.now())) {
            throw const PurchaseOutcomeException(PurchaseOutcome.unverified);
          }
          return entitlement;
        } finally {
          await waiter.cancel();
        }
      });
    } on PurchaseOutcomeException {
      rethrow;
    } on Object catch (_) {
      throw const PurchaseOutcomeException(PurchaseOutcome.failed);
    }
  }

  @override
  Future<Entitlement> restoreOrRefreshVerified() =>
      _runExclusive<Entitlement>(() async {
        if (!await _store.isAvailable()) {
          throw const BillingGatewayException(
            'store_unavailable',
            'The device store is currently unavailable.',
          );
        }

        if (platform == StorePlatform.android) {
          final verifier = _requirePlayVerifier();
          if (!await verifier.validateKey()) {
            throw const BillingGatewayException(
              'play_license_key_invalid',
              'The Android host rejected the Google Play public key.',
            );
          }
          // Reconcile batches emitted during plugin startup before asking Play
          // again. Unfinished transactions are store-durable across process
          // death; this queue prevents loss inside the current process before
          // the controller performs its launch/resume refresh.
          final bufferedEntitlement =
              await _reconcileUnclaimedStoreBatches();
          if (bufferedEntitlement?.isProAt(_clock.now()) ?? false) {
            return bufferedEntitlement!;
          }
          final addition = _store
              .getPlatformAddition<play_iap.InAppPurchaseAndroidPlatformAddition>();
          final response = await addition.queryPastPurchases();
          if (response.error != null) {
            throw BillingGatewayException(
              'restore_failed',
              'Google Play could not refresh purchases '
                  '(${response.error!.code}).',
            );
          }
          return _resolveVerifiedEntitlement(response.pastPurchases);
        }

        final waiter = _PurchaseBatchWaiter(
          _updates.stream,
          (List<PurchaseDetails> _) => true,
        );
        try {
          // Subscribe before draining startup updates so a StoreKit delivery
          // racing this reconciliation is captured by either the queue or the
          // active waiter.
          final bufferedEntitlement =
              await _reconcileUnclaimedStoreBatches();
          if (bufferedEntitlement?.isProAt(_clock.now()) ?? false) {
            return bufferedEntitlement!;
          }
          await _store.restorePurchases();
          final batch = await waiter.future.timeout(
            _restoreResultTimeout,
            // StoreKit 2 has no distinct "restore complete with zero items"
            // transaction event. A successful AppStore.sync followed by no
            // verified delivery in the bounded window means no entitlement.
            // Store/network failures still throw from restorePurchases above.
            onTimeout: () => const <PurchaseDetails>[],
          );
          final entitlement = await _resolveVerifiedEntitlement(batch);
          _claimStoreBatch(batch);
          return entitlement;
        } finally {
          await waiter.cancel();
        }
      });

  @override
  Future<void> openSubscriptionManagement() async {
    _assertNotDisposed();
    final uri = subscriptionManagementUri(
      platform: platform,
      verifiedAndroidProductId: _lastVerifiedAndroidProductId,
      androidPackageName: _androidPackageName,
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      throw const BillingGatewayException(
        'subscription_management_unavailable',
        'The store subscription-management page could not be opened.',
      );
    }
  }

  /// Releases the early purchase-stream subscription.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _storeSubscription.cancel();
    await _updates.close();
    await _entitlementRefreshRequests.close();
    _unclaimedStoreBatches.clear();
  }

  void _onStoreBatch(List<PurchaseDetails> incoming) {
    if (_disposed) return;
    final batch = List<PurchaseDetails>.unmodifiable(incoming);
    _unclaimedStoreBatches.add(batch);
    _updates.add(batch);
    if (!_operationInProgress &&
        incoming.any(
          (details) =>
              ProductIds.forPlatform(platform).contains(details.productID) &&
              (details.status == PurchaseStatus.purchased ||
                  details.status == PurchaseStatus.restored),
        )) {
      _entitlementRefreshRequests.add(null);
    }
  }

  void _claimStoreBatch(List<PurchaseDetails> claimed) {
    _unclaimedStoreBatches.removeWhere((batch) => identical(batch, claimed));
  }

  Future<Entitlement?> _reconcileUnclaimedStoreBatches() async {
    if (_unclaimedStoreBatches.isEmpty) return null;
    final snapshot = List<List<PurchaseDetails>>.of(_unclaimedStoreBatches);
    final purchases = snapshot.expand((batch) => batch).toList(growable: false);
    final entitlement = await _resolveVerifiedEntitlement(purchases);
    for (final batch in snapshot) {
      _claimStoreBatch(batch);
    }
    return entitlement;
  }

  ProductDetails _preferredProduct(List<ProductDetails> candidates) {
    if (platform == StorePlatform.android) {
      if (candidates.length != 1 ||
          candidates.single is! play_iap.GooglePlayProductDetails) {
        throw const BillingGatewayException(
          'play_subscription_contract_mismatch',
          'Google Play returned an unexpected base plan or offer.',
        );
      }
      final candidate = candidates.single as play_iap.GooglePlayProductDetails;
      final offers = candidate.productDetails.subscriptionOfferDetails;
      final index = candidate.subscriptionIndex;
      if (offers == null ||
          index == null ||
          index < 0 ||
          index >= offers.length ||
          candidate.offerToken == null) {
        throw const BillingGatewayException(
          'play_subscription_contract_mismatch',
          'Google Play did not return the locked subscription base plan.',
        );
      }
      final offer = offers[index];
      final phase = offer.pricingPhases.length == 1
          ? offer.pricingPhases.single
          : null;
      final evidence = PlaySubscriptionPlanEvidence(
        productId: candidate.id,
        basePlanId: offer.basePlanId,
        offerId: offer.offerId,
        offerTags: offer.offerTags,
        offerTokenMatches: offer.offerIdToken.isNotEmpty &&
            candidate.offerToken == offer.offerIdToken,
        hasInstallmentPlan: offer.installmentPlanDetails != null,
        pricingPhaseCount: offer.pricingPhases.length,
        billingPeriod: phase?.billingPeriod ?? '',
        priceAmountMicros: phase?.priceAmountMicros ?? 0,
        formattedPriceMatches: phase?.formattedPrice == candidate.price,
        currencyMatches: phase?.priceCurrencyCode == candidate.currencyCode,
        recurrenceMode:
            phase?.recurrenceMode ?? play_wrappers.RecurrenceMode.nonRecurring,
        billingCycleCount: phase?.billingCycleCount ?? -1,
      );
      if (!matchesLockedPlaySubscriptionContract(evidence)) {
        throw const BillingGatewayException(
          'play_subscription_contract_mismatch',
          'Google Play base-plan cadence or pricing phases do not match the paywall.',
        );
      }
      return candidate;
    }
    if (candidates.length != 1) {
      throw const BillingGatewayException(
        'app_store_product_contract_mismatch',
        'The App Store returned an unexpected product configuration.',
      );
    }
    return candidates.first;
  }

  bool _isPurchaseResolutionBatch(
    List<PurchaseDetails> batch,
    String productId,
  ) {
    if (batch.any((details) => details.productID == productId)) return true;
    // Android emits an empty-product placeholder for a flow-level cancel/error.
    return batch.any(
      (details) =>
          details.productID.isEmpty &&
          (details.status == PurchaseStatus.canceled ||
              details.status == PurchaseStatus.error),
    );
  }

  Future<Entitlement> _resolveVerifiedEntitlement(
    List<PurchaseDetails> details, {
    String? expectedProductId,
  }) async {
    final allowed = ProductIds.forPlatform(platform);
    final candidates = details.where((purchase) {
      final correctProduct = expectedProductId == null
          ? allowed.contains(purchase.productID)
          : purchase.productID == expectedProductId;
      return correctProduct &&
          (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored);
    }).toList(growable: false);

    if (platform == StorePlatform.android) {
      candidates.sort((left, right) {
        final leftRenewing = left is play_iap.GooglePlayPurchaseDetails &&
            left.billingClientPurchase.isAutoRenewing;
        final rightRenewing = right is play_iap.GooglePlayPurchaseDetails &&
            right.billingClientPurchase.isAutoRenewing;
        if (leftRenewing != rightRenewing) return leftRenewing ? -1 : 1;
        return allowed
            .indexOf(left.productID)
            .compareTo(allowed.indexOf(right.productID));
      });
    }

    Entitlement? verified;
    for (final purchase in candidates) {
      final candidate = platform == StorePlatform.android
          ? await _verifyAndCompleteAndroid(purchase)
          : await _verifyAndCompleteStoreKit2(purchase);
      verified ??= candidate;
    }
    return verified ?? const Entitlement.free();
  }

  Future<Entitlement?> _verifyAndCompleteAndroid(
    PurchaseDetails details,
  ) async {
    if (details is! play_iap.GooglePlayPurchaseDetails ||
        details.verificationData.source != play_iap.kIAPSource) {
      return null;
    }
    final purchase = details.billingClientPurchase;
    if (purchase.purchaseState != play_wrappers.PurchaseStateWrapper.purchased ||
        purchase.packageName != _androidPackageName ||
        purchase.products.length != 1 ||
        purchase.products.single != details.productID ||
        purchase.purchaseToken.trim().isEmpty ||
        purchase.originalJson.trim().isEmpty ||
        purchase.signature.trim().isEmpty ||
        details.verificationData.localVerificationData !=
            purchase.originalJson ||
        details.verificationData.serverVerificationData !=
            purchase.purchaseToken) {
      return null;
    }

    final verifier = _requirePlayVerifier();
    final verified = await verifier.verify(
      originalJson: purchase.originalJson,
      signatureBase64: purchase.signature,
      expectedProductId: details.productID,
      expectedPackageName: _androidPackageName,
      expectedPurchaseToken: purchase.purchaseToken,
    );
    if (!verified) return null;

    if (!purchase.isAcknowledged) {
      if (!details.pendingCompletePurchase) return null;
      try {
        // A successful Future is the plugin's acknowledgement confirmation;
        // PurchaseWrapper is immutable and therefore cannot reflect it in-place.
        await _store.completePurchase(details);
      } on Object catch (_) {
        throw const BillingGatewayException(
          'acknowledgement_failed',
          'Google Play could not acknowledge the verified purchase.',
        );
      }
    }

    _lastVerifiedAndroidProductId = details.productID;
    return Entitlement(
      tier: AccessTier.pro,
      source: EntitlementSource.googlePlaySubscription,
      // This field is a 24-hour last-verified lease, never a claimed billing
      // expiry. Launch/resume refresh renews it while Play reports ownership.
      validUntil: _clock
          .now()
          .toUtc()
          .add(androidLastVerifiedContinuityWindow),
      willRenew: purchase.isAutoRenewing,
    );
  }

  Future<Entitlement?> _verifyAndCompleteStoreKit2(
    PurchaseDetails details,
  ) async {
    if (details is! storekit_iap.SK2PurchaseDetails) return null;
    final purchaseId = details.purchaseID;
    if (details.productID != ProductIds.iosLifetime ||
        purchaseId == null ||
        purchaseId.trim().isEmpty ||
        details.verificationData.source != storekit_iap.kIAPSource ||
        details.verificationData.localVerificationData.trim().isEmpty ||
        details.verificationData.serverVerificationData.trim().isEmpty) {
      return null;
    }

    if (details.pendingCompletePurchase) {
      try {
        await _store.completePurchase(details);
      } on Object catch (_) {
        throw const BillingGatewayException(
          'completion_failed',
          'The App Store could not finish the verified transaction.',
        );
      }
    }
    return const Entitlement(
      tier: AccessTier.pro,
      source: EntitlementSource.appStoreLifetime,
    );
  }

  GooglePlayPurchaseVerifier _requirePlayVerifier() {
    if (platform != StorePlatform.android) {
      throw const BillingGatewayException(
        'wrong_store_platform',
        'Google Play verification was requested on a non-Android store.',
      );
    }
    final cached = _playVerifier;
    if (cached != null) return cached;
    try {
      final verifier =
          GooglePlayPurchaseVerifier(_compiledPlayLicenseKeyBase64);
      _playVerifier = verifier;
      return verifier;
    } on BillingGatewayException {
      rethrow;
    } on Object catch (_) {
      throw const BillingGatewayException(
        'play_license_key_invalid',
        'PLAY_LICENSE_KEY_BASE64 is not a valid Google Play RSA public key.',
      );
    }
  }

  void _requireAllowedProduct(String productId) {
    if (!ProductIds.forPlatform(platform).contains(productId)) {
      throw const BillingGatewayException(
        'wrong_product',
        'The selected product does not belong to this store.',
      );
    }
  }

  Future<T> _runExclusive<T>(Future<T> Function() operation) async {
    _assertNotDisposed();
    if (_operationInProgress) {
      throw const BillingGatewayException(
        'operation_in_progress',
        'Another store operation is already in progress.',
      );
    }
    _operationInProgress = true;
    try {
      return await operation();
    } finally {
      _operationInProgress = false;
    }
  }

  void _assertNotDisposed() {
    if (_disposed) {
      throw const BillingGatewayException(
        'gateway_disposed',
        'The billing gateway has already been disposed.',
      );
    }
  }
}

class _PurchaseBatchWaiter {
  _PurchaseBatchWaiter(
    Stream<List<PurchaseDetails>> stream,
    bool Function(List<PurchaseDetails>) accepts,
  ) {
    _subscription = stream.listen(
      (batch) {
        if (!_completer.isCompleted && accepts(batch)) {
          _completer.complete(batch);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_completer.isCompleted) {
          _completer.completeError(error, stackTrace);
        }
      },
    );
  }

  final Completer<List<PurchaseDetails>> _completer =
      Completer<List<PurchaseDetails>>();
  late final StreamSubscription<List<PurchaseDetails>> _subscription;

  Future<List<PurchaseDetails>> get future => _completer.future;

  Future<void> cancel() => _subscription.cancel();
}
