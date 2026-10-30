import 'package:flutter_test/flutter_test.dart';
import 'package:taskhub/deadline_reminders.dart';

void main() {
  test('plans a day and an hour before each active deadline', () {
    final now = DateTime(2026, 11, 2, 9);
    final due = DateTime(2026, 11, 4, 12);
    final reminders = planDeadlineReminders([
      (id: 'one', title: 'Essay', subject: 'English', due: due,
          completed: false),
      (id: 'done', title: 'Quiz', subject: 'Math', due: due,
          completed: true),
    ], now);

    expect(reminders, hasLength(2));
    expect(reminders[0].at, DateTime(2026, 11, 3, 12));
    expect(reminders[1].at, DateTime(2026, 11, 4, 11));
    expect(reminders[0].body, contains('English · Essay · 04.11 12:00'));
    expect(reminders[0].id, isNot(reminders[1].id));
  });

  test('skips passed reminder times and expired deadlines', () {
    final now = DateTime(2026, 11, 2, 11, 30);
    final reminders = planDeadlineReminders([
      (id: 'soon', title: 'Lab', subject: 'Physics',
          due: DateTime(2026, 11, 2, 12), completed: false),
      (id: 'later', title: 'Essay', subject: 'English',
          due: DateTime(2026, 11, 2, 14), completed: false),
      (id: 'past', title: 'Quiz', subject: 'Math',
          due: DateTime(2026, 11, 2, 10), completed: false),
    ], now);

    expect(reminders, hasLength(1));
    expect(reminders.single.title, 'Дедлайн через час');
    expect(reminders.single.at, DateTime(2026, 11, 2, 13));
  });
}
