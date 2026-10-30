import 'package:flutter_test/flutter_test.dart';
import 'package:taskhub/lesson_reminders.dart';

void main() {
  test('reminds ten minutes before the earliest lesson of each day', () {
    const lessons = <ReminderLesson>[
      (day: 'Monday', subject: 'Later', start: '10:00', room: 'C1.2.346'),
      (day: 'Monday', subject: 'Math', start: '08:30', room: 'C1.1.143'),
      (day: 'Tuesday', subject: 'Physics', start: '09:00', room: ''),
    ];

    final reminders = planFirstLessonReminders(
      lessons,
      DateTime(2026, 11, 2, 8, 19),
    );

    expect(reminders, hasLength(2));
    expect(reminders[0].scheduledAt, DateTime(2026, 11, 2, 8, 20));
    expect(reminders[0].body, 'Math в 08:30 · кабинет C1.1.143');
    expect(reminders[1].scheduledAt, DateTime(2026, 11, 3, 8, 50));
    expect(reminders[1].body, 'Physics в 09:00 · кабинет не указан');
  });

  test('moves a passed reminder to the next week', () {
    const lessons = <ReminderLesson>[
      (day: 'Monday', subject: 'Math', start: '08:30', room: 'C1.1.143'),
    ];

    final reminder = planFirstLessonReminders(
      lessons,
      DateTime(2026, 11, 2, 8, 20),
    ).single;

    expect(reminder.scheduledAt, DateTime(2026, 11, 9, 8, 20));
  });
}
