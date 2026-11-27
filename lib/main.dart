import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/app_shell.dart';
import 'screens/auth_screens.dart';
import 'screens/onboarding_screens.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';

export 'config/supabase_config.dart';
export 'models/app_models.dart';
export 'screens/agenda_screen.dart';
export 'screens/app_shell.dart';
export 'screens/auth_screens.dart';
export 'screens/finance_screen.dart';
export 'screens/fixed_tasks_screen.dart';
export 'screens/home_screen.dart';
export 'screens/onboarding_screens.dart';
export 'screens/settings_screen.dart';
export 'screens/subject_notes_screen.dart';
export 'screens/summary_screen.dart';
export 'services/notification_service.dart';
export 'services/storage_service.dart';
export 'services/supabase_service.dart';
export 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.instance.initialize();
  await NotificationService.instance.initialize();
  runApp(const UniSyncApp());
}

class UniSyncApp extends StatefulWidget {
  const UniSyncApp({super.key});

  @override
  State<UniSyncApp> createState() => _UniSyncAppState();
}

class _UniSyncAppState extends State<UniSyncApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<TaskNotificationEvent>? _notificationSub;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _notificationSub =
        NotificationService.instance.events.listen(_handleNotificationEvent);
    _authSub =
        SupabaseService.instance.authStateChanges.listen(_handleAuthChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = NotificationService.instance.takePendingEvent();
      if (pending != null) {
        _handleNotificationEvent(pending);
      }
    });
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _handleAuthChange(AuthState state) async {
    if (state.event == AuthChangeEvent.signedIn) {
      final email = state.session?.user.email;
      if (email == null || email.isEmpty) return;
      await AppStorage.handleSupabaseSessionActive(email);
      final completed = await AppStorage.isOnboardingComplete();
      if (completed) {
        final tasks = await AppStorage.loadFixedTasks();
        await NotificationService.instance.rescheduleAllFixedTasks(tasks);
      }
      final nav = _navigatorKey.currentState;
      if (nav == null) return;
      nav.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) =>
              completed ? const AppShell() : const ProfileSetupScreen(),
        ),
        (_) => false,
      );
    }
  }

  Future<void> _handleNotificationEvent(TaskNotificationEvent event) async {
    if (event.isAgendaEvent) {
      if (event.actionId == NotificationService.actionCompleteEvent) {
        await _completeAgendaEvent(event);
        return;
      }
      final navContext = _navigatorKey.currentContext;
      if (navContext == null || !navContext.mounted) return;
      final done = await showDialog<bool>(
        context: navContext,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            event.taskTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'Deseja marcar este compromisso da agenda como concluído?',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Agora não',
                style: TextStyle(color: ink, fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: blue),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Concluir',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
      if (done == true) {
        await _completeAgendaEvent(event);
      }
      return;
    }

    if (event.actionId == NotificationService.actionDoneYes) {
      await _recordAnswer(event, true);
      return;
    }
    if (event.actionId == NotificationService.actionDoneNo) {
      await _recordAnswer(event, false);
      return;
    }

    final navContext = _navigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;

    final answer = await showDialog<bool>(
      context: navContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          event.taskTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Confirmar hoje?',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Não',
              style: TextStyle(color: ink, fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: blue),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Sim',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (answer != null) {
      await _recordAnswer(event, answer);
    }
  }

  Future<void> _completeAgendaEvent(TaskNotificationEvent event) async {
    await AppStorage.toggleAgendaEventCompleted(
      eventId: event.taskId,
      completed: true,
    );
    await NotificationService.instance.cancelAgendaEvent(event.taskId);
    notifyAppDataChanged();
    _messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text('${event.taskTitle}: concluído!')),
    );
  }

  Future<void> _recordAnswer(TaskNotificationEvent event, bool done) async {
    await AppStorage.recordFixedTaskResponse(
      taskId: event.taskId,
      date: DateTime.now(),
      done: done,
    );
    notifyAppDataChanged();
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          done
              ? '${event.taskTitle}: Sim'
              : '${event.taskTitle}: Não',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      title: 'UniSync',
      theme: buildUniSyncTheme(),
      home: const FirstRunGate(),
    );
  }
}

enum _StartupRoute { loading, login, onboarding, home }

class FirstRunGate extends StatefulWidget {
  const FirstRunGate({super.key});

  @override
  State<FirstRunGate> createState() => _FirstRunGateState();
}

class _FirstRunGateState extends State<FirstRunGate> {
  static const String _releaseNoticeKey = 'release_notice_1_1_0';

  _StartupRoute _route = _StartupRoute.loading;

  @override
  void initState() {
    super.initState();
    _resolveRoute();
  }

  Future<void> _resolveRoute() async {
    final activeEmail = await AppStorage.getActiveUserEmail();
    if (activeEmail == null) {
      if (!mounted) return;
      setState(() => _route = _StartupRoute.login);
      _scheduleReleaseNotice();
      return;
    }

    if (AppStorage.isCloudConnected) {
      await AppStorage.pullFromCloud();
    }

    final completed = await AppStorage.isOnboardingComplete();
    if (completed) {
      final tasks = await AppStorage.loadFixedTasks();
      await NotificationService.instance.rescheduleAllFixedTasks(tasks);
    }

    if (!mounted) return;
    setState(
      () => _route = completed ? _StartupRoute.home : _StartupRoute.onboarding,
    );
    _scheduleReleaseNotice();
  }

  void _scheduleReleaseNotice() {
    if (!kIsWeb) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_showReleaseNotice());
    });
  }

  Future<void> _showReleaseNotice() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_releaseNoticeKey) == true || !mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Novidade no UniSync!',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Agora você pode registrar tarefas fixas como feitas em datas anteriores. '
          'Na Agenda, selecione o dia e toque em “Marcar feita” na tarefa.',
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: blue),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );

    if (mounted) {
      await preferences.setBool(_releaseNoticeKey, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_route) {
      case _StartupRoute.loading:
        return const ColoredBox(
          color: canvas,
          child: Center(child: CircularProgressIndicator(color: blue)),
        );
      case _StartupRoute.login:
        return const LoginScreen();
      case _StartupRoute.onboarding:
        return const ProfileSetupScreen();
      case _StartupRoute.home:
        return const AppShell();
    }
  }
}
