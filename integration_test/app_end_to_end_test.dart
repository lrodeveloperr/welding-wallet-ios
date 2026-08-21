import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:welding_gas_wallet/src/app.dart';
import 'package:welding_gas_wallet/src/app_controller.dart';
import 'package:welding_gas_wallet/src/domain/welding_gas_wallet_core_v1_1.dart';
import 'package:welding_gas_wallet/src/storage.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('add cylinder, record cost, inspect spend, and delete locally',
      (tester) async {
    final empty = WalletData.empty();
    final repository = MemoryWalletRepository(empty.next(
      settings: empty.settings.copyWith(onboardingComplete: true),
    ));
    final reminders = TestReminderGateway();
    final billing = TestBillingGateway();
    final engine = WeldingGasWalletEngine(
      repo: repository,
      billing: billing,
      scheduler: reminders,
      ids: SequenceIds(),
      clock: TestClock(),
    );
    final controller = WalletController(
      engine: engine,
      billing: billing,
      reminderPermission: reminders,
      initialLocale: 'en',
      links: TestLinkGateway(),
    );
    await controller.bootstrap();
    await tester.pumpWidget(WeldingGasWalletApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text(controller.t('addCylinder')).last);
    await tester.pumpAndSettle();
    var fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Shop oxygen');
    await tester.enterText(fields.at(1), 'Oxygen');
    await tester.tap(find.text(controller.t('save')));
    await tester.pumpAndSettle();
    expect(find.text('Shop oxygen'), findsOneWidget);

    await tester.tap(find.text('Shop oxygen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(controller.t('recordCost')));
    await tester.pumpAndSettle();
    fields = find.byType(TextFormField);
    await tester.enterText(fields.first, '42.50');
    await tester.tap(find.text(controller.t('save')));
    await tester.pumpAndSettle();
    expect(controller.data!.events.where((event) => event.amount != null), hasLength(1));

    await tester.tap(find.byTooltip(controller.t('close')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(controller.t('spend')).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('42.50'), findsWidgets);

    await tester.tap(find.text(controller.t('wallet')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shop oxygen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(controller.t('deleteCylinder')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(controller.t('deleteCylinder')).last);
    await tester.pumpAndSettle();
    expect(controller.data!.cylinders, isEmpty);
  });
}
