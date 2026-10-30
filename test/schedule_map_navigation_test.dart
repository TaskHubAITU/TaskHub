import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskhub/main.dart';
import 'package:taskhub/lesson_reminders.dart';
import 'package:taskhub/university_map_data.dart';

void main() {
  testWidgets('lesson map button opens and highlights its room', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final lesson = Lesson(
      id: 'lesson-1',
      day: kDays[DateTime.now().weekday - 1],
      subject: 'Math',
      room: '2.346',
      start: '09:00',
      end: '10:00',
      colorValue: kSubjectColors.first.toARGB32(),
      iconCodePoint: kSubjectIcons.first.codePoint,
    );
    SharedPreferences.setMockInitialValues({
      'taskhub_lessons': jsonEncode([lesson.toJson()]),
      'taskhub_deadlines': '[]',
    });

    final catalog = MapCatalog.fromJson(
      File('assets/map/aitu_rooms.json').readAsStringSync(),
    );
    await tester.pumpWidget(
      TaskHubApp(mapCatalog: catalog, reminderScheduler: _NoopReminders()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Показать кабинет на карте'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    expect(
      find.descendant(of: find.byType(Card), matching: find.text('C1.2.346')),
      findsOneWidget,
    );
    expect(find.text('C1.2 · 3 этаж'), findsOneWidget);
  });

  testWidgets('notification button saves disabled state and clears lessons',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'taskhub_lessons': jsonEncode([
        Lesson(
          id: 'lesson-1',
          day: 'Monday',
          subject: 'Math',
          room: 'C1.1.143',
          start: '09:00',
          end: '10:00',
          colorValue: kSubjectColors.first.toARGB32(),
          iconCodePoint: kSubjectIcons.first.codePoint,
        ).toJson(),
      ]),
      'taskhub_deadlines': '[]',
    });
    final scheduler = _RecordingReminders();
    await tester.pumpWidget(TaskHubApp(reminderScheduler: scheduler));
    await tester.pumpAndSettle();
    expect(scheduler.calls.last, hasLength(1));

    await tester.tap(find.byTooltip('Отключить уведомления'));
    await tester.pumpAndSettle();
    expect(scheduler.calls.last, isEmpty);
    expect(
      (await SharedPreferences.getInstance())
          .getBool('taskhub_notifications_enabled'),
      false,
    );
    expect(find.byTooltip('Включить уведомления'), findsOneWidget);
  });
}

class _NoopReminders implements LessonReminderScheduler {
  @override
  Future<void> sync(List<ReminderLesson> lessons) async {}
}

class _RecordingReminders implements LessonReminderScheduler {
  final calls = <List<ReminderLesson>>[];

  @override
  Future<void> sync(List<ReminderLesson> lessons) async {
    calls.add(lessons);
  }
}
