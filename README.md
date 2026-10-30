# TaskHub

**A student planner and campus navigation app for Astana IT University.**

TaskHub brings class schedules, assignment deadlines, and university room navigation into one Flutter app. It is designed to make everyday student tasks easier, especially for students finding their way around AITU.

## Features

- **Class schedule** — view and manage weekly lessons.
- **Deadlines** — add assignments, set due dates, mark tasks as completed, and keep track of upcoming work.
- **AITU campus map** — search for rooms by number, switch between floors, and locate a selected room on the map.
- **Schedule-to-map navigation** — open the map directly from a classroom listed in the schedule.
- **Customisation** — personalise subjects with colours and icons.
- **Reminders** — local notifications for lessons and deadlines, with an option to turn them off.
- **Local storage** — save schedule and deadline data on the device with SharedPreferences.

## Built With

- [Flutter](https://flutter.dev/) and Dart
- `shared_preferences` for local data
- `flutter_svg` for map visuals
- `flutter_local_notifications` for reminders
- `timezone` and `flutter_timezone` for notification scheduling

The current app stores its data locally; it does not require a separate backend for its core features.

## Getting Started

Install [Flutter](https://docs.flutter.dev/get-started/install) and set up a device or emulator.

```bash
git clone https://github.com/alikhansabargazy/Android-TaskHub.git
cd Android-TaskHub
flutter pub get
flutter run
```

To build an Android APK:

```bash
flutter build apk --release
```

The output is typically at `build/app/outputs/flutter-apk/app-release.apk`.

## Project Structure

```text
lib/
  main.dart                  App interface, schedule and deadlines
  map_page.dart              Interactive campus map
  university_map_data.dart   Map data models and search
  lesson_reminders.dart      Lesson notification scheduling
  deadline_reminders.dart    Deadline notification scheduling
assets/map/                 Room data and floor maps
```

## Screenshots

Screenshots of the current app interface will be added here.

## Project Status

TaskHub is a working student project and is still being improved. Planned improvements include refining the interface, collecting more usability feedback, and making common actions even easier to find.

## Contributors

TaskHub is a collaborative student project. See the [contributors and commit history](https://github.com/alikhansabargazy/Android-TaskHub/graphs/contributors) for recorded contributions.

---

*Built for students at Astana IT University.*
