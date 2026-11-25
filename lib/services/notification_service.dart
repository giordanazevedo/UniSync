import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/app_models.dart';
import 'storage_service.dart';

class TaskNotificationEvent {
  const TaskNotificationEvent({
    required this.taskId,
    required this.taskTitle,
    this.actionId,
    this.isAgendaEvent = false,
  });

  final String taskId;
  final String taskTitle;
  final String? actionId;
  final bool isAgendaEvent;
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String channelId = 'fixed_tasks_check';
  static const String channelName = 'Tarefas fixas';
  static const String channelDescription =
      'Notificações do UniSync no horário das suas tarefas fixas.';
  static const String agendaChannelId = 'agenda_events_reminders';
  static const String agendaChannelName = 'Compromissos da agenda';
  static const String agendaChannelDescription =
      'Lembretes do UniSync para provas, trabalhos e compromissos por data.';
  static const String actionDoneYes = 'done_yes';
  static const String actionDoneNo = 'done_no';
  static const String actionCompleteEvent = 'complete_event';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<TaskNotificationEvent> _eventController =
      StreamController<TaskNotificationEvent>.broadcast();

  bool _initialized = false;
  TaskNotificationEvent? _pendingEvent;

  Stream<TaskNotificationEvent> get events => _eventController.stream;

  TaskNotificationEvent? takePendingEvent() {
    final event = _pendingEvent;
    _pendingEvent = null;
    return event;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    } catch (_) {}

    if (kIsWeb) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    try {
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _handleResponse,
      );

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.high,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          agendaChannelId,
          agendaChannelName,
          description: agendaChannelDescription,
          importance: Importance.high,
        ),
      );

      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails != null &&
          launchDetails.didNotificationLaunchApp &&
          launchDetails.notificationResponse != null) {
        _handleResponse(launchDetails.notificationResponse!);
      }
    } catch (_) {
      // Ambiente de teste ou plataforma desktop sem suporte a notificações locais.
    }
  }

  void _handleResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      final type = decoded['type'] as String? ?? 'fixed_task';
      if (type == 'agenda_event') {
        final eventId = decoded['eventId'] as String?;
        final eventTitle = decoded['eventTitle'] as String? ?? 'Compromisso';
        if (eventId == null || eventId.isEmpty) return;
        final event = TaskNotificationEvent(
          taskId: eventId,
          taskTitle: eventTitle,
          actionId: response.actionId,
          isAgendaEvent: true,
        );
        if (_eventController.hasListener) {
          _eventController.add(event);
        } else {
          _pendingEvent = event;
        }
        return;
      }

      final taskId = decoded['taskId'] as String?;
      final taskTitle = decoded['taskTitle'] as String? ?? 'Tarefa fixa';
      if (taskId == null || taskId.isEmpty) return;

      final event = TaskNotificationEvent(
        taskId: taskId,
        taskTitle: taskTitle,
        actionId: response.actionId,
      );
      if (_eventController.hasListener) {
        _eventController.add(event);
      } else {
        _pendingEvent = event;
      }
    } catch (_) {}
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission() ?? true;
        try {
          await android.requestExactAlarmsPermission();
        } catch (_) {}
        return granted;
      }

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } catch (_) {}
    return false;
  }

  int _notificationId(String taskId, int weekday) =>
      (taskId.hashCode.abs() % 100000) * 10 + weekday;

  int _agendaNotificationId(String eventId) =>
      2000000 + (eventId.hashCode.abs() % 500000);

  tz.TZDateTime _nextInstanceOfWeekdayAndTime(
    int weekday,
    int hour,
    int minute,
  ) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  NotificationDetails _taskNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            actionDoneYes,
            'Sim',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            actionDoneNo,
            'Não',
            showsUserInterface: true,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      ),
    );
  }

  Future<void> scheduleFixedTask(FixedTask task) async {
    if (kIsWeb) return;
    await cancelFixedTask(task);

    final enabled = await AppStorage.areNotificationsEnabled();
    if (!enabled) return;

    await initialize();
    final granted = await requestPermissions();
    if (!granted) return;

    final parts = task.time.split(':');
    final hour = int.tryParse(parts.first) ?? 8;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final payload = jsonEncode(<String, String>{
      'taskId': task.id,
      'taskTitle': task.title,
    });
    final details = _taskNotificationDetails();

    for (final weekday in task.weekdays) {
      final scheduled = _nextInstanceOfWeekdayAndTime(weekday, hour, minute);
      final id = _notificationId(task.id, weekday);
      try {
        await _plugin.zonedSchedule(
          id,
          task.title,
          'Hoje às ${task.time} · Responder Sim ou Não',
          scheduled,
          details,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      } catch (_) {
        try {
          await _plugin.zonedSchedule(
            id,
            task.title,
            'Hoje às ${task.time} · Responder Sim ou Não',
            scheduled,
            details,
            payload: payload,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        } catch (_) {}
      }
    }
  }

  Future<void> cancelFixedTask(FixedTask task) async {
    if (kIsWeb) return;
    try {
      for (var day = 1; day <= 7; day++) {
        await _plugin.cancel(_notificationId(task.id, day));
      }
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  Future<void> rescheduleAllFixedTasks(List<FixedTask> tasks) async {
    final events = await AppStorage.loadAgendaEvents();
    await rescheduleAll(tasks: tasks, events: events);
  }

  Future<void> rescheduleAll({
    required List<FixedTask> tasks,
    required List<AgendaEvent> events,
  }) async {
    if (kIsWeb) return;
    await cancelAll();
    final enabled = await AppStorage.areNotificationsEnabled();
    if (!enabled) return;
    for (final task in tasks) {
      await scheduleFixedTask(task);
    }
    for (final event in events) {
      await scheduleAgendaEvent(event);
    }
  }

  NotificationDetails _agendaNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        agendaChannelId,
        agendaChannelName,
        channelDescription: agendaChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            actionCompleteEvent,
            'Concluir',
            showsUserInterface: true,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      ),
    );
  }

  Future<DateTime?> scheduleAgendaEvent(AgendaEvent event) async {
    if (kIsWeb) return null;
    await cancelAgendaEvent(event.id);

    if (event.completed || event.reminderMinutesBefore == null) return null;

    final enabled = await AppStorage.areNotificationsEnabled();
    if (!enabled) return null;

    await initialize();
    final granted = await requestPermissions();
    if (!granted) return null;

    final eventDt = event.scheduledDateTime;
    final now = tz.TZDateTime.now(tz.local);
    final tzEventDt = tz.TZDateTime(
      tz.local,
      eventDt.year,
      eventDt.month,
      eventDt.day,
      eventDt.hour,
      eventDt.minute,
    );
    var notifyAt = tzEventDt.subtract(
      Duration(minutes: event.reminderMinutesBefore!),
    );

    // Se o aviso antecipado já passou mas o compromisso ainda vai acontecer,
    // agenda para o horário exato do compromisso para o aluno não perder.
    if (!notifyAt.isAfter(now)) {
      if (tzEventDt.isAfter(now)) {
        notifyAt = tzEventDt;
      } else {
        return null;
      }
    }

    final bodyParts = <String>[
      '${event.category} · ${event.time}',
      if (event.reminderMinutesBefore != null &&
          event.reminderMinutesBefore! > 0)
        event.reminderLabel,
      if (event.notes.trim().isNotEmpty) event.notes.trim(),
    ];
    final payload = jsonEncode(<String, String>{
      'type': 'agenda_event',
      'eventId': event.id,
      'eventTitle': event.title,
    });
    final id = _agendaNotificationId(event.id);
    final details = _agendaNotificationDetails();

    try {
      await _plugin.zonedSchedule(
        id,
        event.title,
        bodyParts.join(' · '),
        notifyAt,
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      return notifyAt;
    } catch (_) {
      try {
        await _plugin.zonedSchedule(
          id,
          event.title,
          bodyParts.join(' · '),
          notifyAt,
          details,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        return notifyAt;
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> cancelAgendaEvent(String eventId) async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(_agendaNotificationId(eventId));
    } catch (_) {}
  }

  Future<bool> showTestQuestionNotification(FixedTask task) async {
    if (kIsWeb) return false;
    await initialize();
    final granted = await requestPermissions();
    if (!granted) return false;

    try {
      await _plugin.show(
        _notificationId(task.id, 9),
        task.title,
        'Hoje às ${task.time} · Responder Sim ou Não',
        _taskNotificationDetails(),
        payload: jsonEncode(<String, String>{
          'taskId': task.id,
          'taskTitle': task.title,
        }),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> showGeneralTestNotification() async {
    if (kIsWeb) return false;
    await initialize();
    final granted = await requestPermissions();
    if (!granted) return false;

    try {
      await _plugin.show(
        999001,
        'UniSync',
        'Notificações ativadas com sucesso no seu celular!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: true,
          ),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
