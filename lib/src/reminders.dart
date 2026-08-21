import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import 'domain/welding_gas_wallet_core_v1_1.dart';

/// Permission is deliberately separate from [ReminderScheduler]. The app calls
/// this only after a user enables reminders; initialization never prompts.
abstract interface class ReminderPermissionGateway {
  Future<bool> requestPermission();
}

abstract interface class ReminderPresentationGateway {
  void configureLocalizedPresentation({
    required String channelName,
    required String channelDescription,
  });
}

class DeviceReminderScheduler
    implements
        ReminderScheduler,
        ReminderPermissionGateway,
        ReminderPresentationGateway {
  DeviceReminderScheduler({FlutterLocalNotificationsPlugin? notifications})
      : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'wallet_reminders';

  final FlutterLocalNotificationsPlugin _notifications;
  Future<void>? _initializing;
  String? _channelName;
  String? _channelDescription;

  @override
  void configureLocalizedPresentation({
    required String channelName,
    required String channelDescription,
  }) {
    _channelName = channelName;
    _channelDescription = channelDescription;
  }

  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    timezone_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      timezone.setLocalLocation(timezone.getLocation(zone.identifier));
    } on Object {
      // `timezone.local` remains UTC when a device identifier cannot be mapped.
      // The reminder still fires at the absolute instant stored by the domain.
    }
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_welding_wallet'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    if (Platform.isAndroid) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          true;
    }
    if (Platform.isIOS) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  @override
  Future<void> schedule(Reminder reminder) async {
    await initialize();
    final channelName = _channelName;
    final channelDescription = _channelDescription;
    if (channelName == null || channelDescription == null) {
      throw StateError('Localized reminder presentation was not configured.');
    }
    final now = timezone.TZDateTime.now(timezone.local);
    final requested = timezone.TZDateTime.from(reminder.dueAt, timezone.local);
    // An overdue durable reminder is delivered promptly instead of disappearing.
    final scheduled = requested.isAfter(now)
        ? requested
        : now.add(const Duration(seconds: 5));
    await _notifications.zonedSchedule(
      _stableNotificationId(reminder.id),
      title: reminder.title,
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'reminder',
    );
  }

  @override
  Future<void> cancel(String reminderId) async {
    await initialize();
    await _notifications.cancel(id: _stableNotificationId(reminderId));
  }

  @override
  Future<void> cancelAll() async {
    await initialize();
    await _notifications.cancelAll();
  }
}

int _stableNotificationId(String value) {
  // FNV-1a constrained to Android's positive signed 32-bit notification IDs.
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}
