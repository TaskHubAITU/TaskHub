import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskhub/planner_sync.dart';
import 'package:taskhub/taskhub_api.dart';

class FakeApi extends TaskHubApi {
  Map<String, dynamic> remote = {'revision': 0, 'lessons': [], 'deadlines': []};
  bool offline = false;
  FakeApi() {
    token = 'fake';
    userId = 1;
  }
  @override
  Future<void> restore() async {}
  @override
  Future<Map<String, dynamic>> call(
    String method,
    String path, [
    Map<String, dynamic>? data,
  ]) async {
    if (offline) throw Exception('offline');
    if (method == 'GET') return Map.of(remote);
    if (data!['revision'] != remote['revision']) {
      throw const ApiError('revision_conflict (409)');
    }
    remote = {...data, 'revision': (remote['revision'] as int) + 1};
    return {'revision': remote['revision']};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('pending changes survive controller restart and retry', () async {
    final api = FakeApi();
    final first = PlannerSync(api);
    await first.start();
    api.offline = true;
    await first.edit([
      {'id': 'local'},
    ], []);
    expect(first.pending, true);
    first.dispose();
    final second = PlannerSync(api);
    await second.start();
    expect(second.state['lessons'], [
      {'id': 'local'},
    ]);
    api.offline = false;
    await second.sync();
    expect(second.pending, false);
    expect(api.remote['lessons'], [
      {'id': 'local'},
    ]);
    second.dispose();
  });
  test('conflicts preserve local changes until explicit resolution', () async {
    final api = FakeApi();
    final sync = PlannerSync(api);
    await sync.start();
    api.remote = {
      'revision': 1,
      'lessons': [
        {'id': 'remote'},
      ],
      'deadlines': [],
    };
    await sync.edit([
      {'id': 'local'},
    ], []);
    expect(sync.conflict, true);
    expect(api.remote['lessons'], [
      {'id': 'remote'},
    ]);
    await sync.resolve(keepLocal: true);
    expect(api.remote['lessons'], [
      {'id': 'local'},
    ]);
    expect(sync.conflict, false);
    sync.dispose();
  });
  test('guest import is explicit and repeatable without duplicates', () async {
    SharedPreferences.setMockInitialValues({
      'taskhub_lessons': '[{"id":"guest"}]',
    });
    final api = FakeApi();
    final sync = PlannerSync(api);
    await sync.start();
    expect(sync.state['lessons'], isEmpty);
    await sync.importGuest();
    await sync.importGuest();
    expect(api.remote['lessons'], [
      {'id': 'guest_guest'},
    ]);
    sync.dispose();
  });
  test(
    'switching accounts never uploads the previous pending planner',
    () async {
      final api = FakeApi();
      final sync = PlannerSync(api);
      await sync.start();
      api.offline = true;
      await sync.edit([
        {'id': 'private-user-one'},
      ], []);
      api.userId = 2;
      api.remote = {'revision': 0, 'lessons': [], 'deadlines': []};
      api.offline = false;
      api.notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(sync.state['lessons'], isEmpty);
      expect(api.remote['lessons'], isEmpty);
      sync.dispose();
    },
  );
}
