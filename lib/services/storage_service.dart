import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';
import 'supabase_service.dart';

class AppStorage {
  static const String _accountsKey = 'registered_accounts';
  static const String _activeUserKey = 'active_user_email';

  static const String _onboardingKey = 'onboarding_complete';
  static const String _profileNameKey = 'profile_name';
  static const String _profileCourseKey = 'profile_course';
  static const String _profilePeriodKey = 'profile_period';
  static const String _profileShiftKey = 'profile_shift';
  static const String _legacySemesterKey = 'profile_semester';
  static const String _subjectsKey = 'subjects';
  static const String _fixedTasksKey = 'fixed_tasks';
  static const String _attendanceKey = 'attendance_records';
  static const String _financeKey = 'finance_entries';
  static const String _agendaEventsKey = 'agenda_events';
  static const String _cloudAgendaEventsReservedKey = '__agenda_events__';
  static const String _notificationsKey = 'notifications_enabled';

  static final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static bool get isCloudConnected =>
      SupabaseService.instance.isReady &&
      SupabaseService.instance.currentUser != null;

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  static bool isValidEmail(String email) =>
      _emailRegex.hasMatch(_normalizeEmail(email));

  static String? validatePassword(String password) {
    if (password.length < 6) {
      return 'A senha deve ter pelo menos 6 caracteres.';
    }
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasDigit = RegExp(r'[0-9]').hasMatch(password);
    if (!hasLetter || !hasDigit) {
      return 'A senha deve conter pelo menos uma letra e um número.';
    }
    return null;
  }

  static String _hashPassword(String email, String password) {
    final input = utf8.encode('unisync::${_normalizeEmail(email)}::$password');
    var h1 = 0x811c9dc5;
    var h2 = 0x01000193;
    for (final byte in input) {
      h1 ^= byte;
      h1 = (h1 * 0x01000193) & 0xFFFFFFFF;
      h2 ^= (byte + 31) & 0xFF;
      h2 = (h2 * 0x01000193) & 0xFFFFFFFF;
    }
    return '${h1.toRadixString(16).padLeft(8, '0')}${h2.toRadixString(16).padLeft(8, '0')}';
  }

  static String _key(SharedPreferences prefs, String baseKey) {
    final email = prefs.getString(_activeUserKey)?.trim().toLowerCase() ?? '';
    if (email.isEmpty) return baseKey;
    return 'u_${email}_$baseKey';
  }

  static String? _getString(SharedPreferences prefs, String baseKey) {
    final scoped = prefs.getString(_key(prefs, baseKey));
    if (scoped != null) return scoped;
    final email = prefs.getString(_activeUserKey)?.trim() ?? '';
    if (email.isEmpty) return prefs.getString(baseKey);
    return null;
  }

  static bool? _getBool(SharedPreferences prefs, String baseKey) {
    final scoped = prefs.getBool(_key(prefs, baseKey));
    if (scoped != null) return scoped;
    final email = prefs.getString(_activeUserKey)?.trim() ?? '';
    if (email.isEmpty) return prefs.getBool(baseKey);
    return null;
  }

  // ==================== AUTENTICAÇÃO E CONTAS ====================

  static Future<String?> getActiveUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    if (SupabaseService.instance.isReady) {
      final cloudEmail = SupabaseService.instance.currentUserEmail;
      if (cloudEmail != null && cloudEmail.isNotEmpty) {
        await prefs.setString(_activeUserKey, cloudEmail);
        return cloudEmail;
      }
      await prefs.remove(_activeUserKey);
      return null;
    }

    final email = prefs.getString(_activeUserKey)?.trim().toLowerCase();
    if (email == null || email.isEmpty) return null;
    return email;
  }

  static Future<Map<String, String>> _loadAccountsMap(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_accountsKey);
    if (raw == null || raw.trim().isEmpty) return <String, String>{};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return <String, String>{};
    }
  }

  static Future<AuthOutcome> registerAccount({
    required String email,
    required String password,
  }) async {
    final normalized = _normalizeEmail(email);
    if (!isValidEmail(normalized)) {
      return const AuthOutcome(
        error: 'Informe um endereço de e-mail válido (ex.: nome@email.com).',
      );
    }
    final passwordError = validatePassword(password);
    if (passwordError != null) {
      return AuthOutcome(error: passwordError);
    }

    if (SupabaseService.instance.isReady) {
      final outcome = await SupabaseService.instance.signUp(
        email: normalized,
        password: password,
      );
      if (outcome.isSuccess) {
        await handleSupabaseSessionActive(normalized);
      }
      return outcome;
    }

    final prefs = await SharedPreferences.getInstance();
    final accounts = await _loadAccountsMap(prefs);
    if (accounts.containsKey(normalized)) {
      return const AuthOutcome(
        error: 'Já existe uma conta cadastrada com este e-mail. Faça login.',
      );
    }

    accounts[normalized] = _hashPassword(normalized, password);
    await prefs.setString(_accountsKey, jsonEncode(accounts));
    await prefs.setString(_activeUserKey, normalized);
    return const AuthOutcome();
  }

  static Future<AuthOutcome> signIn({
    required String email,
    required String password,
  }) async {
    final normalized = _normalizeEmail(email);
    if (!isValidEmail(normalized)) {
      return const AuthOutcome(
        error: 'Informe um endereço de e-mail válido (ex.: nome@email.com).',
      );
    }
    if (password.isEmpty) {
      return const AuthOutcome(error: 'Informe sua senha.');
    }

    if (SupabaseService.instance.isReady) {
      final outcome = await SupabaseService.instance.signInWithPassword(
        email: normalized,
        password: password,
      );
      if (outcome.isSuccess) {
        await handleSupabaseSessionActive(normalized);
      }
      return outcome;
    }

    final prefs = await SharedPreferences.getInstance();
    final accounts = await _loadAccountsMap(prefs);
    final storedHash = accounts[normalized];
    if (storedHash == null) {
      return const AuthOutcome(
        error: 'Conta não encontrada. Crie uma conta primeiro.',
      );
    }
    if (storedHash != _hashPassword(normalized, password)) {
      return const AuthOutcome(error: 'Senha incorreta. Tente novamente.');
    }

    await prefs.setString(_activeUserKey, normalized);
    return const AuthOutcome();
  }

  static Future<AuthOutcome> signInWithGoogle() {
    return SupabaseService.instance.signInWithGoogle();
  }

  static Future<String?> sendPasswordReset(String email) {
    final normalized = _normalizeEmail(email);
    if (!isValidEmail(normalized)) {
      return Future<String?>.value('Informe um e-mail válido para recuperação.');
    }
    return SupabaseService.instance.sendPasswordReset(normalized);
  }

  static Future<void> handleSupabaseSessionActive(String email) async {
    final normalized = _normalizeEmail(email);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeUserKey, normalized);
    await pullFromCloud();

    // Se entrou com Google pela primeira vez, aproveita o nome da conta Google no perfil.
    final currentProfile = await loadProfile();
    if (currentProfile.name.isEmpty) {
      final meta = SupabaseService.instance.currentUser?.userMetadata;
      final googleName = (meta?['full_name'] ?? meta?['name'] ?? '')
          .toString()
          .trim();
      if (googleName.isNotEmpty) {
        await saveProfile(
          UserProfile(
            name: googleName,
            course: currentProfile.course,
            period: currentProfile.period,
            shift: currentProfile.shift,
          ),
        );
      }
    }
  }

  static Future<void> signOut() async {
    await SupabaseService.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeUserKey);
  }

  static Future<void> resetCurrentUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_activeUserKey)?.trim().toLowerCase() ?? '';
    if (email.isNotEmpty) {
      final prefix = 'u_${email}_';
      final keysToRemove =
          prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
      for (final k in keysToRemove) {
        await prefs.remove(k);
      }
    } else {
      final keysToRemove = prefs
          .getKeys()
          .where((k) => k != _accountsKey && k != _activeUserKey)
          .toList();
      for (final k in keysToRemove) {
        await prefs.remove(k);
      }
    }
    await pushToCloud();
  }

  // ==================== SINCRONIZAÇÃO EM NUVEM (SUPABASE) ====================

  static Future<bool> pullFromCloud() async {
    if (!isCloudConnected) return false;
    final row = await SupabaseService.instance.fetchUserCloudData();
    if (row == null) return false;

    final prefs = await SharedPreferences.getInstance();

    final onboarding = row['onboarding_complete'] == true;
    await prefs.setBool(_key(prefs, _onboardingKey), onboarding);

    if (row['profile'] is Map) {
      final profileMap = Map<String, dynamic>.from(row['profile'] as Map);
      final name = (profileMap['name'] as String?)?.trim() ?? '';
      final course = (profileMap['course'] as String?)?.trim() ?? '';
      final period = (profileMap['period'] as String?)?.trim() ?? '';
      final shift = (profileMap['shift'] as String?)?.trim() ?? '';
      await prefs.setString(_key(prefs, _profileNameKey), name);
      await prefs.setString(_key(prefs, _profileCourseKey), course);
      await prefs.setString(_key(prefs, _profilePeriodKey), period);
      await prefs.setString(_key(prefs, _profileShiftKey), shift);
      await prefs.setString(_key(prefs, _legacySemesterKey), period);
    }

    if (row['subjects'] is List) {
      await prefs.setString(
        _key(prefs, _subjectsKey),
        jsonEncode(row['subjects']),
      );
    }

    if (row['subject_notes'] is Map) {
      final notesMap = Map<String, dynamic>.from(row['subject_notes'] as Map);
      for (final entry in notesMap.entries) {
        if (entry.key == _cloudAgendaEventsReservedKey && entry.value is List) {
          await prefs.setString(
            _key(prefs, _agendaEventsKey),
            jsonEncode(entry.value),
          );
          continue;
        }
        await prefs.setString(
          _key(prefs, _notesBaseKey(entry.key)),
          jsonEncode(entry.value),
        );
      }
    }

    if (row['fixed_tasks'] is List) {
      await prefs.setString(
        _key(prefs, _fixedTasksKey),
        jsonEncode(row['fixed_tasks']),
      );
    }

    if (row['attendance_records'] is Map) {
      await prefs.setString(
        _key(prefs, _attendanceKey),
        jsonEncode(row['attendance_records']),
      );
    }

    if (row['finance_entries'] is List) {
      await prefs.setString(
        _key(prefs, _financeKey),
        jsonEncode(row['finance_entries']),
      );
    }

    if (row['notifications_enabled'] is bool) {
      await prefs.setBool(
        _key(prefs, _notificationsKey),
        row['notifications_enabled'] as bool,
      );
    }

    return true;
  }

  static Future<bool> pushToCloud() async {
    if (!isCloudConnected) return false;

    final onboarding = await isOnboardingComplete();
    final profile = await loadProfile();
    final subjects = await loadSubjects();
    final subjectNotes = <String, List<Map<String, dynamic>>>{};
    for (final subject in subjects) {
      final notes = await loadSubjectNotes(subject);
      subjectNotes[subject.id] = notes.map((n) => n.toJson()).toList();
    }
    final agendaEvents = await loadAgendaEvents();
    subjectNotes[_cloudAgendaEventsReservedKey] =
        agendaEvents.map((e) => e.toJson()).toList();
    final fixedTasks = await loadFixedTasks();
    final attendance = await loadAttendanceMap();
    final finance = await loadFinanceEntries();
    final notifications = await areNotificationsEnabled();

    return SupabaseService.instance.saveUserCloudData(<String, dynamic>{
      'onboarding_complete': onboarding,
      'profile': <String, String>{
        'name': profile.name,
        'course': profile.course,
        'period': profile.period,
        'shift': profile.shift,
      },
      'subjects': subjects.map((s) => s.toJson()).toList(),
      'subject_notes': subjectNotes,
      'fixed_tasks': fixedTasks.map((t) => t.toJson()).toList(),
      'attendance_records': attendance,
      'finance_entries': finance.map((f) => f.toJson()).toList(),
      'notifications_enabled': notifications,
    });
  }

  static void _syncInBackground() {
    if (!isCloudConnected) return;
    unawaited(pushToCloud());
  }

  // ==================== ONBOARDING E PERFIL ====================

  static Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return _getBool(prefs, _onboardingKey) ?? false;
  }

  static Future<void> setOnboardingComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(prefs, _onboardingKey), value);
    _syncInBackground();
  }

  static Future<UserProfile> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final name = _getString(prefs, _profileNameKey)?.trim() ?? '';
    final course = _getString(prefs, _profileCourseKey)?.trim() ?? '';
    final period = _getString(prefs, _profilePeriodKey)?.trim() ??
        _getString(prefs, _legacySemesterKey)?.trim() ??
        '';
    final shift = _getString(prefs, _profileShiftKey)?.trim() ?? '';
    return UserProfile(
      name: name,
      course: course,
      period: period,
      shift: shift,
    );
  }

  static Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(prefs, _profileNameKey), profile.name.trim());
    await prefs.setString(
      _key(prefs, _profileCourseKey),
      profile.course.trim(),
    );
    await prefs.setString(
      _key(prefs, _profilePeriodKey),
      profile.period.trim(),
    );
    await prefs.setString(_key(prefs, _profileShiftKey), profile.shift.trim());
    await prefs.setString(
      _key(prefs, _legacySemesterKey),
      profile.period.trim(),
    );
    _syncInBackground();
  }

  // ==================== DISCIPLINAS E ANOTAÇÕES ====================

  static Future<List<SubjectItem>> loadSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _getString(prefs, _subjectsKey);
    if (raw == null || raw.trim().isEmpty) return <SubjectItem>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .asMap()
          .entries
          .map(
            (entry) => SubjectItem.fromJson(
              entry.value as Map<String, dynamic>,
              entry.key,
            ),
          )
          .where((subject) => subject.name.isNotEmpty)
          .toList();
    } catch (_) {
      return <SubjectItem>[];
    }
  }

  static Future<void> saveSubjects(List<SubjectItem> subjects) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(prefs, _subjectsKey),
      jsonEncode(subjects.map((subject) => subject.toJson()).toList()),
    );
    _syncInBackground();
  }

  static String _notesBaseKey(String subjectId) =>
      'subject_notes_list_$subjectId';

  static Future<List<SubjectNote>> loadSubjectNotes(
    SubjectItem subject,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = _getString(prefs, _notesBaseKey(subject.id));
    if (rawList != null && rawList.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawList) as List<dynamic>;
        final notes = decoded
            .map((item) => SubjectNote.fromJson(item as Map<String, dynamic>))
            .toList();
        notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return notes;
      } catch (_) {}
    }

    final legacyText =
        _getString(prefs, 'subject_notes_${subject.name}')?.trim() ?? '';
    if (legacyText.isNotEmpty) {
      final migrated = <SubjectNote>[
        SubjectNote(
          id: 'migrated_${subject.id}',
          title: 'Anotações gerais',
          content: legacyText,
          updatedAt: DateTime.now(),
        ),
      ];
      await saveSubjectNotes(subject.id, migrated);
      return migrated;
    }

    return <SubjectNote>[];
  }

  static Future<void> saveSubjectNotes(
    String subjectId,
    List<SubjectNote> notes,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(prefs, _notesBaseKey(subjectId)),
      jsonEncode(notes.map((note) => note.toJson()).toList()),
    );
    _syncInBackground();
  }

  static Future<Map<String, int>> loadSubjectNoteCounts(
    List<SubjectItem> subjects,
  ) async {
    final counts = <String, int>{};
    for (final subject in subjects) {
      final notes = await loadSubjectNotes(subject);
      counts[subject.id] = notes.length;
    }
    return counts;
  }

  // ==================== TAREFAS FIXAS ====================

  static Future<List<FixedTask>> loadFixedTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _getString(prefs, _fixedTasksKey);
    if (raw == null || raw.trim().isEmpty) return <FixedTask>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((value) => FixedTask.fromJson(value as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return <FixedTask>[];
    }
  }

  static Future<void> saveFixedTasks(List<FixedTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(prefs, _fixedTasksKey),
      jsonEncode(tasks.map((task) => task.toJson()).toList()),
    );
    _syncInBackground();
  }

  static Future<List<FixedTask>> recordFixedTaskResponse({
    required String taskId,
    required DateTime date,
    required bool done,
  }) async {
    final key = dateKey(date);
    final tasks = await loadFixedTasks();
    final updated = tasks
        .map((task) => task.id == taskId ? task.withResponse(key, done) : task)
        .toList();
    await saveFixedTasks(updated);
    return updated;
  }

  // ==================== PRESENÇA E FINANÇAS ====================

  static Future<Map<String, bool>> loadAttendanceMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _getString(prefs, _attendanceKey);
    if (raw == null || raw.trim().isEmpty) return <String, bool>{};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value == true));
    } catch (_) {
      return <String, bool>{};
    }
  }

  static Future<Map<String, bool>> saveAttendance(
    DateTime date,
    bool attended,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final records = await loadAttendanceMap();
    records[dateKey(date)] = attended;
    await prefs.setString(_key(prefs, _attendanceKey), jsonEncode(records));
    _syncInBackground();
    return records;
  }

  static Future<List<FinanceEntry>> loadFinanceEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _getString(prefs, _financeKey);
    if (raw == null || raw.trim().isEmpty) return <FinanceEntry>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final list = decoded
          .map((item) => FinanceEntry.fromJson(item as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (_) {
      return <FinanceEntry>[];
    }
  }

  static Future<void> saveFinanceEntries(List<FinanceEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(prefs, _financeKey),
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
    _syncInBackground();
  }

  // ==================== COMPROMISSOS POR DATA (AGENDA) ====================

  static Future<List<AgendaEvent>> loadAgendaEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _getString(prefs, _agendaEventsKey);
    if (raw == null || raw.trim().isEmpty) return <AgendaEvent>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final list = decoded
          .map((item) => AgendaEvent.fromJson(item as Map<String, dynamic>))
          .where((event) => event.title.isNotEmpty)
          .toList();
      list.sort((a, b) {
        final byDate = a.dateKey.compareTo(b.dateKey);
        if (byDate != 0) return byDate;
        return a.time.compareTo(b.time);
      });
      return list;
    } catch (_) {
      return <AgendaEvent>[];
    }
  }

  static Future<void> saveAgendaEvents(List<AgendaEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(prefs, _agendaEventsKey),
      jsonEncode(events.map((event) => event.toJson()).toList()),
    );
    _syncInBackground();
  }

  static Future<List<AgendaEvent>> toggleAgendaEventCompleted({
    required String eventId,
    required bool completed,
  }) async {
    final events = await loadAgendaEvents();
    final updated = events
        .map((e) => e.id == eventId ? e.copyWith(completed: completed) : e)
        .toList();
    await saveAgendaEvents(updated);
    return updated;
  }

  // ==================== NOTIFICAÇÕES ====================

  static Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return _getBool(prefs, _notificationsKey) ?? true;
  }

  static Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(prefs, _notificationsKey), enabled);
    _syncInBackground();
  }
}
