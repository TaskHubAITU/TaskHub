import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'taskhub_api.dart';

/// A pending write is scoped to one account and retains its original revision.
/// Conflicts require an explicit choice; they never silently overwrite data.
class PlannerSync extends ChangeNotifier {
  final TaskHubApi api;
  PlannerSync(this.api);
  Map<String, dynamic> state = {'revision': 0, 'lessons': [], 'deadlines': []};
  bool loading = true;
  bool pending = false;
  bool conflict = false;
  String? error;
  int? _account;
  int _generation = 0;
  int _edits = 0;
  bool _running = false;
  bool _disposed = false;
  Timer? _timer;
  Future<void> _persistence = Future.value();
  String get _key => 'planner_account_$_account';

  Future<void> start() async {
    try {
      if (!pagesDemoWithoutApi) await api.restore();
    } catch (_) {
      if (api.userId == null) await api.clearSession();
      error = 'Could not restore your session. Sign in when online.';
    }
    if (_disposed) return;
    api.addListener(_sessionChanged);
    await _switchAccount();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => sync());
  }

  void _sessionChanged() {
    final deleted = api.deletedAccount;
    if (deleted != null) {
      api.deletedAccount = null;
      unawaited(_purgeAccount(deleted));
    }
    if (_account != api.userId) unawaited(_switchAccount());
  }

  Future<void> _purgeAccount(int id) async {
    await _persistence.catchError((Object _) {});
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('planner_account_$id');
    await prefs.remove('planner_account_${id}_conflict_backup');
  }

  Future<void> _switchAccount() async {
    final generation = ++_generation;
    _account = api.userId;
    loading = true;
    pending = false;
    conflict = false;
    if (!_disposed) notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (generation != _generation) return;
    final saved = prefs.getString(_key);
    try {
      if (saved != null) {
        final data = jsonDecode(saved) as Map<String, dynamic>;
        state = Map<String, dynamic>.from(data['state'] as Map);
        pending = data['pending'] == true;
      } else {
        state = {
          'revision': 0,
          'lessons': _account == null
              ? jsonDecode(prefs.getString('taskhub_lessons') ?? '[]')
              : [],
          'deadlines': _account == null
              ? jsonDecode(prefs.getString('taskhub_deadlines') ?? '[]')
              : [],
        };
      }
    } catch (_) {
      if (saved != null) {
        await prefs.setString('${_key}_unreadable_backup', saved);
      }
      if (generation != _generation) return;
      state = {'revision': 0, 'lessons': [], 'deadlines': []};
      error = 'Saved planner could not be read. Original storage was retained.';
    }
    loading = false;
    if (!_disposed) notifyListeners();
    await sync();
  }

  Future<void> _save() {
    final key = _key;
    final value = jsonEncode({'state': state, 'pending': pending});
    _persistence = _persistence.catchError((Object _) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(key, value)) {
        throw StateError('Could not save planner');
      }
    });
    return _persistence;
  }

  Future<void> edit(List<dynamic> lessons, List<dynamic> deadlines) async {
    if (loading) return;
    state = {...state, 'lessons': lessons, 'deadlines': deadlines};
    _edits++;
    pending = _account != null;
    await _save();
    if (!_disposed) notifyListeners();
    await sync();
  }

  Future<void> sync() async {
    if (_running ||
        loading ||
        conflict ||
        _account == null ||
        api.token == null) {
      return;
    }
    _running = true;
    final generation = _generation;
    final edits = _edits;
    try {
      if (pending) {
        final result = await api.call('PUT', '/api/v1/state', Map.of(state));
        if (generation != _generation) return;
        state = {...state, 'revision': result['revision']};
        pending = edits != _edits;
      } else {
        final result = await api.call('GET', '/api/v1/state');
        if (generation != _generation || edits != _edits) return;
        state = result;
      }
      error = null;
      await _save();
    } catch (e) {
      if (generation != _generation) return;
      conflict = e.toString().contains('revision_conflict');
      error = conflict
          ? 'This planner changed on another device. Choose which version to keep.'
          : 'Changes are saved on this device. Cloud sync will retry.';
    } finally {
      _running = false;
      if (!_disposed) notifyListeners();
    }
    if (pending && !conflict && error == null) await sync();
  }

  Future<void> importGuest() async {
    if (_account == null || loading || conflict) return;
    final generation = _generation;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('planner_account_null');
    final guest = saved == null
        ? {
            'lessons': jsonDecode(prefs.getString('taskhub_lessons') ?? '[]'),
            'deadlines': jsonDecode(
              prefs.getString('taskhub_deadlines') ?? '[]',
            ),
          }
        : (jsonDecode(saved) as Map)['state'] as Map;
    if (generation != _generation) return;
    List<dynamic> merge(String key) {
      final result = List<dynamic>.from(state[key] as List);
      final ids = result.map((e) => (e as Map)['id']).toSet();
      for (final raw in guest[key] as List) {
        final item = Map<String, dynamic>.from(raw as Map);
        item['id'] = 'guest_${item['id']}';
        if (ids.add(item['id'])) result.add(item);
      }
      return result;
    }

    await edit(merge('lessons'), merge('deadlines'));
  }

  Future<void> resolve({required bool keepLocal}) async {
    final generation = _generation;
    final remote = await api.call('GET', '/api/v1/state');
    if (generation != _generation) return;
    // Retain the discarded version for recovery on this device.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${_key}_conflict_backup',
      jsonEncode(keepLocal ? remote : state),
    );
    state = keepLocal ? {...state, 'revision': remote['revision']} : remote;
    pending = keepLocal;
    conflict = false;
    error = null;
    await _save();
    if (!_disposed) notifyListeners();
    await sync();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    api.removeListener(_sessionChanged);
    super.dispose();
  }
}
