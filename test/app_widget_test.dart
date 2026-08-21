import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:welding_gas_wallet/src/app.dart';
import 'package:welding_gas_wallet/src/app_controller.dart';
import 'package:welding_gas_wallet/src/app_strings.dart';
import 'package:welding_gas_wallet/src/domain/welding_gas_wallet_core_v1_1.dart';
import 'package:welding_gas_wallet/src/storage.dart';

import 'support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding communicates value and safety before setup',
      (tester) async {
    final harness = WidgetHarness(onboarded: false);
    await harness.controller.bootstrap();
    await tester.pumpWidget(WeldingGasWalletApp(controller: harness.controller));
    await tester.pumpAndSettle();

    expect(find.text(harness.controller.t('welcomeTitle')), findsOneWidget);
    expect(find.text(harness.controller.t('welcomePointThree')), findsOneWidget);
    await tester.tap(find.text(harness.controller.t('continueAction')));
    await tester.pumpAndSettle();
    expect(find.text(harness.controller.t('scopeTitle')), findsOneWidget);
    expect(find.text(harness.controller.t('privacyPolicy')), findsOneWidget);
    expect(find.text(harness.controller.t('termsOfUse')), findsOneWidget);

    await tester.tap(find.text(harness.controller.t('continueAction')));
    await tester.pumpAndSettle();
    expect(find.text(harness.controller.t('setupTitle')), findsOneWidget);
    await tester.tap(find.text(harness.controller.t('getStarted')));
    await tester.pumpAndSettle();
    expect(harness.controller.data!.settings.onboardingComplete, isTrue);
    expect(find.text(harness.controller.t('wallet')), findsWidgets);
  });

  testWidgets('currency choice is searchable and saved during setup',
      (tester) async {
    final harness = WidgetHarness(onboarded: false);
    await harness.controller.bootstrap();
    await tester.pumpWidget(WeldingGasWalletApp(controller: harness.controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text(harness.controller.t('continueAction')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(harness.controller.t('continueAction')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('currency-picker')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('currency-search')),
      'jpy',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('currency-JPY')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('currency-JPY')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(harness.controller.t('getStarted')));
    await tester.pumpAndSettle();

    expect(harness.controller.data!.settings.currencyCode, 'JPY');
  });

  testWidgets('all four primary destinations are present and Settings is real',
      (tester) async {
    final harness = WidgetHarness();
    await harness.controller.bootstrap();
    await tester.pumpWidget(WeldingGasWalletApp(controller: harness.controller));
    await tester.pumpAndSettle();

    for (final key in <String>['wallet', 'activity', 'spend', 'settings']) {
      expect(find.text(harness.controller.t(key)), findsWidgets);
    }
    await tester.tap(find.text(harness.controller.t('settings')).first);
    await tester.pumpAndSettle();
    expect(find.text(harness.controller.t('planAndAccess')), findsOneWidget);
    expect(find.text(harness.controller.t('dataAndBackup')), findsOneWidget);
    expect(find.text(harness.controller.t('privacyAndSafety')), findsOneWidget);
    expect(find.text(harness.controller.t('deleteAllData')), findsOneWidget);
  });

  testWidgets('fourth-cylinder editor preserves draft and shows exact store CTA',
      (tester) async {
    final harness = WidgetHarness();
    await harness.controller.bootstrap();
    for (var index = 1; index <= 3; index++) {
      await harness.controller.addCylinder(AddCylinderDraft(
        nickname: 'Cylinder $index',
        gasType: 'Argon',
        relationship: RelationshipType.owned,
      ));
    }
    await tester.pumpWidget(WeldingGasWalletApp(controller: harness.controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text(harness.controller.t('addCylinder')).last);
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Fourth oxygen');
    await tester.enterText(fields.at(1), 'Oxygen');
    await tester.tap(find.text(harness.controller.t('save')));
    await tester.pumpAndSettle();

    expect(harness.controller.data!.pendingDraft?.nickname, 'Fourth oxygen');
    expect(find.text(harness.controller.t('fourthReady')), findsOneWidget);
    expect(find.text('Subscribe annually · €11.99'), findsOneWidget);
    expect(find.text(harness.controller.t('privacyPolicy')), findsOneWidget);
    expect(find.text(harness.controller.t('termsOfUse')), findsOneWidget);
  });

  testWidgets('compact phone layout has no render overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = WidgetHarness();
    await harness.controller.bootstrap();
    await tester.pumpWidget(WeldingGasWalletApp(controller: harness.controller));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(harness.controller.t('addCylinder')).last);
    await tester.pumpAndSettle();
    final chip = find.byType(ChoiceChip).first;
    expect(tester.getSize(chip).height, greaterThanOrEqualTo(44));
  });

  testWidgets('320px phone remains operable at 200 percent text scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(
      tester.platformDispatcher.clearTextScaleFactorTestValue,
    );
    final harness = WidgetHarness();
    await harness.controller.bootstrap();
    await tester.pumpWidget(WeldingGasWalletApp(controller: harness.controller));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final addAction = find.text(harness.controller.t('addCylinder')).last;
    expect(addAction, findsOneWidget);
    await tester.ensureVisible(addAction);
    await tester.tap(addAction);
    await tester.pumpAndSettle();
    expect(find.text(harness.controller.t('save')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic uses RTL while preserving all four navigation destinations',
      (tester) async {
    final harness = WidgetHarness(initialLocale: 'ar');
    await harness.controller.bootstrap();
    await tester.pumpWidget(WeldingGasWalletApp(controller: harness.controller));
    await tester.pumpAndSettle();

    expect(harness.controller.strings!.locale, 'ar');
    expect(
      Directionality.of(tester.element(find.byType(WalletShell))),
      TextDirection.rtl,
    );
    for (final key in <String>['wallet', 'activity', 'spend', 'settings']) {
      expect(find.text(harness.controller.t(key)), findsWidgets);
    }
    await tester.tap(find.text(harness.controller.t('settings')).first);
    await tester.pumpAndSettle();
    expect(find.text(harness.controller.t('planAndAccess')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic catalog failure uses independent RTL recovery copy',
      (tester) async {
    final harness = WidgetHarness(initialLocale: 'ar');
    harness.controller
      ..localizationFailure = const LocalizationCatalogException(
        'ar',
        FormatException('deliberately corrupt test catalog'),
      )
      ..booting = false;
    final emergency = emergencyRecoveryForLocale('ar');

    await tester.pumpWidget(WeldingGasWalletApp(controller: harness.controller));
    await tester.pump();

    expect(find.text(emergency.title), findsOneWidget);
    expect(find.text(emergency.retry), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text(emergency.title))),
      TextDirection.rtl,
    );
  });

  testWidgets('Japanese catalog failure remains non-English and LTR',
      (tester) async {
    final harness = WidgetHarness(initialLocale: 'ja');
    harness.controller
      ..localizationFailure = const LocalizationCatalogException(
        'ja',
        FormatException('deliberately corrupt test catalog'),
      )
      ..booting = false;
    final emergency = emergencyRecoveryForLocale('ja');

    await tester.pumpWidget(WeldingGasWalletApp(controller: harness.controller));
    await tester.pump();

    expect(find.text(emergency.title), findsOneWidget);
    expect(emergency.title, isNot(emergencyRecoveryForLocale('en').title));
    expect(
      Directionality.of(tester.element(find.text(emergency.title))),
      TextDirection.ltr,
    );
  });

  testWidgets('desktop width switches to an extended navigation rail',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = WidgetHarness();
    await harness.controller.bootstrap();
    await tester.pumpWidget(WeldingGasWalletApp(controller: harness.controller));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}

class WidgetHarness {
  WidgetHarness({bool onboarded = true, String initialLocale = 'en'})
      : repo = MemoryWalletRepository(_seed(onboarded, initialLocale)),
        reminders = TestReminderGateway(),
        billing = TestBillingGateway(),
        clock = TestClock() {
    final engine = WeldingGasWalletEngine(
      repo: repo,
      billing: billing,
      scheduler: reminders,
      ids: SequenceIds(),
      clock: clock,
    );
    controller = WalletController(
      engine: engine,
      billing: billing,
      reminderPermission: reminders,
      initialLocale: initialLocale,
      links: TestLinkGateway(),
    );
  }

  final MemoryWalletRepository repo;
  final TestReminderGateway reminders;
  final TestBillingGateway billing;
  final TestClock clock;
  late final WalletController controller;
}

WalletData _seed(bool onboarded, String locale) {
  final empty = WalletData.empty();
  return empty.next(
    settings: empty.settings.copyWith(
      locale: locale,
      onboardingComplete: onboarded,
    ),
  );
}
