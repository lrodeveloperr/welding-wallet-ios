import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

import 'app_controller.dart';
import 'app_strings.dart';
import 'domain/welding_gas_wallet_core_v1_1.dart';
import 'locale_money.dart';
import 'workshop_pearl.dart';

class WeldingGasWalletApp extends StatefulWidget {
  const WeldingGasWalletApp({required this.controller, super.key});

  final WalletController controller;

  @override
  State<WeldingGasWalletApp> createState() => _WeldingGasWalletAppState();
}

class _WeldingGasWalletAppState extends State<WeldingGasWalletApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.controller.onResumed());
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final controller = widget.controller;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: controller.strings?.call('appName') ?? 'Welding Gas Wallet',
            theme: workshopPearlTheme(),
            locale: controller.strings == null
                ? const Locale('en')
                : flutterLocale(controller.strings!.locale),
            supportedLocales: flutterSupportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            builder: (context, child) => Directionality(
              textDirection: controller.strings?.isRtl == true
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: child!,
            ),
            home: _home(controller),
          );
        },
      );

  Widget _home(WalletController controller) {
    if (controller.localizationFailure case final failure?) {
      final emergency = emergencyRecoveryForLocale(failure.locale);
      return Directionality(
        textDirection:
            emergency.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: _ControlledFailure(
          title: emergency.title,
          body: emergency.body,
          onRetry: controller.bootstrap,
          retryLabel: emergency.retry,
        ),
      );
    }
    if (controller.startupError != null) {
      return _StorageFailureScreen(controller: controller);
    }
    if (controller.booting || !controller.ready) {
      return _PearlLoading(label: controller.t('appName'));
    }
    if (!controller.data!.settings.onboardingComplete) {
      return OnboardingScreen(controller: controller);
    }
    return WalletShell(controller: controller);
  }
}

class _PearlLoading extends StatelessWidget {
  const _PearlLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Semantics(
            label: label,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CylinderGlyph(size: 76),
                SizedBox(height: 22),
                SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ControlledFailure extends StatelessWidget {
  const _ControlledFailure({
    required this.title,
    required this.body,
    required this.onRetry,
    required this.retryLabel,
  });

  final String title;
  final String body;
  final Future<void> Function() onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: PearlCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const CylinderGlyph(
                        size: 68,
                        color: PearlColors.danger,
                        background: PearlColors.dangerSoft,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(body, textAlign: TextAlign.center),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: () => unawaited(onRetry()),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(retryLabel),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _StorageFailureScreen extends StatelessWidget {
  const _StorageFailureScreen({required this.controller});

  final WalletController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: PearlCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const CylinderGlyph(
                        size: 68,
                        color: PearlColors.danger,
                        background: PearlColors.dangerSoft,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        controller.t('storageProblemTitle'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        controller.t('storageProblemBody'),
                        textAlign: TextAlign.center,
                      ),
                      if (controller.errorMessage case final message?) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: PearlColors.danger),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size(48, 62)),
                        onPressed: controller.busy
                            ? null
                            : () => unawaited(
                                  controller.recoverCorruptStoreFromBackup(),
                                ),
                        icon: const Icon(Icons.file_download_outlined),
                        label: Text(controller.t('importBackup')),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: controller.busy
                            ? null
                            : () => unawaited(controller.bootstrap()),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(controller.t('retry')),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: PearlColors.danger),
                        onPressed: controller.busy
                            ? null
                            : () => unawaited(_confirmClearCorrupt(context)),
                        icon: const Icon(Icons.delete_forever_outlined),
                        label: Text(controller.t('deleteAllData')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> _confirmClearCorrupt(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: PearlColors.danger),
        title: Text(controller.t('deleteAllData')),
        content: Text(controller.t('deleteWarning')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(controller.t('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PearlColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(controller.t('deleteConfirm')),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.clearCorruptStore();
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.controller, super.key});

  final WalletController controller;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  late String _currency;
  late String _mass;
  late String _volume;

  WalletController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    final settings = c.data!.settings;
    _currency = settings.currencyCode;
    _mass = settings.defaultMassUnit;
    _volume = settings.defaultVolumeUnit;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  children: <Widget>[
                    _OnboardingProgress(step: _step),
                    const SizedBox(height: 22),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        child: SingleChildScrollView(
                          key: ValueKey<int>(_step),
                          child: _stepBody(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: <Widget>[
                        if (_step > 0)
                          OutlinedButton(
                            onPressed: c.busy ? null : () => setState(() => _step--),
                            child: Text(c.t('back')),
                          ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed:
                              c.busy ? null : () => unawaited(_continue()),
                          icon: _step == 2
                              ? const Icon(Icons.arrow_forward_rounded)
                              : const Icon(Icons.check_rounded),
                          label: Text(
                            _step == 2 ? c.t('getStarted') : c.t('continueAction'),
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
      );

  Widget _stepBody() => switch (_step) {
        0 => _OnboardingHero(controller: c),
        1 => _ScopeDisclosure(controller: c),
        _ => _SetupPreferences(
            controller: c,
            currency: _currency,
            mass: _mass,
            volume: _volume,
            onCurrency: (value) => setState(() => _currency = value),
            onMass: (value) => setState(() => _mass = value),
            onVolume: (value) => setState(() => _volume = value),
          ),
      };

  Future<void> _continue() async {
    if (_step < 2) {
      setState(() => _step++);
      return;
    }
    await c.completeOnboarding(
      currencyCode: _currency,
      massUnit: _mass,
      volumeUnit: _volume,
    );
  }
}

class _OnboardingProgress extends StatelessWidget {
  const _OnboardingProgress({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) => Row(
        children: List<Widget>.generate(3, (index) {
          final active = index <= step;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 5,
              margin: EdgeInsetsDirectional.only(end: index == 2 ? 0 : 8),
              decoration: BoxDecoration(
                color: active ? PearlColors.pine : PearlColors.line,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          );
        }),
      );
}

class _OnboardingHero extends StatelessWidget {
  const _OnboardingHero({required this.controller});

  final WalletController controller;

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[PearlColors.pine, Color(0xFF67ADEB)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: PearlColors.heroShadow,
                  blurRadius: 34,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              children: <Widget>[
                const CylinderGlyph(
                  size: 92,
                  color: Colors.white,
                  background: Color(0x2AFFFFFF),
                ),
                const SizedBox(height: 25),
                Text(
                  controller.t('welcomeTitle'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 15),
                Text(
                  controller.t('welcomeBody'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          for (final item in <(IconData, String)>[
            (Icons.grid_view_rounded, controller.t('welcomePointOne')),
            (Icons.bolt_rounded, controller.t('welcomePointTwo')),
            (Icons.lock_outline_rounded, controller.t('welcomePointThree')),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PearlCard(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: <Widget>[
                    Icon(item.$1, color: PearlColors.pine),
                    const SizedBox(width: 14),
                    Expanded(child: Text(item.$2)),
                  ],
                ),
              ),
            ),
        ],
      );
}

class _ScopeDisclosure extends StatelessWidget {
  const _ScopeDisclosure({required this.controller});

  final WalletController controller;

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          const SizedBox(height: 20),
          const CylinderGlyph(
            size: 86,
            color: PearlColors.copper,
            background: PearlColors.copperSoft,
          ),
          const SizedBox(height: 24),
          Text(
            controller.t('scopeTitle'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 14),
          Text(
            controller.t('scopeBody'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          PearlCard(
            color: PearlColors.copperSoft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.health_and_safety_outlined,
                    color: PearlColors.warning),
                const SizedBox(width: 14),
                Expanded(child: Text(controller.t('safetyBody'))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: <Widget>[
              TextButton(
                onPressed: () =>
                    unawaited(controller.openLegal(LegalLinks.privacy)),
                child: Text(controller.t('privacyPolicy')),
              ),
              TextButton(
                onPressed: () =>
                    unawaited(controller.openLegal(LegalLinks.terms)),
                child: Text(controller.t('termsOfUse')),
              ),
              TextButton(
                onPressed: () =>
                    unawaited(controller.openLegal(LegalLinks.disclaimer)),
                child: Text(controller.t('disclaimer')),
              ),
            ],
          ),
        ],
      );
}

const _specialPurposeCurrencyCodes = <String>{
  'BOV',
  'CHE',
  'CHW',
  'CLF',
  'COU',
  'MXV',
  'USN',
  'UYI',
  'UYW',
  'XAG',
  'XAU',
  'XBA',
  'XBB',
  'XBC',
  'XBD',
  'XDR',
  'XPD',
  'XPT',
  'XSU',
  'XTS',
  'XUA',
  'XXX',
};

List<String> _currencyChoices(String selected) {
  final choices = iso4217Codes
      .where((code) => !_specialPurposeCurrencyCodes.contains(code))
      .toList(growable: true);
  if (!choices.contains(selected)) choices.add(selected);
  choices.sort();
  return choices;
}

class _CurrencyPickerField extends StatelessWidget {
  const _CurrencyPickerField({
    required this.value,
    required this.label,
    required this.closeLabel,
    required this.onChanged,
  });

  final String value;
  final String label;
  final String closeLabel;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
        key: const ValueKey<String>('currency-picker'),
        button: true,
        excludeSemantics: true,
        label: '$label: $value',
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final selected = await showModalBottomSheet<String>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (context) => _CurrencyPickerSheet(
                selected: value,
                label: label,
                closeLabel: closeLabel,
              ),
            );
            if (selected != null && context.mounted) onChanged(selected);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              suffixIcon: const Icon(Icons.expand_more_rounded),
            ),
            child: Text(value),
          ),
        ),
      );
}

class _CurrencyPickerSheet extends StatefulWidget {
  const _CurrencyPickerSheet({
    required this.selected,
    required this.label,
    required this.closeLabel,
  });

  final String selected;
  final String label;
  final String closeLabel;

  @override
  State<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<_CurrencyPickerSheet> {
  final TextEditingController _query = TextEditingController();
  late final List<String> _choices = _currencyChoices(widget.selected);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim().toUpperCase();
    final visible = query.isEmpty
        ? _choices
        : _choices.where((code) => code.contains(query)).toList(growable: false);
    final maximumHeight = math
        .min(640.0, MediaQuery.sizeOf(context).height * 0.86)
        .toDouble();
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maximumHeight),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _SheetTitle(title: widget.label, close: widget.closeLabel),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('currency-search'),
              controller: _query,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: widget.label,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: visible.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final code = visible[index];
                  final selected = code == widget.selected;
                  return ListTile(
                    key: ValueKey<String>('currency-$code'),
                    minTileHeight: 48,
                    title: Text(code),
                    trailing: selected
                        ? const Icon(Icons.check_rounded, color: PearlColors.pine)
                        : null,
                    onTap: () => Navigator.pop(context, code),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupPreferences extends StatelessWidget {
  const _SetupPreferences({
    required this.controller,
    required this.currency,
    required this.mass,
    required this.volume,
    required this.onCurrency,
    required this.onMass,
    required this.onVolume,
  });

  final WalletController controller;
  final String currency;
  final String mass;
  final String volume;
  final ValueChanged<String> onCurrency;
  final ValueChanged<String> onMass;
  final ValueChanged<String> onVolume;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 12),
          Text(controller.t('setupTitle'),
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 10),
          Text(controller.t('setupBody')),
          const SizedBox(height: 24),
          PearlCard(
            child: Column(
              children: <Widget>[
                _CurrencyPickerField(
                  value: currency,
                  label: controller.t('currency'),
                  closeLabel: controller.t('close'),
                  onChanged: onCurrency,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: mass,
                  decoration: InputDecoration(labelText: controller.t('massUnit')),
                  items: const <String>['kg', 'lb']
                      .map((value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ))
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) onMass(value);
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: volume,
                  decoration: InputDecoration(labelText: controller.t('volumeUnit')),
                  items: const <String>['L', 'm3', 'ft3']
                      .map((value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ))
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) onVolume(value);
                  },
                ),
              ],
            ),
          ),
        ],
      );
}

class WalletShell extends StatefulWidget {
  const WalletShell({required this.controller, super.key});

  final WalletController controller;

  @override
  State<WalletShell> createState() => _WalletShellState();
}

class _WalletShellState extends State<WalletShell> {
  int _index = 0;
  String? _shownNotice;
  String? _shownError;
  bool _selectionPromptOpen = false;

  WalletController get c => widget.controller;

  @override
  Widget build(BuildContext context) {
    _showTransientMessages();
    _offerDowngradeSelection();
    final pages = <Widget>[
      WalletScreen(controller: c, onAdd: () => unawaited(_openAdd())),
      ActivityScreen(controller: c),
      SpendScreen(controller: c),
      SettingsScreen(controller: c),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      final content = IndexedStack(index: _index, children: pages);
      return Scaffold(
        body: SafeArea(
          child: wide
              ? Row(
                  children: <Widget>[
                    _PearlRail(
                      controller: c,
                      selectedIndex: _index,
                      onSelected: (value) => setState(() => _index = value),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: content),
                  ],
                )
              : content,
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (value) => setState(() => _index = value),
                destinations: _destinations(c),
              ),
        floatingActionButton: _index == 0
            ? SizedBox(
                width: math.min(480, MediaQuery.sizeOf(context).width - 32),
                height: 62,
                child: FilledButton.icon(
                  onPressed:
                      c.busy ? null : () => unawaited(_openAdd()),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(c.t('addCylinder')),
                ),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      );
    });
  }

  void _showTransientMessages() {
    final message = c.errorMessage;
    if (message != null && message != _shownError) {
      _shownError = message;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      });
    }
    final notice = c.noticeMessage;
    if (notice != null && notice != _shownNotice) {
      _shownNotice = notice;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notice),
            backgroundColor: PearlColors.pine,
          ),
        );
      });
    }
  }

  void _offerDowngradeSelection() {
    final needsSelection = !c.isPro &&
        c.currentCylinders.length > freeEditableCylinderLimit &&
        c.currentCylinders.every((item) => !item.isFreeEditableSelection);
    if (!needsSelection || _selectionPromptOpen) return;
    _selectionPromptOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        builder: (context) => FreeSelectionSheet(controller: c),
      );
      _selectionPromptOpen = false;
    });
  }

  Future<void> _openAdd() async {
    final result = await showModalBottomSheet<AddResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => CylinderEditorSheet(controller: c),
    );
    if (!mounted || result is! AddRequiresPaywall) return;
    await showPaywall(context, c, reason: result.reason);
  }
}

List<NavigationDestination> _destinations(WalletController c) =>
    <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.account_balance_wallet_outlined),
        selectedIcon: const Icon(Icons.account_balance_wallet_rounded),
        label: c.t('wallet'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.receipt_long_outlined),
        selectedIcon: const Icon(Icons.receipt_long_rounded),
        label: c.t('activity'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.donut_large_outlined),
        selectedIcon: const Icon(Icons.donut_large_rounded),
        label: c.t('spend'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.tune_outlined),
        selectedIcon: const Icon(Icons.tune_rounded),
        label: c.t('settings'),
      ),
    ];

class _PearlRail extends StatelessWidget {
  const _PearlRail({
    required this.controller,
    required this.selectedIndex,
    required this.onSelected,
  });

  final WalletController controller;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
        width: 244,
        color: PearlColors.surface,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 18),
              child: Row(
                children: <Widget>[
                  const CylinderGlyph(size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      controller.t('appName'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: NavigationRail(
                extended: true,
                minExtendedWidth: 224,
                selectedIndex: selectedIndex,
                onDestinationSelected: onSelected,
                groupAlignment: -0.8,
                backgroundColor: PearlColors.surface,
                indicatorColor: PearlColors.mint,
                destinations: <NavigationRailDestination>[
                  for (final destination in _destinations(controller))
                    NavigationRailDestination(
                      icon: destination.icon,
                      selectedIcon: destination.selectedIcon,
                      label: Text(destination.label),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: _PlanPill(controller: controller),
            ),
          ],
        ),
      );
}

class _PlanPill extends StatelessWidget {
  const _PlanPill({required this.controller});

  final WalletController controller;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: controller.isPro ? PearlColors.successSoft : PearlColors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              controller.isPro ? Icons.workspace_premium_rounded : Icons.lock_open_rounded,
              size: 20,
              color: controller.isPro ? PearlColors.success : PearlColors.inkMuted,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                controller.isPro ? controller.t('proPlan') : controller.t('freePlan'),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
      );
}

class WalletScreen extends StatelessWidget {
  const WalletScreen({
    required this.controller,
    required this.onAdd,
    super.key,
  });

  final WalletController controller;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final data = controller.data!;
    final current = data.cylinders
        .where((item) => item.consumesCurrentSlot)
        .toList(growable: false);
    final upcoming = data.reminders.where((item) => !item.completed).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return CustomScrollView(
      key: const PageStorageKey<String>('wallet'),
      slivers: <Widget>[
        SliverToBoxAdapter(child: _PageHeader(controller: controller)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          sliver: SliverList.list(
            children: <Widget>[
              _WalletHero(controller: controller),
              const SizedBox(height: 28),
              SectionHeading(
                controller.t('currentCylinders'),
                trailing: _CountChip(
                  label: controller.isPro
                      ? controller.t('unlimited')
                      : '${current.length}/$freeEditableCylinderLimit',
                ),
              ),
              const SizedBox(height: 13),
              if (current.isEmpty)
                _EmptyState(
                  icon: Icons.add_circle_outline_rounded,
                  title: controller.t('noCylindersTitle'),
                  body: controller.t('noCylindersBody'),
                  action: FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(controller.t('addFirstCylinder')),
                  ),
                )
              else
                ...current.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CylinderCard(controller: controller, cylinder: item),
                    )),
              const SizedBox(height: 18),
              SectionHeading(controller.t('upcomingReminders')),
              const SizedBox(height: 13),
              if (upcoming.isEmpty)
                PearlCard(
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.notifications_none_rounded,
                          color: PearlColors.inkMuted),
                      const SizedBox(width: 12),
                      Expanded(child: Text(controller.t('remindersBody'))),
                    ],
                  ),
                )
              else
                ...upcoming.take(4).map((reminder) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ReminderRow(
                        controller: controller,
                        reminder: reminder,
                      ),
                    )),
            ],
          ),
        ),
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.controller, this.title});

  final WalletController controller;
  final String? title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Row(
            children: <Widget>[
              const CylinderGlyph(size: 45),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title ?? controller.t('appName'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (title == null)
                      Text(
                        controller.t('tagline'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              _PlanPillCompact(controller: controller),
            ],
          ),
        ),
      );
}

class _PlanPillCompact extends StatelessWidget {
  const _PlanPillCompact({required this.controller});

  final WalletController controller;

  @override
  Widget build(BuildContext context) => Semantics(
        label: controller.isPro ? controller.t('proPlan') : controller.t('freePlan'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: controller.isPro ? PearlColors.successSoft : PearlColors.surfaceMuted,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                controller.isPro
                    ? Icons.workspace_premium_rounded
                    : Icons.lock_open_rounded,
                size: 17,
                color: controller.isPro ? PearlColors.success : PearlColors.inkMuted,
              ),
              const SizedBox(width: 6),
              Text(controller.isPro ? controller.t('proPlan') : controller.t('freePlan')),
            ],
          ),
        ),
      );
}

class _WalletHero extends StatelessWidget {
  const _WalletHero({required this.controller});

  final WalletController controller;

  @override
  Widget build(BuildContext context) {
    final data = controller.data!;
    final current = data.cylinders.where((item) => item.consumesCurrentSlot).length;
    final due = data.reminders.where((item) => !item.completed).length;
    final events = data.events.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[PearlColors.pine, Color(0xFF67ADEB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: PearlColors.heroShadow,
            offset: Offset(0, 14),
            blurRadius: 34,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            controller.t('statusAtGlance'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(child: _Metric(value: '$current', label: controller.t('current'))),
              const _MetricDivider(),
              Expanded(child: _Metric(value: '$due', label: controller.t('needsAttention'))),
              const _MetricDivider(),
              Expanded(child: _Metric(value: '$events', label: controller.t('recorded'))),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          Text(
            value,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
          ),
        ],
      );
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 54,
        color: Colors.white.withValues(alpha: 0.16),
      );
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: PearlColors.mint,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: PearlColors.pine,
                fontWeight: FontWeight.w700,
              ),
        ),
      );
}

class _CylinderCard extends StatelessWidget {
  const _CylinderCard({required this.controller, required this.cylinder});

  final WalletController controller;
  final Cylinder cylinder;

  @override
  Widget build(BuildContext context) {
    final readOnly = !controller.isPro &&
        controller.currentCylinders.length > freeEditableCylinderLimit &&
        !cylinder.isFreeEditableSelection;
    return PearlCard(
      onTap: () =>
          unawaited(showCylinderDetail(context, controller, cylinder.id)),
      semanticLabel: '${cylinder.nickname}, ${cylinder.gasType}',
      child: Row(
        children: <Widget>[
          CylinderGlyph(
            size: 58,
            color: readOnly ? PearlColors.inkMuted : PearlColors.pine,
            background: readOnly ? PearlColors.surfaceMuted : PearlColors.mint,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        cylinder.nickname,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (readOnly)
                      Tooltip(
                        message: controller.t('readOnlyCylinder'),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          size: 19,
                          color: PearlColors.inkMuted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(cylinder.gasType),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  children: <Widget>[
                    _MiniTag(_relationshipLabel(controller, cylinder.relationship)),
                    if (cylinder.capacityValue != null)
                      _MiniTag(
                        '${_formatDecimal(cylinder.capacityValue!, controller.strings!.locale)} ${cylinder.capacityUnit ?? ''}',
                      ),
                    _MiniTag(controller.t(cylinder.lifecycle.name)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: PearlColors.inkMuted),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: PearlColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: Theme.of(context).textTheme.labelSmall),
      );
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.controller, required this.reminder});

  final WalletController controller;
  final Reminder reminder;

  @override
  Widget build(BuildContext context) {
    final overdue = reminder.dueAt.isBefore(DateTime.now().toUtc());
    return PearlCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: overdue ? PearlColors.copperSoft : PearlColors.mint,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              overdue ? Icons.notification_important_outlined : Icons.notifications_outlined,
              color: overdue ? PearlColors.warning : PearlColors.pine,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(reminder.title, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '${overdue ? '${controller.t('overdue')} · ' : ''}${_dateTime(context, reminder.dueAt)}',
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: controller.busy
                ? null
                : () => unawaited(controller.completeReminder(reminder.id)),
            child: Text(controller.t('complete')),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => PearlCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 40, color: PearlColors.pine),
            const SizedBox(height: 13),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 7),
            Text(body, textAlign: TextAlign.center),
            if (action != null) ...<Widget>[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      );
}

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({required this.controller, super.key});

  final WalletController controller;

  @override
  Widget build(BuildContext context) {
    final events = controller.data!.events.toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return CustomScrollView(
      key: const PageStorageKey<String>('activity'),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: _PageHeader(
            controller: controller,
            title: controller.t('activity'),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: events.isEmpty
              ? SliverToBoxAdapter(
                  child: _EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: controller.t('noActivityTitle'),
                    body: controller.t('noActivityBody'),
                  ),
                )
              : SliverList.separated(
                  itemCount: events.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _EventRow(
                    controller: controller,
                    event: events[index],
                  ),
                ),
        ),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.controller, required this.event});

  final WalletController controller;
  final CylinderEvent event;

  @override
  Widget build(BuildContext context) {
    final cylinder = controller.data!.cylinders
        .where((item) => item.id == event.cylinderId)
        .firstOrNull;
    final visual = _eventVisual(event.type);
    return PearlCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: visual.$2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(visual.$1, color: visual.$3),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _eventLabel(controller, event.type),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(cylinder?.nickname ?? controller.t('archived')),
                if (event.note != null) ...<Widget>[
                  const SizedBox(height: 5),
                  Text(
                    event.note!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 7),
                Text(
                  _dateTime(context, event.occurredAt),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: PearlColors.inkMuted,
                      ),
                ),
              ],
            ),
          ),
          if (event.amount case final amount?)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 10, top: 2),
              child: Text(
                _formatMoney(amount, controller.strings!.locale),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: PearlColors.pine,
                      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

(IconData, Color, Color) _eventVisual(CylinderEventType type) => switch (type) {
      CylinderEventType.refill =>
        (Icons.water_drop_outlined, PearlColors.mint, PearlColors.pine),
      CylinderEventType.exchange =>
        (Icons.swap_horiz_rounded, PearlColors.mint, PearlColors.pine),
      CylinderEventType.cost ||
      CylinderEventType.purchase ||
      CylinderEventType.rentalPayment ||
      CylinderEventType.leasePayment ||
      CylinderEventType.depositPaid ||
      CylinderEventType.depositReturned =>
        (Icons.payments_outlined, PearlColors.successSoft, PearlColors.success),
      CylinderEventType.reminderCreated || CylinderEventType.reminderCompleted =>
        (Icons.notifications_outlined, PearlColors.mint, PearlColors.pine),
      CylinderEventType.returned || CylinderEventType.archived =>
        (Icons.inventory_2_outlined, PearlColors.surfaceMuted, PearlColors.inkMuted),
      _ => (Icons.edit_note_rounded, PearlColors.mint, PearlColors.pine),
    };

String _eventLabel(WalletController c, CylinderEventType type) => switch (type) {
      CylinderEventType.created => c.t('created'),
      CylinderEventType.refill => c.t('refill'),
      CylinderEventType.exchange => c.t('exchange'),
      CylinderEventType.cost => c.t('cost'),
      CylinderEventType.purchase => c.t('purchase'),
      CylinderEventType.rentalPayment => c.t('rentalPayment'),
      CylinderEventType.leasePayment => c.t('leasePayment'),
      CylinderEventType.depositPaid => c.t('depositPaid'),
      CylinderEventType.depositReturned => c.t('depositReturned'),
      CylinderEventType.supplierChanged => c.t('supplierChanged'),
      CylinderEventType.relationshipChanged => c.t('relationshipChanged'),
      CylinderEventType.returned => c.t('eventReturned'),
      CylinderEventType.archived => c.t('eventArchived'),
      CylinderEventType.reminderCreated => c.t('reminderCreated'),
      CylinderEventType.reminderCompleted => c.t('reminderCompleted'),
    };

class SpendScreen extends StatelessWidget {
  const SpendScreen({required this.controller, super.key});

  final WalletController controller;

  @override
  Widget build(BuildContext context) {
    final totals = <String, int>{};
    for (final event in controller.data!.events) {
      final amount = event.amount;
      if (amount == null) continue;
      final signedMinorUnits = event.type == CylinderEventType.depositReturned
          ? -amount.minorUnits
          : amount.minorUnits;
      totals.update(
        amount.currencyCode,
        (value) => value + signedMinorUnits,
        ifAbsent: () => signedMinorUnits,
      );
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return CustomScrollView(
      key: const PageStorageKey<String>('spend'),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: _PageHeader(
            controller: controller,
            title: controller.t('spend'),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverList.list(
            children: <Widget>[
              if (sorted.isEmpty)
                _EmptyState(
                  icon: Icons.donut_large_outlined,
                  title: controller.t('noSpendTitle'),
                  body: controller.t('noSpendBody'),
                )
              else ...<Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[PearlColors.pine, Color(0xFF5A9FE0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: PearlColors.heroShadow,
                        offset: Offset(0, 14),
                        blurRadius: 34,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        controller.t('spendByCurrency'),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      for (final entry in sorted)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 13),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 48,
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _formatMinorUnits(
                                    entry.value,
                                    entry.key,
                                    controller.strings!.locale,
                                  ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontFeatures: const <FontFeature>[
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                PearlCard(
                  color: PearlColors.mint,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.currency_exchange_rounded,
                          color: PearlColors.pine),
                      const SizedBox(width: 12),
                      Expanded(child: Text(controller.t('multiCurrencyNote'))),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SectionHeading(controller.t('allActivity')),
                const SizedBox(height: 12),
                ...controller.data!.events
                    .where((event) => event.amount != null)
                    .toList()
                    .reversed
                    .take(8)
                    .map((event) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _EventRow(controller: controller, event: event),
                        )),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.controller, super.key});

  final WalletController controller;

  @override
  Widget build(BuildContext context) {
    final settings = controller.data!.settings;
    return CustomScrollView(
      key: const PageStorageKey<String>('settings'),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: _PageHeader(
            controller: controller,
            title: controller.t('settings'),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 36),
          sliver: SliverList.list(
            children: <Widget>[
              SectionHeading(controller.t('planAndAccess')),
              const SizedBox(height: 12),
              _PlanSettingsCard(controller: controller),
              const SizedBox(height: 24),
              SectionHeading(controller.t('appearanceAndRegion')),
              const SizedBox(height: 12),
              PearlCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    _SettingsRow(
                      icon: Icons.language_rounded,
                      title: controller.t('language'),
                      value: localeNativeNames[settings.locale] ?? settings.locale,
                      onTap: () =>
                          unawaited(_showLanguagePicker(context, controller)),
                    ),
                    const Divider(height: 1),
                    _SettingsRow(
                      icon: Icons.payments_outlined,
                      title: controller.t('currency'),
                      value: settings.currencyCode,
                      onTap: () =>
                          unawaited(_showRegionalSettings(context, controller)),
                    ),
                    const Divider(height: 1),
                    _SettingsRow(
                      icon: Icons.straighten_rounded,
                      title: '${controller.t('massUnit')} · ${controller.t('volumeUnit')}',
                      value:
                          '${settings.defaultMassUnit} · ${settings.defaultVolumeUnit}',
                      onTap: () =>
                          unawaited(_showRegionalSettings(context, controller)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SectionHeading(controller.t('reminders')),
              const SizedBox(height: 12),
              PearlCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.notifications_outlined,
                      color: PearlColors.pine),
                  title: Text(controller.t('reminders')),
                  subtitle: Text(controller.t('remindersBody')),
                  value: settings.remindersEnabled,
                  onChanged: controller.busy
                      ? null
                      : (value) =>
                          unawaited(controller.setRemindersEnabled(value)),
                ),
              ),
              const SizedBox(height: 24),
              SectionHeading(
                controller.t('suppliers'),
                trailing: TextButton.icon(
                  onPressed: () =>
                      unawaited(_showSupplierEditor(context, controller)),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(controller.t('add')),
                ),
              ),
              const SizedBox(height: 12),
              _SupplierSettings(controller: controller),
              const SizedBox(height: 24),
              SectionHeading(controller.t('dataAndBackup')),
              const SizedBox(height: 12),
              PearlCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    Builder(builder: (buttonContext) {
                      return _SettingsRow(
                        icon: Icons.ios_share_rounded,
                        title: controller.t('exportBackup'),
                        onTap: () {
                          final box = buttonContext.findRenderObject()! as RenderBox;
                          unawaited(
                            controller.exportBackup(
                              sharePositionOrigin:
                                  box.localToGlobal(Offset.zero) & box.size,
                            ),
                          );
                        },
                      );
                    }),
                    const Divider(height: 1),
                    _SettingsRow(
                      icon: Icons.file_download_outlined,
                      title: controller.t('importBackup'),
                      subtitle: controller.t('importWarning'),
                      onTap: () =>
                          unawaited(_confirmImport(context, controller)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SectionHeading(controller.t('privacyAndSafety')),
              const SizedBox(height: 12),
              PearlCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    _LegalRow(
                      controller: controller,
                      icon: Icons.shield_outlined,
                      title: 'privacyPolicy',
                      uri: LegalLinks.privacy,
                    ),
                    const Divider(height: 1),
                    _LegalRow(
                      controller: controller,
                      icon: Icons.description_outlined,
                      title: 'termsOfUse',
                      uri: LegalLinks.terms,
                    ),
                    const Divider(height: 1),
                    _LegalRow(
                      controller: controller,
                      icon: Icons.health_and_safety_outlined,
                      title: 'disclaimer',
                      uri: LegalLinks.disclaimer,
                    ),
                    const Divider(height: 1),
                    _LegalRow(
                      controller: controller,
                      icon: Icons.support_agent_rounded,
                      title: 'support',
                      uri: LegalLinks.support,
                    ),
                    const Divider(height: 1),
                    _LegalRow(
                      controller: controller,
                      icon: Icons.delete_outline_rounded,
                      title: 'deletionHelp',
                      uri: LegalLinks.deletion,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PearlCard(
                color: PearlColors.mint,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      controller.t('privacyTitle'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(controller.t('privacyBody')),
                    const SizedBox(height: 14),
                    Text(
                      controller.t('safetyTitle'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(controller.t('safetyBody')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: PearlColors.danger),
                onPressed: () =>
                    unawaited(_confirmDelete(context, controller)),
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(controller.t('deleteAllData')),
              ),
              const SizedBox(height: 22),
              Text(
                '${controller.t('version')} 1.0.0',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanSettingsCard extends StatelessWidget {
  const _PlanSettingsCard({required this.controller});

  final WalletController controller;

  @override
  Widget build(BuildContext context) => PearlCard(
        color: controller.isPro ? PearlColors.successSoft : PearlColors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: controller.isPro ? PearlColors.successSoft : PearlColors.mint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    controller.isPro
                        ? Icons.workspace_premium_rounded
                        : Icons.account_balance_wallet_outlined,
                    color: controller.isPro ? PearlColors.success : PearlColors.pine,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        controller.isPro
                            ? controller.t('proPlan')
                            : controller.t('freePlan'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        controller.isPro
                            ? controller.t('proPlanBody')
                            : controller.t('freePlanBody'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!controller.isPro)
              FilledButton.icon(
                onPressed: () => unawaited(
                  showPaywall(
                    context,
                    controller,
                    reason: PaywallReason.addFourthCylinder,
                  ),
                ),
                icon: const Icon(Icons.workspace_premium_outlined),
                label: Text(controller.t('upgrade')),
              ),
            if (controller.billing.platform == StorePlatform.ios)
              TextButton(
                onPressed: controller.refreshingStore
                    ? null
                    : () => unawaited(controller.restore()),
                child: Text(controller.t('restorePurchases')),
              )
            else
              TextButton(
                onPressed: () =>
                    unawaited(controller.manageSubscription()),
                child: Text(controller.t('manageSubscription')),
              ),
            if (controller.storeStatusMessage case final status?)
              Text(
                status,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.value,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? value;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        minTileHeight: 62,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: PearlColors.pine),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (value != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: PearlColors.inkMuted),
                ),
              ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded, color: PearlColors.inkMuted),
          ],
        ),
        onTap: onTap,
      );
}

class _LegalRow extends StatelessWidget {
  const _LegalRow({
    required this.controller,
    required this.icon,
    required this.title,
    required this.uri,
  });

  final WalletController controller;
  final IconData icon;
  final String title;
  final Uri uri;

  @override
  Widget build(BuildContext context) => _SettingsRow(
        icon: icon,
        title: controller.t(title),
        onTap: () => unawaited(controller.openLegal(uri)),
      );
}

class _SupplierSettings extends StatelessWidget {
  const _SupplierSettings({required this.controller});

  final WalletController controller;

  @override
  Widget build(BuildContext context) {
    final suppliers = controller.data!.suppliers;
    if (suppliers.isEmpty) {
      return PearlCard(
        child: Row(
          children: <Widget>[
            const Icon(Icons.storefront_outlined, color: PearlColors.inkMuted),
            const SizedBox(width: 12),
            Expanded(child: Text(controller.t('noSuppliers'))),
          ],
        ),
      );
    }
    return PearlCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (final indexed in suppliers.indexed) ...<Widget>[
            if (indexed.$1 > 0) const Divider(height: 1),
            ListTile(
              minTileHeight: 60,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              leading: const Icon(Icons.storefront_outlined, color: PearlColors.pine),
              title: Text(indexed.$2.name),
              subtitle: indexed.$2.notes == null ? null : Text(indexed.$2.notes!),
            ),
          ],
        ],
      ),
    );
  }
}

class CylinderEditorSheet extends StatefulWidget {
  const CylinderEditorSheet({
    required this.controller,
    super.key,
    this.cylinder,
  });

  final WalletController controller;
  final Cylinder? cylinder;

  @override
  State<CylinderEditorSheet> createState() => _CylinderEditorSheetState();
}

class _CylinderEditorSheetState extends State<CylinderEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nickname;
  late final TextEditingController _gas;
  late final TextEditingController _capacity;
  late final TextEditingController _serial;
  late final TextEditingController _cost;
  late RelationshipType _relationship;
  String? _capacityUnit;
  String? _supplierId;
  DateTime? _acquiredAt;

  WalletController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    final existing = widget.cylinder;
    final draft = existing == null ? c.data!.pendingDraft : null;
    _nickname = TextEditingController(text: existing?.nickname ?? draft?.nickname ?? '');
    _gas = TextEditingController(text: existing?.gasType ?? draft?.gasType ?? '');
    _capacity = TextEditingController(
      text: existing?.capacityValue == null
          ? draft?.capacityValue?.toString() ?? ''
          : _formatDecimal(existing!.capacityValue!, c.strings!.locale),
    );
    _serial = TextEditingController(
      text: existing?.serialNumber ?? draft?.serialNumber ?? '',
    );
    final amount = existing?.acquisitionAmount ?? draft?.acquisitionAmount;
    _cost = TextEditingController(
      text: amount == null
          ? ''
          : _minorToInput(
              amount.minorUnits,
              amount.currencyCode,
              c.strings!.locale,
            ),
    );
    _relationship =
        existing?.relationship ?? draft?.relationship ?? RelationshipType.notSure;
    _capacityUnit = existing?.capacityUnit ?? draft?.capacityUnit;
    _supplierId = existing?.supplierId ?? draft?.supplierId;
    _acquiredAt = existing?.acquiredAt?.toLocal() ?? draft?.acquiredAt?.toLocal();
  }

  @override
  void dispose() {
    _nickname.dispose();
    _gas.dispose();
    _capacity.dispose();
    _serial.dispose();
    _cost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const CylinderGlyph(size: 50),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.cylinder == null
                              ? c.t('addCylinder')
                              : c.t('edit'),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: c.t('close'),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  if (widget.cylinder == null && c.data!.pendingDraft != null) ...<Widget>[
                    const SizedBox(height: 12),
                    PearlCard(
                      color: PearlColors.successSoft,
                      padding: const EdgeInsets.all(13),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.check_circle_outline_rounded,
                              color: PearlColors.success),
                          const SizedBox(width: 10),
                          Expanded(child: Text(c.t('draftPreserved'))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _nickname,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[AutofillHints.nickname],
                    decoration: InputDecoration(
                      labelText: c.t('nickname'),
                      hintText: c.t('nicknameHint'),
                    ),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _gas,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: c.t('gasType'),
                      hintText: c.t('gasTypeHint'),
                    ),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 440;
                    final fields = <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller: _capacity,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(labelText: c.t('capacity')),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return null;
                            final parsed = _parseLocalizedDecimal(
                              value,
                              c.strings!.locale,
                            );
                            if (parsed == null || !parsed.isFinite || parsed <= 0) {
                              return c.t('capacityError');
                            }
                            if (_capacityUnit == null) return c.t('capacityError');
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12, height: 12),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _capacityUnit,
                          decoration: InputDecoration(labelText: c.t('capacityUnit')),
                          items: <String>['kg', 'lb', 'L', 'm3', 'ft3']
                              .map((value) => DropdownMenuItem<String?>(
                                    value: value,
                                    child: Text(value),
                                  ))
                              .toList(growable: false),
                          onChanged: (value) => setState(() => _capacityUnit = value),
                        ),
                      ),
                    ];
                    return narrow
                        ? Column(children: fields)
                        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: fields);
                  }),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _serial,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: c.t('serialNumber'),
                      suffixText: c.t('optional'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(c.t('relationship'), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: RelationshipType.values
                        .map((value) => ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 44),
                              child: ChoiceChip(
                                label: Text(_relationshipLabel(c, value)),
                                selected: _relationship == value,
                                onSelected: (_) =>
                                    setState(() => _relationship = value),
                              ),
                            ))
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String?>(
                    initialValue: _supplierId,
                    decoration: InputDecoration(labelText: c.t('supplier')),
                    items: <DropdownMenuItem<String?>>[
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(c.t('noSupplier')),
                      ),
                      ...c.data!.suppliers.map((supplier) => DropdownMenuItem<String?>(
                            value: supplier.id,
                            child: Text(supplier.name),
                          )),
                    ],
                    onChanged: (value) => setState(() => _supplierId = value),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _cost,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: c.t('acquisitionCost'),
                      suffixText: c.data!.settings.currencyCode,
                    ),
                    validator: _optionalMoneyValidator,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _DateButton(
                          label: c.t('dateAcquired'),
                          value: _acquiredAt == null
                              ? c.t('optional')
                              : DateFormat.yMMMd(_intlLocale(c.strings!.locale))
                                  .format(_acquiredAt!),
                          onTap: () => unawaited(_pickAcquiredDate()),
                        ),
                      ),
                      if (_acquiredAt != null) ...<Widget>[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: c.t('cancel'),
                          onPressed: () => setState(() => _acquiredAt = null),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size(48, 62)),
                    onPressed:
                        c.busy ? null : () => unawaited(_submit()),
                    icon: c.busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(c.t('save')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  String? _requiredValidator(String? value) =>
      value == null || value.trim().isEmpty ? c.t('requiredFields') : null;

  String? _optionalMoneyValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = _parseLocalizedDecimal(value, c.strings!.locale);
    return parsed == null || !parsed.isFinite || parsed < 0
        ? c.t('somethingWentWrong')
        : null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final capacityText = _capacity.text.trim();
    final capacity = capacityText.isEmpty
        ? null
        : _parseLocalizedDecimal(capacityText, c.strings!.locale)!;
    final cost = _parseMoney(
      _cost.text,
      c.data!.settings.currencyCode,
      c.strings!.locale,
    );
    if (widget.cylinder == null) {
      final result = await c.addCylinder(AddCylinderDraft(
        nickname: _nickname.text,
        gasType: _gas.text,
        capacityValue: capacity,
        capacityUnit: capacity == null ? null : _capacityUnit,
        serialNumber: _nullIfBlank(_serial.text),
        relationship: _relationship,
        supplierId: _supplierId,
        acquisitionAmount: cost,
        acquiredAt: _acquiredAt,
      ));
      if (mounted && result != null) Navigator.pop(context, result);
      return;
    }
    await c.updateCylinder(
      cylinderId: widget.cylinder!.id,
      nickname: _nickname.text,
      gasType: _gas.text,
      capacityValue: capacity,
      capacityUnit: capacity == null ? null : _capacityUnit,
      serialNumber: _nullIfBlank(_serial.text),
      acquisitionAmount: cost,
      acquiredAt: _acquiredAt,
      relationship: _relationship,
      supplierId: _supplierId,
    );
    if (mounted && c.errorMessage == null) Navigator.pop(context);
  }

  Future<void> _pickAcquiredDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _acquiredAt ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (date != null && mounted) setState(() => _acquiredAt = date);
  }
}

Future<void> showCylinderDetail(
  BuildContext context,
  WalletController controller,
  String cylinderId,
) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => CylinderDetailSheet(
        controller: controller,
        cylinderId: cylinderId,
      ),
    );

class CylinderDetailSheet extends StatelessWidget {
  const CylinderDetailSheet({
    required this.controller,
    required this.cylinderId,
    super.key,
  });

  final WalletController controller;
  final String cylinderId;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final cylinder = controller.data!.cylinders
              .where((item) => item.id == cylinderId)
              .firstOrNull;
          if (cylinder == null) return const SizedBox.shrink();
          final supplier = controller.data!.suppliers
              .where((item) => item.id == cylinder.supplierId)
              .firstOrNull;
          final events = controller.data!.events
              .where((item) => item.cylinderId == cylinder.id)
              .toList()
            ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
          final readOnly = !controller.isPro &&
              controller.currentCylinders.length > freeEditableCylinderLimit &&
              !cylinder.isFreeEditableSelection;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const CylinderGlyph(size: 58),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(cylinder.nickname,
                                style: Theme.of(context).textTheme.headlineMedium),
                            Text(cylinder.gasType),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: controller.t('close'),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  if (readOnly) ...<Widget>[
                    const SizedBox(height: 14),
                    PearlCard(
                      color: PearlColors.copperSoft,
                      padding: const EdgeInsets.all(13),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.lock_outline_rounded,
                              color: PearlColors.warning),
                          const SizedBox(width: 10),
                          Expanded(child: Text(controller.t('readOnlyCylinder'))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  PearlCard(
                    child: Column(
                      children: <Widget>[
                        _DetailLine(
                          label: controller.t('relationship'),
                          value: _relationshipLabel(controller, cylinder.relationship),
                        ),
                        _DetailLine(
                          label: controller.t('capacity'),
                          value: cylinder.capacityValue == null
                              ? controller.t('notAvailable')
                              : '${_formatDecimal(cylinder.capacityValue!, controller.strings!.locale)} ${cylinder.capacityUnit ?? ''}',
                        ),
                        _DetailLine(
                          label: controller.t('serialNumber'),
                          value: cylinder.serialNumber ?? controller.t('notAvailable'),
                        ),
                        _DetailLine(
                          label: controller.t('supplier'),
                          value: supplier?.name ?? controller.t('noSupplier'),
                        ),
                        _DetailLine(
                          label: controller.t('acquisitionCost'),
                          value: cylinder.acquisitionAmount == null
                              ? controller.t('notAvailable')
                              : _formatMoney(
                                  cylinder.acquisitionAmount!,
                                  controller.strings!.locale,
                                ),
                        ),
                        _DetailLine(
                          label: controller.t('dateAcquired'),
                          value: cylinder.acquiredAt == null
                              ? controller.t('notAvailable')
                              : MaterialLocalizations.of(context)
                                  .formatMediumDate(cylinder.acquiredAt!.toLocal()),
                          last: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SectionHeading(controller.t('quickActions')),
                  const SizedBox(height: 11),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _ActionButton(
                        icon: Icons.edit_outlined,
                        label: controller.t('edit'),
                        onTap: () => unawaited(_edit(context, cylinder)),
                      ),
                      _ActionButton(
                        icon: Icons.water_drop_outlined,
                        label: controller.t('recordRefill'),
                        onTap: () => unawaited(
                          _record(context, cylinder, _RecordKind.refill),
                        ),
                      ),
                      _ActionButton(
                        icon: Icons.swap_horiz_rounded,
                        label: controller.t('recordExchange'),
                        onTap: () => unawaited(
                          _record(context, cylinder, _RecordKind.exchange),
                        ),
                      ),
                      _ActionButton(
                        icon: Icons.payments_outlined,
                        label: controller.t('recordCost'),
                        onTap: () => unawaited(
                          _record(context, cylinder, _RecordKind.cost),
                        ),
                      ),
                      _ActionButton(
                        icon: Icons.notifications_outlined,
                        label: controller.t('addReminder'),
                        onTap: () => unawaited(_reminder(context, cylinder)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (events.isNotEmpty) ...<Widget>[
                    SectionHeading(controller.t('activity')),
                    const SizedBox(height: 11),
                    ...events.take(5).map((event) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _EventRow(controller: controller, event: event),
                        )),
                  ],
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: readOnly
                        ? () => unawaited(
                              showPaywall(
                                context,
                                controller,
                                reason:
                                    PaywallReason.editLockedCylinderAfterDowngrade,
                              ),
                            )
                        : () => unawaited(
                              _confirmLifecycle(
                                context,
                                cylinder,
                                returned: true,
                              ),
                            ),
                    icon: const Icon(Icons.assignment_return_outlined),
                    label: Text(controller.t('markReturned')),
                  ),
                  const SizedBox(height: 9),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: PearlColors.inkMuted),
                    onPressed: readOnly
                        ? null
                        : () => unawaited(
                              _confirmLifecycle(
                                context,
                                cylinder,
                                returned: false,
                              ),
                            ),
                    icon: const Icon(Icons.archive_outlined),
                    label: Text(controller.t('archiveCylinder')),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: PearlColors.danger),
                    onPressed: () => unawaited(
                      _confirmDeleteCylinder(context, cylinder),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(controller.t('deleteCylinder')),
                  ),
                ],
              ),
            ),
          );
        },
      );

  Future<void> _edit(BuildContext context, Cylinder cylinder) async {
    final decision = await controller.editDecision(cylinder.id);
    if (!context.mounted || decision == null) return;
    if (decision is Locked) {
      await showPaywall(context, controller, reason: decision.reason);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => CylinderEditorSheet(
        controller: controller,
        cylinder: cylinder,
      ),
    );
  }

  Future<void> _record(
    BuildContext context,
    Cylinder cylinder,
    _RecordKind kind,
  ) async {
    final decision = await controller.editDecision(cylinder.id);
    if (!context.mounted || decision == null) return;
    if (decision is Locked) {
      await showPaywall(context, controller, reason: decision.reason);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => RecordActionSheet(
        controller: controller,
        cylinder: cylinder,
        kind: kind,
      ),
    );
  }

  Future<void> _reminder(BuildContext context, Cylinder cylinder) async {
    final decision = await controller.editDecision(cylinder.id);
    if (!context.mounted || decision == null) return;
    if (decision is Locked) {
      await showPaywall(context, controller, reason: decision.reason);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ReminderEditorSheet(
        controller: controller,
        cylinder: cylinder,
      ),
    );
  }

  Future<void> _confirmLifecycle(
    BuildContext context,
    Cylinder cylinder, {
    required bool returned,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          returned ? controller.t('markReturned') : controller.t('archiveCylinder'),
        ),
        content: Text(cylinder.nickname),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(controller.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(controller.t('confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (returned) {
      await controller.markReturned(cylinder.id);
    } else {
      await controller.archive(cylinder.id);
    }
    if (context.mounted && controller.errorMessage == null) Navigator.pop(context);
  }

  Future<void> _confirmDeleteCylinder(
    BuildContext context,
    Cylinder cylinder,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: PearlColors.danger),
        title: Text(controller.t('deleteCylinder')),
        content: Text(controller.t('deleteCylinderWarning')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(controller.t('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PearlColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(controller.t('deleteCylinder')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await controller.deleteCylinder(cylinder.id);
    if (context.mounted && controller.errorMessage == null) Navigator.pop(context);
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value, this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: PearlColors.line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: Text(label)),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 156,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon),
          label: Text(label, maxLines: 2, textAlign: TextAlign.center),
        ),
      );
}

enum _RecordKind { refill, exchange, cost }

class RecordActionSheet extends StatefulWidget {
  const RecordActionSheet({
    required this.controller,
    required this.cylinder,
    required this.kind,
    super.key,
  });

  final WalletController controller;
  final Cylinder cylinder;
  final _RecordKind kind;

  @override
  State<RecordActionSheet> createState() => _RecordActionSheetState();
}

class _RecordActionSheetState extends State<RecordActionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _serial = TextEditingController();
  DateTime _date = DateTime.now();

  WalletController get c => widget.controller;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _serial.dispose();
    super.dispose();
  }

  String get _title => switch (widget.kind) {
        _RecordKind.refill => c.t('recordRefill'),
        _RecordKind.exchange => c.t('recordExchange'),
        _RecordKind.cost => c.t('recordCost'),
      };

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _SheetTitle(title: _title, close: c.t('close')),
                const SizedBox(height: 18),
                Text(widget.cylinder.nickname,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: c.t('amount'),
                    suffixText: c.data!.settings.currencyCode,
                  ),
                  validator: (value) {
                    if (widget.kind == _RecordKind.cost &&
                        (value == null || value.trim().isEmpty)) {
                      return c.t('requiredFields');
                    }
                    if (value == null || value.trim().isEmpty) return null;
                    final number = _parseLocalizedDecimal(
                      value,
                      c.strings!.locale,
                    );
                    return number == null || number < 0 ? c.t('somethingWentWrong') : null;
                  },
                ),
                if (widget.kind == _RecordKind.exchange) ...<Widget>[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _serial,
                    decoration: InputDecoration(
                      labelText: c.t('newSerialNumber'),
                      hintText: c.t('keepSerial'),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _note,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: c.t('note'),
                    suffixText: c.t('optional'),
                  ),
                ),
                const SizedBox(height: 14),
                _DateButton(
                  label: c.t('eventDate'),
                  value: DateFormat.yMMMd(_intlLocale(c.strings!.locale))
                      .format(_date),
                  onTap: () => unawaited(_pickDate()),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(48, 62)),
                  onPressed: c.busy ? null : () => unawaited(_submit()),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(c.t('save')),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 366)),
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = _parseMoney(
      _amount.text,
      c.data!.settings.currencyCode,
      c.strings!.locale,
    );
    final occurredAt = DateTime(
      _date.year,
      _date.month,
      _date.day,
      DateTime.now().hour,
      DateTime.now().minute,
    );
    switch (widget.kind) {
      case _RecordKind.refill:
        await c.recordRefill(
          cylinderId: widget.cylinder.id,
          occurredAt: occurredAt,
          amount: amount,
          note: _nullIfBlank(_note.text),
        );
      case _RecordKind.exchange:
        await c.recordExchange(
          cylinderId: widget.cylinder.id,
          occurredAt: occurredAt,
          amount: amount,
          newSerialNumber: _nullIfBlank(_serial.text),
          note: _nullIfBlank(_note.text),
        );
      case _RecordKind.cost:
        await c.recordCost(
          cylinderId: widget.cylinder.id,
          occurredAt: occurredAt,
          amount: amount!,
          note: _nullIfBlank(_note.text),
        );
    }
    if (mounted && c.errorMessage == null) Navigator.pop(context);
  }
}

class ReminderEditorSheet extends StatefulWidget {
  const ReminderEditorSheet({
    required this.controller,
    required this.cylinder,
    super.key,
  });

  final WalletController controller;
  final Cylinder cylinder;

  @override
  State<ReminderEditorSheet> createState() => _ReminderEditorSheetState();
}

class _ReminderEditorSheetState extends State<ReminderEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  ReminderKind _kind = ReminderKind.refill;
  DateTime _due = DateTime.now().add(const Duration(days: 7));

  WalletController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: c.t('refill'));
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _SheetTitle(title: c.t('addReminder'), close: c.t('close')),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _title,
                  decoration: InputDecoration(labelText: c.t('reminderTitle')),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? c.t('requiredFields')
                      : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<ReminderKind>(
                  initialValue: _kind,
                  decoration: InputDecoration(labelText: c.t('reminderType')),
                  items: ReminderKind.values
                      .map((kind) => DropdownMenuItem<ReminderKind>(
                            value: kind,
                            child: Text(c.t(kind.name)),
                          ))
                      .toList(growable: false),
                  onChanged: (kind) {
                    if (kind != null) setState(() => _kind = kind);
                  },
                ),
                const SizedBox(height: 14),
                _DateButton(
                  label: c.t('reminderDue'),
                  value: _dateTime(context, _due),
                  onTap: () => unawaited(_pickDue()),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(48, 62)),
                  onPressed: c.busy ? null : () => unawaited(_submit()),
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text(c.t('save')),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _pickDue() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_due),
    );
    if (time == null || !mounted) return;
    setState(() {
      _due = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await c.createReminder(
      cylinderId: widget.cylinder.id,
      kind: _kind,
      title: _title.text,
      dueAt: _due,
    );
    if (mounted && c.errorMessage == null) Navigator.pop(context);
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.title, required this.close});

  final String title;
  final String close;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
          ),
          IconButton(
            tooltip: close,
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      );
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: <Widget>[
              const Icon(Icons.calendar_today_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(label, style: Theme.of(context).textTheme.labelMedium),
                    Text(value, style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      );
}

Future<void> showPaywall(
  BuildContext context,
  WalletController controller, {
  required PaywallReason reason,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => PaywallSheet(controller: controller, reason: reason),
    );

class PaywallSheet extends StatefulWidget {
  const PaywallSheet({
    required this.controller,
    required this.reason,
    super.key,
  });

  final WalletController controller;
  final PaywallReason reason;

  @override
  State<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<PaywallSheet> {
  String? _selectedId;

  WalletController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _selectDefault();
  }

  void _selectDefault() {
    if (c.products.isEmpty) return;
    _selectedId = c.products.where((item) => item.isDefault).firstOrNull?.id ??
        c.products.first.id;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (context, _) {
          final hasDraft = c.data!.pendingDraft != null;
          final selected = c.products
              .where((product) => product.id == _selectedId)
              .firstOrNull;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              18 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: <Color>[PearlColors.pine, Color(0xFF65A9E8)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              hasDraft &&
                                      widget.reason == PaywallReason.addFourthCylinder
                                  ? c.t('fourthReady')
                                  : c.t('proPlan'),
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            Text(hasDraft ? c.t('draftPreserved') : c.t('proPlanBody')),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: c.t('close'),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  PearlCard(
                    color: PearlColors.mint,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(Icons.lock_open_rounded, color: PearlColors.pine),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            hasDraft ? c.t('paywallBody') : c.t('proPlanBody'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (c.products.isEmpty)
                    PearlCard(
                      child: Column(
                        children: <Widget>[
                          const Icon(Icons.cloud_off_outlined,
                              color: PearlColors.inkMuted, size: 34),
                          const SizedBox(height: 10),
                          Text(
                            hasDraft
                                ? c.t('purchaseUnavailable')
                                : c.t('storePriceUnavailable'),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await c.reloadProducts();
                              if (mounted) setState(_selectDefault);
                            },
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(c.t('retry')),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final product in c.products)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ProductChoice(
                          controller: c,
                          product: product,
                          selected: product.id == _selectedId,
                          onTap: () => setState(() => _selectedId = product.id),
                        ),
                      ),
                  if (selected != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      _purchaseContract(c, selected),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(48, 62)),
                      onPressed: c.busy
                          ? null
                          : () => unawaited(_purchase(selected)),
                      icon: c.busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.lock_open_rounded),
                      label: Text(_purchaseAction(c, selected)),
                    ),
                  ],
                  if (c.billing.platform == StorePlatform.ios)
                    TextButton(
                      onPressed: c.refreshingStore
                          ? null
                          : () => unawaited(_restore()),
                      child: Text(c.t('restorePurchases')),
                    )
                  else
                    TextButton(
                      onPressed: () => unawaited(c.manageSubscription()),
                      child: Text(c.t('manageSubscription')),
                    ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    children: <Widget>[
                      TextButton(
                        onPressed: () =>
                            unawaited(c.openLegal(LegalLinks.terms)),
                        child: Text(c.t('termsOfUse')),
                      ),
                      TextButton(
                        onPressed: () =>
                            unawaited(c.openLegal(LegalLinks.privacy)),
                        child: Text(c.t('privacyPolicy')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );

  Future<void> _purchase(StoreProduct product) async {
    await c.purchase(product.id);
    if (mounted && c.isPro) Navigator.pop(context);
  }

  Future<void> _restore() async {
    await c.restore();
    if (mounted && c.isPro) Navigator.pop(context);
  }
}

class _ProductChoice extends StatelessWidget {
  const _ProductChoice({
    required this.controller,
    required this.product,
    required this.selected,
    required this.onTap,
  });

  final WalletController controller;
  final StoreProduct product;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: selected ? PearlColors.mint : PearlColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? PearlColors.pine : PearlColors.line,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? PearlColors.pine : PearlColors.inkMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              _productLabel(controller, product.id),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(product.localizedPeriodLabel),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  product.localizedPrice,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: PearlColors.pine,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
}

String _productLabel(WalletController c, String id) {
  if (id == ProductIds.androidAnnual) return c.t('annual');
  if (id == ProductIds.androidMonthly) return c.t('monthly');
  return c.t('lifetime');
}

String _purchaseContract(WalletController c, StoreProduct product) {
  final key = product.id == ProductIds.androidAnnual
      ? 'annualPurchaseContract'
      : product.id == ProductIds.androidMonthly
          ? 'monthlyPurchaseContract'
          : 'lifetimePurchaseContract';
  return c.t(key, <String, Object?>{'price': product.localizedPrice});
}

String _purchaseAction(WalletController c, StoreProduct product) {
  final key = product.id == ProductIds.androidAnnual
      ? 'subscribeAnnualAction'
      : product.id == ProductIds.androidMonthly
          ? 'subscribeMonthlyAction'
          : 'buyLifetimeAction';
  return c.t(key, <String, Object?>{'price': product.localizedPrice});
}

class FreeSelectionSheet extends StatefulWidget {
  const FreeSelectionSheet({required this.controller, super.key});

  final WalletController controller;

  @override
  State<FreeSelectionSheet> createState() => _FreeSelectionSheetState();
}

class _FreeSelectionSheetState extends State<FreeSelectionSheet> {
  final Set<String> _selected = <String>{};

  WalletController get c => widget.controller;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(c.t('freePlan'), style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(c.t('freePlanBody')),
              const SizedBox(height: 16),
              for (final cylinder in c.currentCylinders)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: CheckboxListTile(
                    tileColor: PearlColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: PearlColors.line),
                    ),
                    title: Text(cylinder.nickname),
                    subtitle: Text(cylinder.gasType),
                    value: _selected.contains(cylinder.id),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true &&
                            _selected.length < freeEditableCylinderLimit) {
                          _selected.add(cylinder.id);
                        } else if (checked == false) {
                          _selected.remove(cylinder.id);
                        }
                      });
                    },
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(48, 62)),
                onPressed: _selected.length == freeEditableCylinderLimit
                    ? () async {
                        await c.selectFreeEditable(_selected);
                        if (mounted && c.errorMessage == null) Navigator.pop(context);
                      }
                    : null,
                child: Text(
                  '${c.t('confirm')} (${_selected.length}/$freeEditableCylinderLimit)',
                ),
              ),
              TextButton(
                onPressed: () => unawaited(
                  showPaywall(
                    context,
                    c,
                    reason: PaywallReason.editLockedCylinderAfterDowngrade,
                  ),
                ),
                child: Text(c.t('upgrade')),
              ),
            ],
          ),
        ),
      );
}

Future<void> _showLanguagePicker(
  BuildContext context,
  WalletController controller,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Column(
        children: <Widget>[
          _SheetTitle(title: controller.t('language'), close: controller.t('close')),
          Expanded(
            child: ListView.separated(
              itemCount: supportedLocales.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final locale = supportedLocales[index];
                final selected = locale == controller.data!.settings.locale;
                return ListTile(
                  minTileHeight: 52,
                  selected: selected,
                  title: Text(localeNativeNames[locale] ?? locale),
                  trailing: selected
                      ? const Icon(Icons.check_rounded, color: PearlColors.pine)
                      : null,
                  onTap: () async {
                    await controller.setLocale(locale);
                    if (context.mounted && controller.localizationFailure == null) {
                      Navigator.pop(context);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showRegionalSettings(
  BuildContext context,
  WalletController controller,
) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _RegionalSettingsSheet(controller: controller),
    );

class _RegionalSettingsSheet extends StatefulWidget {
  const _RegionalSettingsSheet({required this.controller});

  final WalletController controller;

  @override
  State<_RegionalSettingsSheet> createState() => _RegionalSettingsSheetState();
}

class _RegionalSettingsSheetState extends State<_RegionalSettingsSheet> {
  late String _currency;
  late String _mass;
  late String _volume;

  WalletController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    final settings = c.data!.settings;
    _currency = settings.currencyCode;
    _mass = settings.defaultMassUnit;
    _volume = settings.defaultVolumeUnit;
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _SheetTitle(
                title: c.t('appearanceAndRegion'),
                close: c.t('close'),
              ),
              const SizedBox(height: 16),
              _CurrencyPickerField(
                value: _currency,
                label: c.t('currency'),
                closeLabel: c.t('close'),
                onChanged: (value) => setState(() => _currency = value),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _mass,
                decoration: InputDecoration(labelText: c.t('massUnit')),
                items: const <String>['kg', 'lb']
                    .map((value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ))
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) setState(() => _mass = value);
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _volume,
                decoration: InputDecoration(labelText: c.t('volumeUnit')),
                items: const <String>['L', 'm3', 'ft3']
                    .map((value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ))
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) setState(() => _volume = value);
                },
              ),
              const SizedBox(height: 22),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(48, 62)),
                onPressed: c.busy
                    ? null
                    : () async {
                        await c.updateSettings(
                          currencyCode: _currency,
                          massUnit: _mass,
                          volumeUnit: _volume,
                        );
                        if (mounted && c.errorMessage == null) Navigator.pop(context);
                      },
                child: Text(c.t('save')),
              ),
            ],
          ),
        ),
      );
}

Future<void> _showSupplierEditor(
  BuildContext context,
  WalletController controller,
) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _SupplierEditorSheet(controller: controller),
    );

class _SupplierEditorSheet extends StatefulWidget {
  const _SupplierEditorSheet({required this.controller});

  final WalletController controller;

  @override
  State<_SupplierEditorSheet> createState() => _SupplierEditorSheetState();
}

class _SupplierEditorSheetState extends State<_SupplierEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _SheetTitle(title: c.t('addSupplier'), close: c.t('close')),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: c.t('supplierName')),
              validator: (value) => value == null || value.trim().isEmpty
                  ? c.t('requiredFields')
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: InputDecoration(labelText: c.t('supplierNotes')),
            ),
            const SizedBox(height: 22),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 62)),
              onPressed: c.busy
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) return;
                      await c.createSupplier(
                        _name.text,
                        notes: _nullIfBlank(_notes.text),
                      );
                      if (mounted && c.errorMessage == null) Navigator.pop(context);
                    },
              child: Text(c.t('save')),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmImport(
  BuildContext context,
  WalletController controller,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(controller.t('importBackup')),
      content: Text(controller.t('importWarning')),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(controller.t('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(controller.t('confirm')),
        ),
      ],
    ),
  );
  if (confirmed == true) await controller.importBackup();
}

Future<void> _confirmDelete(
  BuildContext context,
  WalletController controller,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: PearlColors.danger),
      title: Text(controller.t('deleteAllData')),
      content: Text(controller.t('deleteWarning')),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(controller.t('cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: PearlColors.danger),
          onPressed: () => Navigator.pop(context, true),
          child: Text(controller.t('deleteConfirm')),
        ),
      ],
    ),
  );
  if (confirmed == true) await controller.deleteAll();
}

String _relationshipLabel(WalletController c, RelationshipType value) =>
    c.t(value.name);

String _dateTime(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final material = MaterialLocalizations.of(context);
  return '${material.formatMediumDate(local)} · ${material.formatTime(TimeOfDay.fromDateTime(local))}';
}

String _formatDecimal(double value, String locale) {
  return LocaleMoney.formatDecimal(value, locale);
}

String? _nullIfBlank(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

Money? _parseMoney(String text, String currencyCode, String locale) {
  return LocaleMoney.parseMoney(text, currencyCode, locale);
}

String _formatMoney(Money money, String locale) =>
    LocaleMoney.formatMoney(money, locale);

String _formatMinorUnits(
  int minorUnits,
  String currencyCode,
  String locale,
) {
  return LocaleMoney.formatMinorUnits(minorUnits, currencyCode, locale);
}

String _minorToInput(int minorUnits, String currencyCode, String locale) {
  return LocaleMoney.inputValue(minorUnits, currencyCode, locale);
}

double? _parseLocalizedDecimal(String input, String locale) {
  return LocaleMoney.parseMajor(input, locale);
}

String _intlLocale(String locale) =>
    LocaleMoney.intlLocale(locale);
