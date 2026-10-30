import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

typedef ReminderDeadline = ({
  String id,
  String title,
  String subject,
  DateTime due,
  bool completed,
});

const _deadlineIdsKey = 'taskhub_scheduled_deadline_ids';

class DeadlineReminder {
  const DeadlineReminder(this.id, this.title, this.body, this.at);

  final int id;
  final String title;
  final String body;
  final DateTime at;
}

int _idFor(String id, int offset) {
  var hash = 2166136261;
  for (final codeUnit in id.codeUnits) {
    hash = ((hash ^ codeUnit) * 16777619) & 0x7fffffff;
  }
  return 100000 + (hash % 700000000) * 3 + offset;
}

List<DeadlineReminder> planDeadlineReminders(
  List<ReminderDeadline> deadlines,
  DateTime now,
) {
  final upcoming =
      deadlines.where((d) => !d.completed && d.due.isAfter(now)).toList()
        ..sort((a, b) => a.due.compareTo(b.due));
  final result = <DeadlineReminder>[];
  // iOS keeps only 64 pending local notifications. Leave room for lessons.
  for (final deadline in upcoming.take(24)) {
    final label =
        '${deadline.due.day.toString().padLeft(2, '0')}.'
        '${deadline.due.month.toString().padLeft(2, '0')} '
        '${deadline.due.hour.toString().padLeft(2, '0')}:'
        '${deadline.due.minute.toString().padLeft(2, '0')}';
    final body = '${deadline.subject} · ${deadline.title} · $label';
    final dayBefore = deadline.due.subtract(const Duration(days: 1));
    final hourBefore = deadline.due.subtract(const Duration(hours: 1));
    if (dayBefore.isAfter(now)) {
      result.add(
        DeadlineReminder(
          _idFor(deadline.id, 0),
          'Дедлайн завтра',
          body,
          dayBefore,
        ),
      );
    }
    if (hourBefore.isAfter(now)) {
      result.add(
        DeadlineReminder(
          _idFor(deadline.id, 1),
          'Дедлайн через час',
          body,
          hourBefore,
        ),
      );
    }
  }
  return result;
}

class LocalDeadlineReminderScheduler {
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'deadlines',
      'Дедлайны',
      channelDescription: 'Напоминания о дедлайнах',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _androidCanScheduleExact = true;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> _initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  Future<void> sync(List<ReminderDeadline> deadlines) async {
    if (!_supported) return;
    final prefs = await SharedPreferences.getInstance();
    final oldIds = prefs.getStringList(_deadlineIdsKey) ?? <String>[];
    if (deadlines.isEmpty && oldIds.isEmpty) return;
    try {
      await _initialize();
      for (final id in oldIds) {
        await _plugin.cancel(id: int.parse(id));
      }
      await prefs.remove(_deadlineIdsKey);
      if (deadlines.isEmpty) return;

      bool permitted;
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        permitted = await android?.requestNotificationsPermission() ?? false;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        permitted =
            await ios?.requestPermissions(alert: true, sound: true) ?? false;
      } else {
        final macos = _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >();
        permitted =
            await macos?.requestPermissions(alert: true, sound: true) ?? false;
      }
      if (!permitted) return;

      final now = DateTime.now();
      final reminders = planDeadlineReminders(deadlines, now);
      final scheduledIds = <String>[];
      for (final reminder in reminders) {
        Future<void> schedule(AndroidScheduleMode mode) =>
            _plugin.zonedSchedule(
              id: reminder.id,
              title: reminder.title,
              body: reminder.body,
              scheduledDate: tz.TZDateTime.from(reminder.at, tz.local),
              notificationDetails: _details,
              androidScheduleMode: mode,
            );
        try {
          await schedule(
            _androidCanScheduleExact
                ? AndroidScheduleMode.exactAllowWhileIdle
                : AndroidScheduleMode.inexactAllowWhileIdle,
          );
        } on PlatformException catch (error) {
          if (error.code != 'exact_alarms_not_permitted') rethrow;
          _androidCanScheduleExact = false;
          await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
        }
        scheduledIds.add(reminder.id.toString());
      }
      await prefs.setStringList(_deadlineIdsKey, scheduledIds);

      for (final deadline in deadlines) {
        if (deadline.completed ||
            !deadline.due.isAfter(now) ||
            deadline.due.difference(now) > const Duration(days: 1)) {
          continue;
        }
        final key = 'taskhub_imminent_deadline_${deadline.id}';
        final value =
            '${deadline.due.toIso8601String()}|${deadline.title}|${deadline.subject}';
        if (prefs.getString(key) == value) continue;
        await _plugin.show(
          id: _idFor(deadline.id, 2),
          title: 'Дедлайн скоро',
          body: '${deadline.subject} · ${deadline.title}',
          notificationDetails: _details,
        );
        await prefs.setString(key, value);
      }
    } catch (error) {
      debugPrint('Не удалось запланировать дедлайны: $error');
    }
  }
}
