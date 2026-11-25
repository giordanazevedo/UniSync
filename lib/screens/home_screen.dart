import 'package:material_ui/material_ui.dart';

import '../models/app_models.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'fixed_tasks_screen.dart';
import 'onboarding_screens.dart';
import 'settings_screen.dart';
import 'subject_notes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.refreshTick,
    required this.onDataChanged,
  });

  final int refreshTick;
  final VoidCallback onDataChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserProfile profile = const UserProfile(name: '', course: '', period: '');
  List<SubjectItem> subjects = <SubjectItem>[];
  Map<String, int> noteCounts = <String, int>{};
  List<FixedTask> fixedTasks = <FixedTask>[];
  List<AgendaEvent> agendaEvents = <AgendaEvent>[];
  bool? attendedToday;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final loadedProfile = await AppStorage.loadProfile();
    final loadedSubjects = await AppStorage.loadSubjects();
    final loadedCounts = await AppStorage.loadSubjectNoteCounts(loadedSubjects);
    final loadedTasks = await AppStorage.loadFixedTasks();
    final loadedEvents = await AppStorage.loadAgendaEvents();
    final attendanceMap = await AppStorage.loadAttendanceMap();
    final todayKey = dateKey(DateTime.now());

    if (!mounted) return;
    setState(() {
      profile = loadedProfile;
      subjects = loadedSubjects;
      noteCounts = loadedCounts;
      fixedTasks = loadedTasks;
      agendaEvents = loadedEvents;
      attendedToday = attendanceMap[todayKey];
    });
  }

  Future<void> _toggleAgendaEvent(AgendaEvent event) async {
    final nextDone = !event.completed;
    final updated = await AppStorage.toggleAgendaEventCompleted(
      eventId: event.id,
      completed: nextDone,
    );
    if (nextDone) {
      await NotificationService.instance.cancelAgendaEvent(event.id);
    } else {
      await NotificationService.instance
          .scheduleAgendaEvent(event.copyWith(completed: false));
    }
    if (!mounted) return;
    setState(() => agendaEvents = updated);
    widget.onDataChanged();
  }

  Future<void> _answerFixedTask(FixedTask task, bool done) async {
    final updated = await AppStorage.recordFixedTaskResponse(
      taskId: task.id,
      date: DateTime.now(),
      done: done,
    );
    if (!mounted) return;
    setState(() => fixedTasks = updated);
    widget.onDataChanged();
  }

  Future<void> _setAttendance(bool attended) async {
    await AppStorage.saveAttendance(DateTime.now(), attended);
    if (!mounted) return;
    setState(() => attendedToday = attended);
    widget.onDataChanged();
  }

  double _semesterProgress(DateTime now) {
    // Progresso estimado dentro do semestre atual (Jan–Jun ou Jul–Dez).
    final monthInHalf = now.month <= 6 ? now.month : now.month - 6;
    final fraction = ((monthInHalf - 1) + (now.day / 30.0)) / 6.0;
    return fraction.clamp(0.05, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayKey = dateKey(now);
    final todayWeekday = now.weekday;
    final progress = _semesterProgress(now);
    final progressPercent = (progress * 100).round();
    final nowTimeLabel =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final todayStart = DateTime(now.year, now.month, now.day);
    final upcomingEvents = agendaEvents.where((event) {
      if (event.dateKey == todayKey) return true;
      if (event.completed) return false;
      final diff = event.date.difference(todayStart).inDays;
      return diff >= 0 && diff <= 7;
    }).toList();

    final sortedTasks = List<FixedTask>.from(fixedTasks)
      ..sort((a, b) {
        final aToday = a.isScheduledForWeekday(todayWeekday) ? 0 : 1;
        final bToday = b.isScheduledForWeekday(todayWeekday) ? 0 : 1;
        if (aToday != bToday) return aToday.compareTo(bToday);
        return a.time.compareTo(b.time);
      });

    final sortedSubjects = List<SubjectItem>.from(subjects)
      ..sort((a, b) {
        final aToday = a.occursOnWeekday(todayWeekday) ? 0 : 1;
        final bToday = b.occursOnWeekday(todayWeekday) ? 0 : 1;
        if (aToday != bToday) return aToday.compareTo(bToday);
        return a.startTime.compareTo(b.startTime);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        // Card de boas-vindas (azul claro, iniciais, data e engrenagem)
        SurfaceCard(
          color: paleBlue,
          borderSideColor: paleBlueBorder,
          borderRadius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Avatar(initials: profile.initials, radius: 25),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Olá, ${profile.firstName}!',
                      style: const TextStyle(
                        color: blue,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        letterSpacing: -0.4,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatDatePt(now),
                      style: const TextStyle(color: muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              SettingsButton(
                onPressed: () async {
                  await pushScreen<void>(
                    context,
                    SettingsScreen(onDataChanged: widget.onDataChanged),
                  );
                  await _loadData();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Card Curso, Período e Progresso
        SurfaceCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Metric(
                      label: 'CURSO',
                      value: profile.course.isEmpty
                          ? 'Não informado'
                          : profile.course,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Metric(
                      label: 'PERÍODO',
                      value: profile.period.isEmpty
                          ? 'Não informado'
                          : profile.period,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Progresso do período',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                  Text(
                    '$progressPercent%',
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ProgressLine(value: progress),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Seção Para hoje -> Confirmação diária
        Text('Para hoje', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        SurfaceCard(
          color: paleBlue,
          borderSideColor: paleBlueBorder,
          borderRadius: 20,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'CONFIRMAÇÃO DIÁRIA',
                    style: TextStyle(
                      color: blue,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .6,
                    ),
                  ),
                  Text(
                    nowTimeLabel,
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Assistiu às aulas hoje?',
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 19,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _AnswerButton(
                      label: 'Sim, assisti',
                      filled: attendedToday != false,
                      selected: attendedToday == true,
                      onPressed: () => _setAttendance(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AnswerButton(
                      label: 'Não hoje',
                      filled: false,
                      selected: attendedToday == false,
                      onPressed: () => _setAttendance(false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        if (upcomingEvents.isNotEmpty) ...[
          Text(
            'Próximos compromissos',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          for (final event in upcomingEvents) ...[
            Builder(
              builder: (_) {
                final accent = subjectColorAt(event.colorIndex);
                final isTodayEvent = event.dateKey == todayKey;
                final dayLabel = isTodayEvent
                    ? 'Hoje'
                    : formatShortDayMonth(event.date);
                return SurfaceCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _toggleAgendaEvent(event),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            event.completed
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: event.completed ? green : accent,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: TextStyle(
                                color: event.completed ? muted : ink,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                decoration: event.completed
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$dayLabel · ${event.time} · ${event.reminderLabel}',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      PillBadge(
                        label: event.category,
                        backgroundColor: accent.withValues(alpha: 0.12),
                        textColor: accent,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
        ],

        // Seção Tarefas fixas
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Tarefas fixas',
                style: Theme.of(context).textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () async {
                await pushScreen<void>(context, const FixedTasksScreen());
                await _loadData();
                widget.onDataChanged();
              },
              style: TextButton.styleFrom(
                foregroundColor: blue,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: const Text(
                'Gerenciar',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (sortedTasks.isEmpty)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                await pushScreen<void>(context, const FixedTasksScreen());
                await _loadData();
                widget.onDataChanged();
              },
              child: SurfaceCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: paleBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add, color: blue, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Crie sua primeira tarefa fixa',
                            style: TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Ex.: pegar carona com o Mikael todos os dias',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: muted),
                  ],
                ),
              ),
            ),
          )
        else
          for (final task in sortedTasks) ...[
            _FixedTaskPromptCard(
              task: task,
              todayKey: todayKey,
              monthCount: task.completedCountInMonth(now.year, now.month),
              onAnswer: (done) => _answerFixedTask(task, done),
            ),
            const SizedBox(height: 10),
          ],

        const SizedBox(height: 18),

        // Cabeçalho Disciplinas com atalho direto para adicionar mais
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Disciplinas',
                style: Theme.of(context).textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () async {
                await pushScreen<bool>(
                  context,
                  const SubjectsSetupScreen(isOnboarding: false),
                );
                await _loadData();
                widget.onDataChanged();
              },
              style: TextButton.styleFrom(
                foregroundColor: blue,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: const Text(
                '+ Adicionar',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Lista agrupada de disciplinas e horários (estilo Page 2, clicável para anotações)
        if (sortedSubjects.isEmpty)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                await pushScreen<bool>(
                  context,
                  const SubjectsSetupScreen(isOnboarding: false),
                );
                await _loadData();
                widget.onDataChanged();
              },
              child: SurfaceCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: paleBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: blue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cadastre suas disciplinas',
                            style: TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Toque em uma disciplina depois para fazer anotações',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: muted),
                  ],
                ),
              ),
            ),
          )
        else
          SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: List<Widget>.generate(sortedSubjects.length, (i) {
                final subject = sortedSubjects[i];
                final notesCount = noteCounts[subject.id] ?? 0;
                final isToday = subject.occursOnWeekday(todayWeekday);
                final subtitleParts = <String>[
                  isToday ? 'Aula hoje' : subject.daysLabel,
                  notesCount == 0
                      ? 'Toque para anotar'
                      : notesCount == 1
                          ? '1 anotação'
                          : '$notesCount anotações',
                ];

                return Column(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        await pushScreen<void>(
                          context,
                          SubjectNotesScreen(subject: subject),
                        );
                        await _loadData();
                        widget.onDataChanged();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 52,
                              child: Text(
                                subject.startTime,
                                style: const TextStyle(
                                  color: ink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              width: 4,
                              height: 40,
                              decoration: BoxDecoration(
                                color: subjectColorAt(subject.colorIndex),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subject.name,
                                    style: const TextStyle(
                                      color: ink,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitleParts.join(' · '),
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.edit_note_rounded,
                              size: 20,
                              color: notesCount > 0 ? blue : muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (i != sortedSubjects.length - 1)
                      const Divider(height: 1, color: borderColor),
                  ],
                );
              }),
            ),
          ),
      ],
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.label,
    required this.filled,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isPrimaryLook = filled || selected;
    final bgColor = filled
        ? blue
        : selected
            ? orange
            : Colors.white;
    final fgColor = isPrimaryLook ? Colors.white : ink;

    return SizedBox(
      height: 46,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: isPrimaryLook ? null : Border.all(color: borderColor),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: fgColor,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FixedTaskPromptCard extends StatelessWidget {
  const _FixedTaskPromptCard({
    required this.task,
    required this.todayKey,
    required this.monthCount,
    required this.onAnswer,
  });

  final FixedTask task;
  final String todayKey;
  final int monthCount;
  final ValueChanged<bool> onAnswer;

  @override
  Widget build(BuildContext context) {
    final status = task.statusForDate(todayKey);
    final taskColor = subjectColorAt(task.colorIndex);
    final timesText = monthCount == 1
        ? '1 vez neste mês'
        : '$monthCount vezes neste mês';

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: taskColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${task.time} · ${formatWeekdays(task.weekdays)}',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              PillBadge(label: timesText),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _AnswerButton(
                  label: 'Sim',
                  filled: status != FixedTaskStatus.missed,
                  selected: status == FixedTaskStatus.completed,
                  onPressed: () => onAnswer(true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AnswerButton(
                  label: 'Não',
                  filled: false,
                  selected: status == FixedTaskStatus.missed,
                  onPressed: () => onAnswer(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
