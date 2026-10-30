import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

typedef ReminderLesson = ({
  String day,
  String subject,
  String start,
  String room,
});

class FirstLessonReminder {
  const FirstLessonReminder({
    required this.weekday,
    required this.lesson,
    required this.scheduledAt,
  });

  final int weekday;
  final ReminderLesson lesson;
  final DateTime scheduledAt;

  int get id => 42000 + weekday;
  String get title => 'Первая пара через 10 минут';
  String get body =>
      '${lesson.subject} в ${lesson.start} · кабинет ${lesson.room.trim().isEmpty ? 'не указан' : lesson.room.trim()}';
}

const _weekdays = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

List<FirstLessonReminder> planFirstLessonReminders(
  List<ReminderLesson> lessons,
  DateTime now,
) {
  final firstByDay = <int, ({ReminderLesson lesson, int minutes})>{};
  for (final lesson in lessons) {
    final dayIndex = _weekdays.indexOf(lesson.day);
    final time = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(lesson.start);
    if (dayIndex < 0 || time == null) continue;
    final hour = int.parse(time.group(1)!);
    final minute = int.parse(time.group(2)!);
    if (hour > 23 || minute > 59) continue;
    final minutes = hour * 60 + minute;
    final weekday = dayIndex + 1;
    final current = firstByDay[weekday];
    if (current != null && current.minutes <= minutes) continue;
    firstByDay[weekday] = (lesson: lesson, minutes: minutes);
  }

  return [
    for (final entry in firstByDay.entries)
      FirstLessonReminder(
        weekday: entry.key,
        lesson: entry.value.lesson,
        scheduledAt: _nextReminderAt(now, entry.key, entry.value.minutes),
      ),
  ]..sort((a, b) => a.weekday.compareTo(b.weekday));
}

DateTime _nextReminderAt(DateTime now, int weekday, int minutes) {
  final daysAhead = (weekday - now.weekday + 7) % 7;
  DateTime reminderFor(int extraDays) => DateTime(
    now.year,
    now.month,
    now.day + daysAhead + extraDays,
    minutes ~/ 60,
    minutes % 60,
  ).subtract(const Duration(minutes: 10));

  final upcoming = reminderFor(0);
  return upcoming.isAfter(now) ? upcoming : reminderFor(7);
}

abstract class LessonReminderScheduler {
  Future<void> sync(List<ReminderLesson> lessons);
}

class LocalLessonReminderScheduler implements LessonReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _androidCanScheduleExact = true;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<bool> _initializeAndRequestPermission() async {
    if (!_supported) return false;
    if (!_initialized) {
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

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final permitted =
          await android?.requestNotificationsPermission() ?? false;
      if (!permitted) return false;
      final prefs = await SharedPreferences.getInstance();
      const key = 'taskhub_exact_alarm_permission_requested';
      if (!(prefs.getBool(key) ?? false)) {
        await prefs.setBool(key, true);
        try {
          _androidCanScheduleExact =
              await android?.requestExactAlarmsPermission() ?? false;
        } on PlatformException {
          _androidCanScheduleExact = false;
        }
      }
      return true;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(alert: true, sound: true) ?? false;
    }
    final macos = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    return await macos?.requestPermissions(alert: true, sound: true) ?? false;
  }

  @override
  Future<void> sync(List<ReminderLesson> lessons) async {
    if (!_supported) return;
    if (lessons.isEmpty && !_initialized) return;
    final reminders = planFirstLessonReminders(lessons, DateTime.now());
    try {
      final permitted = await _initializeAndRequestPermission();
      for (var weekday = 1; weekday <= 7; weekday++) {
        await _plugin.cancel(id: 42000 + weekday);
      }
      if (!permitted) return;
      for (final reminder in reminders) {
        Future<void> schedule(AndroidScheduleMode mode) =>
            _plugin.zonedSchedule(
              id: reminder.id,
              title: reminder.title,
              body: reminder.body,
              scheduledDate: tz.TZDateTime.from(reminder.scheduledAt, tz.local),
              notificationDetails: const NotificationDetails(
                android: AndroidNotificationDetails(
                  'first_lesson',
                  'Первая пара',
                  channelDescription: 'Напоминание перед первой парой',
                  importance: Importance.high,
                  priority: Priority.high,
                ),
              ),
              androidScheduleMode: mode,
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
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
      }
    } catch (error) {
      debugPrint('Не удалось запланировать уведомления: $error');
    }
  }
}
