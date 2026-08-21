import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart'
    as play_wrappers;
import 'package:welding_gas_wallet/src/billing.dart';
import 'package:welding_gas_wallet/src/domain/welding_gas_wallet_core_v1_1.dart';

void main() {
  group('initiated purchase outcomes', () {
    const productId = ProductIds.androidAnnual;

    test('purchased and restored exact products proceed to verification', () {
      expect(
        classifyInitiatedPurchaseOutcome(
          const <(String, PurchaseStatus)>[
            (productId, PurchaseStatus.purchased),
          ],
          productId,
        ),
        isNull,
      );
      expect(
        classifyInitiatedPurchaseOutcome(
          const <(String, PurchaseStatus)>[
            (productId, PurchaseStatus.restored),
          ],
          productId,
        ),
        isNull,
      );
    });

    test('pending, cancellation and errors remain typed non-grants', () {
      expect(
        classifyInitiatedPurchaseOutcome(
          const <(String, PurchaseStatus)>[
            (productId, PurchaseStatus.pending),
          ],
          productId,
        ),
        PurchaseOutcome.pending,
      );
      expect(
        classifyInitiatedPurchaseOutcome(
          const <(String, PurchaseStatus)>[
            ('', PurchaseStatus.canceled),
          ],
          productId,
        ),
        PurchaseOutcome.cancelled,
      );
      expect(
        classifyInitiatedPurchaseOutcome(
          const <(String, PurchaseStatus)>[
            ('', PurchaseStatus.error),
          ],
          productId,
        ),
        PurchaseOutcome.failed,
      );
    });
  });

  group('locked Google Play subscription contract', () {
    PlaySubscriptionPlanEvidence annual({
      String basePlanId = 'annual',
      String? offerId,
      List<String> offerTags = const <String>[],
      bool offerTokenMatches = true,
      bool hasInstallmentPlan = false,
      int pricingPhaseCount = 1,
      String billingPeriod = 'P1Y',
      int priceAmountMicros = 11990000,
      bool formattedPriceMatches = true,
      bool currencyMatches = true,
      play_wrappers.RecurrenceMode recurrenceMode =
          play_wrappers.RecurrenceMode.infiniteRecurring,
      int billingCycleCount = 0,
    }) =>
        PlaySubscriptionPlanEvidence(
          productId: ProductIds.androidAnnual,
          basePlanId: basePlanId,
          offerId: offerId,
          offerTags: offerTags,
          offerTokenMatches: offerTokenMatches,
          hasInstallmentPlan: hasInstallmentPlan,
          pricingPhaseCount: pricingPhaseCount,
          billingPeriod: billingPeriod,
          priceAmountMicros: priceAmountMicros,
          formattedPriceMatches: formattedPriceMatches,
          currencyMatches: currencyMatches,
          recurrenceMode: recurrenceMode,
          billingCycleCount: billingCycleCount,
        );

    test('accepts only the full-price infinite annual base plan', () {
      expect(matchesLockedPlaySubscriptionContract(annual()), isTrue);
    });

    test('rejects offer, trial, wrong cadence, installment and zero price', () {
      expect(
        matchesLockedPlaySubscriptionContract(annual(offerId: 'trial')),
        isFalse,
      );
      expect(
        matchesLockedPlaySubscriptionContract(
          annual(pricingPhaseCount: 2),
        ),
        isFalse,
      );
      expect(
        matchesLockedPlaySubscriptionContract(annual(billingPeriod: 'P1M')),
        isFalse,
      );
      expect(
        matchesLockedPlaySubscriptionContract(
          annual(hasInstallmentPlan: true),
        ),
        isFalse,
      );
      expect(
        matchesLockedPlaySubscriptionContract(annual(priceAmountMicros: 0)),
        isFalse,
      );
      expect(
        matchesLockedPlaySubscriptionContract(
          annual(
            recurrenceMode: play_wrappers.RecurrenceMode.finiteRecurring,
          ),
        ),
        isFalse,
      );
    });
  });

  group('GooglePlayPurchaseVerifier', () {
    const publicLicenseKey =
        'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCqY66MugW/9ggly6H0yEbU'
        'W1UtKlAz8erfslTqSPf+Frb5KOhfB8RynLVE6/BNu7hI6vl9oZndI4smA5D'
        'tBX8Qde+aZE1WTHn66ASveWFDl7vcqSyc6C0SsunC3GU2f1MWhWZxLg6+01'
        'ZmcTdqHhjtfP94U2XFIZB7VdpkZ0qtlwIDAQAB';
    const payload =
        '{"orderId":"GPA.1234","packageName":"com.goodusestudios.'
        'weldinggaswallet","productId":"com.gooduse.weldinggaswallet.pro.'
        'annual","purchaseTime":1787300000000,"purchaseState":0,'
        '"purchaseToken":"test-token-123","quantity":1,'
        '"acknowledged":false}';
    const signature =
        'J8Ptl2lT6W6nqRHT20qIwg+7cykL2pqK/UI7JKtzpAW7vcaU9FOskh/OpwqS'
        'u6GaAa2Wh6qEJXMq0GqD3RjmIXaRre1ZIh9oeh0oWVpJbT/e7G0gYiiUizG'
        'Il1MZ32bJnUo5RQmKEvMvvBh/ntjDHJiKw88Sut1zuqc560qH1k8=';
    const nonPurchasedPayload =
        '{"orderId":"GPA.1234","packageName":"com.goodusestudios.'
        'weldinggaswallet","productId":"com.gooduse.weldinggaswallet.pro.'
        'annual","purchaseTime":1787300000000,"purchaseState":1,'
        '"purchaseToken":"test-token-123","quantity":1,'
        '"acknowledged":false}';
    const nonPurchasedSignature =
        'WtS77L2kckgFe7a+MTc3QJsCubdndENBlWON3RmqBuhKZ1M7jWQEznzdXRxt'
        'v6SBlFtKBA5OUjSJUf2TCmQ1H6d55QbOb0T3/fLNu+cc5tQ3/gyOdubm61'
        'QSuPFVZT5FFhVNNu69mn/SttFY/zHvN4v4O02AX198fhL+Ks9/r0c=';

    late GooglePlayPurchaseVerifier verifier;

    setUp(() {
      verifier = GooglePlayPurchaseVerifier(
        publicLicenseKey,
        signatureVerifier: const _FixturePlaySignatureVerifier(
          publicKey: publicLicenseKey,
          payload: payload,
          signature: signature,
        ),
      );
    });

    Future<bool> verify({
      String originalJson = payload,
      String signatureBase64 = signature,
      String productId = ProductIds.androidAnnual,
      String packageName = weldingGasWalletAndroidPackageName,
      String purchaseToken = 'test-token-123',
    }) =>
        verifier.verify(
          originalJson: originalJson,
          signatureBase64: signatureBase64,
          expectedProductId: productId,
          expectedPackageName: packageName,
          expectedPurchaseToken: purchaseToken,
        );

    test('accepts an exact host-verified Play payload', () async {
      expect(await verify(), isTrue);
    });

    test('rejects a valid signature when the claimed SKU is different',
        () async {
      expect(await verify(productId: ProductIds.androidMonthly), isFalse);
    });

    test('rejects package and purchase-token mismatches', () async {
      expect(await verify(packageName: 'com.example.forged'), isFalse);
      expect(await verify(purchaseToken: 'different-token'), isFalse);
    });

    test('rejects payload tampering and invalid signatures', () async {
      expect(
        await verify(originalJson: payload.replaceFirst('annual', 'monthly')),
        isFalse,
      );
      expect(await verify(signatureBase64: 'AAAA'), isFalse);
    });

    test('rejects a validly signed non-purchased state', () async {
      expect(
        await verify(
          originalJson: nonPurchasedPayload,
          signatureBase64: nonPurchasedSignature,
        ),
        isFalse,
      );
    });

    test('host key rejection fails closed before signature acceptance',
        () async {
      final rejected = GooglePlayPurchaseVerifier(
        publicLicenseKey,
        signatureVerifier: const _RejectingPlaySignatureVerifier(),
      );
      expect(await rejected.validateKey(), isFalse);
      expect(
        await rejected.verify(
          originalJson: payload,
          signatureBase64: signature,
          expectedProductId: ProductIds.androidAnnual,
          expectedPackageName: weldingGasWalletAndroidPackageName,
          expectedPurchaseToken: 'test-token-123',
        ),
        isFalse,
      );
    });

    test('missing release key fails before verification', () {
      expect(
        () => GooglePlayPurchaseVerifier(''),
        throwsA(
          isA<BillingGatewayException>().having(
            (error) => error.code,
            'code',
            'play_license_key_missing',
          ),
        ),
      );
    });
  });

  group('subscription management links', () {
    test('uses the App Store account subscriptions page', () {
      expect(
        subscriptionManagementUri(platform: StorePlatform.ios).toString(),
        'https://apps.apple.com/account/subscriptions',
      );
    });

    test('does not guess an Android SKU before verification', () {
      expect(
        subscriptionManagementUri(platform: StorePlatform.android).toString(),
        'https://play.google.com/store/account/subscriptions',
      );
    });

    test('uses exact verified Android SKU and package parameters', () {
      final uri = subscriptionManagementUri(
        platform: StorePlatform.android,
        verifiedAndroidProductId: ProductIds.androidAnnual,
      );
      expect(uri.queryParameters['sku'], ProductIds.androidAnnual);
      expect(
        uri.queryParameters['package'],
        weldingGasWalletAndroidPackageName,
      );
    });

    test('verification continuity is bounded to 24 hours', () {
      expect(androidLastVerifiedContinuityWindow, const Duration(hours: 24));
    });
  });
}

class _FixturePlaySignatureVerifier implements PlaySignatureVerifier {
  const _FixturePlaySignatureVerifier({
    required this.publicKey,
    required this.payload,
    required this.signature,
  });

  final String publicKey;
  final String payload;
  final String signature;

  @override
  Future<bool> validatePublicKey(String licenseKeyBase64) async =>
      licenseKeyBase64 == publicKey;

  @override
  Future<bool> verify({
    required String licenseKeyBase64,
    required String signedData,
    required String signatureBase64,
  }) async =>
      licenseKeyBase64 == publicKey &&
      signedData == payload &&
      signatureBase64 == signature;
}

class _RejectingPlaySignatureVerifier implements PlaySignatureVerifier {
  const _RejectingPlaySignatureVerifier();

  @override
  Future<bool> validatePublicKey(String licenseKeyBase64) async => false;

  @override
  Future<bool> verify({
    required String licenseKeyBase64,
    required String signedData,
    required String signatureBase64,
  }) async => false;
}
