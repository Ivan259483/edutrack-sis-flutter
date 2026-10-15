import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api.dart';
import '../../../core/format.dart';
import '../../../widgets/loader.dart';

/// A shared admin collection and its REST resource (admin/src/data/sync.ts).
enum AdminCollection {
  students('/students', 'student', '/students'),
  enrollments('/enrollments', 'enrollment', '/enrollment'),
  grades('/grades', 'grade', '/grades'),
  schedules('/schedules', 'schedule', '/schedules'),
  announcements('/announcements', 'announcement', '/announcements'),
  tickets('/tickets', 'ticket', '/helpdesk'),
  notifications('/notifications', 'settings', '/'),
  activityLogs('/activity-logs', 'settings', '/');

  const AdminCollection(this.path, this.logType, this.page);

  /// REST resource, e.g. /students.
  final String path;

  /// Activity log `type` for changes to this collection.
  final String logType;

  /// Admin portal page (web path) that shows this collection.
  final String page;
}

/// Everything the admin screens show, loaded from GET /api/admin/bootstrap
/// (the web's RemoteAdminProvider). MongoDB stays the source of truth: every
/// change goes to the API first, and the local copy is replaced with the
/// record the server returns.
///
/// The API's PUT re-validates the whole record and keeps only validated
/// fields, so updates always send the complete record with the changes
/// applied, never just the changed fields.
class AdminStore extends ChangeNotifier {
  AdminStore(this.api);
  final ApiClient api;

  bool loading = false;
  String? error;
  bool get loaded => _loaded;
  bool _loaded = false;

  final Map<AdminCollection, List<Map<String, dynamic>>> _records = {};
  Map<String, dynamic> settings = {};
  List<Map<String, dynamic>> subjects = [];
  List<String> sections = [];

  /// Bumped on every local change, so a refresh that started earlier can't
  /// overwrite it with older data.
  int _version = 0;
  int _saving = 0;

  List<Map<String, dynamic>> records(AdminCollection collection) => _records[collection] ?? const [];
  List<Map<String, dynamic>> get students => records(AdminCollection.students);
  List<Map<String, dynamic>> get enrollments => records(AdminCollection.enrollments);
  List<Map<String, dynamic>> get grades => records(AdminCollection.grades);
  List<Map<String, dynamic>> get schedules => records(AdminCollection.schedules);
  List<Map<String, dynamic>> get announcements => records(AdminCollection.announcements);
  List<Map<String, dynamic>> get tickets => records(AdminCollection.tickets);
  List<Map<String, dynamic>> get notifications => records(AdminCollection.notifications);
  List<Map<String, dynamic>> get activityLogs => records(AdminCollection.activityLogs);

  Map<String, dynamic>? find(AdminCollection collection, String? id) {
    if (id == null) return null;
    for (final record in records(collection)) {
      if (record['id'] == id) return record;
    }
    return null;
  }

  /// First load (with a spinner) or a manual retry.
  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      _apply(asMap(await api.get('/admin/bootstrap'))!);
      _loaded = true;
    } catch (cause) {
      error = apiErrorMessage(cause);
    }
    loading = false;
    notifyListeners();
  }

  /// Loads once per sign-in.
  Future<void> ensureLoaded() async {
    if (!_loaded && !loading) await load();
  }

  /// Background refresh (pull-to-refresh, the 20 s timer, app resume). Keeps
  /// the current data if it fails, and never replaces edits still saving.
  Future<void> refresh() async {
    if (!_loaded) return load();
    if (_saving > 0) return;
    final startedAt = _version;
    try {
      final data = asMap(await api.get('/admin/bootstrap'))!;
      if (_saving > 0 || _version != startedAt) return;
      _apply(data);
      error = null;
      notifyListeners();
    } catch (_) {
      // The next refresh retries.
    }
  }

  void _apply(Map<String, dynamic> data) {
    final state = asMap(data['state']) ?? {};
    for (final collection in AdminCollection.values) {
      _records[collection] = asList(state[collection.name]);
    }
    settings = asMap(state['settings']) ?? {};
    subjects = asList(data['subjects']);
    sections = [for (final s in (data['sections'] as List? ?? const [])) '$s'];
  }

  /// Forgets the data when the administrator signs out.
  void reset() {
    _records.clear();
    settings = {};
    subjects = [];
    sections = [];
    _loaded = false;
    loading = false;
    error = null;
    _version++;
  }

  /// Creates [record] (POST) when it has no id yet, otherwise replaces it
  /// (PUT with the full record). [action] goes to the activity log, like
  /// every admin change on the web. Throws the API error on failure.
  Future<Map<String, dynamic>> save(AdminCollection collection, Map<String, dynamic> record, {required String action}) async {
    final id = record['id'] as String?;
    final isNew = id == null || find(collection, id) == null;
    final saved = asMap(await _write(() => isNew ? api.post(collection.path, record) : api.put('${collection.path}/${Uri.encodeComponent(id)}', record)))!;
    final list = [...records(collection)];
    final index = list.indexWhere((r) => r['id'] == saved['id']);
    if (index >= 0) {
      list[index] = saved;
    } else {
      list.insert(0, saved);
    }
    _records[collection] = list;
    _changed();
    await _log(action, collection);
    return saved;
  }

  /// Deletes [record] (DELETE) and logs [action].
  Future<void> remove(AdminCollection collection, Map<String, dynamic> record, {required String action}) async {
    final id = record['id'] as String;
    await _write(() => api.delete('${collection.path}/${Uri.encodeComponent(id)}'));
    _records[collection] = [...records(collection)]..removeWhere((r) => r['id'] == id);
    _changed();
    await _log(action, collection);
  }

  /// Replaces the system settings (PUT /settings with every field).
  Future<void> saveSettings(Map<String, dynamic> next, {required String action}) async {
    settings = asMap(await _write(() => api.put('/settings', next)))!;
    _changed();
    await _log(action, null, type: 'settings', page: '/settings');
  }

  /// Marks notifications as read (not logged, as on the web).
  Future<void> markRead(Iterable<Map<String, dynamic>> items) async {
    for (final n in items.where((n) => n['read'] != true).toList()) {
      await save(AdminCollection.notifications, {...n, 'read': true}, action: '');
    }
  }

  /// Runs a write; if the server rejects it, reloads the truth and rethrows.
  Future<T> _write<T>(Future<T> Function() request) async {
    _saving++;
    final T result;
    try {
      result = await request();
    } catch (_) {
      _saving--;
      unawaited(refresh());
      rethrow;
    }
    _saving--;
    return result;
  }

  void _changed() {
    _version++;
    notifyListeners();
  }

  /// Appends to the activity log, plus an "Admin activity" notification when
  /// System Activity Notifications are on (admin/src/data/store.tsx). The
  /// change itself is already saved, so a failure here isn't reported.
  Future<void> _log(String action, AdminCollection? collection, {String? type, String? page}) async {
    if (action.isEmpty) return;
    final timestamp = nowIso();
    try {
      final log = asMap(
        await api.post(AdminCollection.activityLogs.path, {'action': action, 'actor': 'Admin', 'timestamp': timestamp, 'type': type ?? collection!.logType}),
      )!;
      _records[AdminCollection.activityLogs] = [log, ...activityLogs];
      if (settings['notifySystemActivity'] == true) {
        final note = asMap(
          await api.post(AdminCollection.notifications.path, {
            'title': 'Admin activity',
            'description': action,
            'timestamp': timestamp,
            'read': false,
            'type': 'announcement',
            'href': page ?? collection!.page,
          }),
        )!;
        _records[AdminCollection.notifications] = [note, ...notifications];
      }
      _changed();
    } catch (_) {
      // Not shown: the change itself succeeded.
    }
  }
}
