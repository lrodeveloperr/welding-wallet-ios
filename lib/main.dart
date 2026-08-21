import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'src/app.dart';
import 'src/app_controller.dart';
import 'src/billing.dart';
import 'src/domain/welding_gas_wallet_core_v1_1.dart';
import 'src/locale_money.dart';
import 'src/reminders.dart';
import 'src/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final systemLocale = Platform.localeName;
  final initialLocale = canonicalLocale(systemLocale);
  final initialCurrencyCode =
      LocaleMoney.defaultCurrencyForSystemLocale(systemLocale);
  final directory = await getApplicationSupportDirectory();
  final repository = FileWalletRepository(
    directory: directory,
    initialLocale: systemLocale,
    initialCurrencyCode: initialCurrencyCode,
  );
  const clock = SystemClock();
  final billing = InAppPurchaseBillingGateway(
    platform: Platform.isIOS ? StorePlatform.ios : StorePlatform.android,
    clock: clock,
  );
  final reminders = DeviceReminderScheduler();
  final engine = WeldingGasWalletEngine(
    repo: repository,
    billing: billing,
    scheduler: reminders,
    ids: UuidIdFactory(),
    clock: clock,
  );
  final controller = WalletController(
    engine: engine,
    billing: billing,
    reminderPermission: reminders,
    initialLocale: initialLocale,
  );
  runApp(WeldingGasWalletApp(controller: controller));
  unawaited(controller.bootstrap());
}
