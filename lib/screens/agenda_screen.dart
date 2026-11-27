import 'package:material_ui/material_ui.dart';

import '../models/app_models.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'onboarding_screens.dart';
import 'settings_screen.dart';
import 'subject_notes_screen.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({
    super.key,
    required this.refreshTick,
    required this.onDataChanged,
  });

  final int refreshTick;
  final VoidCallback onDataChanged;

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  late DateTime displayedMonth;
  late DateTime selectedDate;
  List<SubjectItem> subjects = <SubjectItem>[];
  Map<String, int> noteCounts = <String, int>{};
  List<FixedTask> fixedTasks = <FixedTask>[];
  List<AgendaEvent> agendaEvents = <AgendaEvent>[];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    displayedMonth = DateTime(now.year, now.month);
    selectedDate = DateTime(now.year, now.month, now.day);
    _loadData();
  }

  @override
  void didUpdateWidget(covariant AgendaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final loadedSubjects = await AppStorage.loadSubjects();
    final counts = await AppStorage.loadSubjectNoteCounts(loadedSubjects);
    final loadedTasks = await AppStorage.loadFixedTasks();
    final loadedEvents = await AppStorage.loadAgendaEvents();
    if (!mounted) return;
    setState(() {
      subjects = loadedSubjects;
      noteCounts = counts;
      fixedTasks = loadedTasks;
      agendaEvents = loadedEvents;
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      displayedMonth = DateTime(
        displayedMonth.year,
        displayedMonth.month + delta,
      );
      selectedDate = DateTime(displayedMonth.year, displayedMonth.month, 1);
    });
  }

  Future<void> _toggleEventCompleted(AgendaEvent event) async {
    final nextDone = !event.completed;
    final updatedEvent = event.copyWith(completed: nextDone);
    final updatedList = agendaEvents
        .map((item) => item.id == event.id ? updatedEvent : item)
        .toList();
    await AppStorage.saveAgendaEvents(updatedList);
    if (nextDone) {
      await NotificationService.instance.cancelAgendaEvent(event.id);
    } else {
      await NotificationService.instance.scheduleAgendaEvent(updatedEvent);
    }
    if (!mounted) return;
    setState(() => agendaEvents = updatedList);
    widget.onDataChanged();
  }

  Future<void> _deleteEvent(AgendaEvent event) async {
    final updatedList =
        agendaEvents.where((item) => item.id != event.id).toList();
    await AppStorage.saveAgendaEvents(updatedList);
    await NotificationService.instance.cancelAgendaEvent(event.id);
    if (!mounted) return;
    setState(() => agendaEvents = updatedList);
    widget.onDataChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Compromisso "${event.title}" removido.')),
    );
  }

  Future<void> _markFixedTaskCompleted(FixedTask task) async {
    final responseDate = selectedDate;
    final updated = await AppStorage.recordFixedTaskResponse(
      taskId: task.id,
      date: responseDate,
      done: true,
    );
    if (!mounted) return;
    setState(() => fixedTasks = updated);
    widget.onDataChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${task.title}: marcada como feita em ${formatShortDayMonth(responseDate)}.',
        ),
      ),
    );
  }

  Future<void> _openEventSheet({
    required DateTime initialDate,
    AgendaEvent? existing,
  }) async {
    final savedEvent = await showModalBottomSheet<AgendaEvent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AgendaEventSheet(
        initialDate: initialDate,
        existing: existing,
      ),
    );

    if (savedEvent == null) return;

    final updatedList = List<AgendaEvent>.from(agendaEvents);
    final idx = updatedList.indexWhere((item) => item.id == savedEvent.id);
    if (idx >= 0) {
      updatedList[idx] = savedEvent;
    } else {
      updatedList.add(savedEvent);
    }
    updatedList.sort((a, b) {
      final byDate = a.dateKey.compareTo(b.dateKey);
      if (byDate != 0) return byDate;
      return a.time.compareTo(b.time);
    });

    await AppStorage.saveAgendaEvents(updatedList);
    final scheduledAt =
        await NotificationService.instance.scheduleAgendaEvent(savedEvent);

    if (!mounted) return;
    setState(() {
      agendaEvents = updatedList;
      selectedDate = savedEvent.date;
      displayedMonth = DateTime(savedEvent.date.year, savedEvent.date.month);
    });
    widget.onDataChanged();

    final feedback = savedEvent.reminderMinutesBefore == null
        ? 'Compromisso salvo na agenda.'
        : scheduledAt != null
            ? 'Compromisso salvo! Aviso agendado para ${formatDateTimePt(scheduledAt)}.'
            : 'Compromisso salvo (${savedEvent.reminderLabel}).';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(feedback)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const dayHeaders = <String>['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
    final firstOfMonth = DateTime(displayedMonth.year, displayedMonth.month, 1);
    final startOffset = firstOfMonth.weekday % 7;
    final daysInMonth =
        DateTime(displayedMonth.year, displayedMonth.month + 1, 0).day;
    final totalCells = ((startOffset + daysInMonth + 6) ~/ 7) * 7;
    final now = DateTime.now();

    final selectedKey = dateKey(selectedDate);
    final dayEvents = agendaEvents
        .where((e) => e.dateKey == selectedKey)
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    final daySubjects = subjects
        .where((s) => s.occursOnWeekday(selectedDate.weekday))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final dayTasks = fixedTasks
        .where((t) => t.isScheduledForWeekday(selectedDate.weekday))
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    final summaryParts = <String>[
      if (dayEvents.isNotEmpty)
        '${dayEvents.length} ${dayEvents.length == 1 ? 'compromisso' : 'compromissos'}',
      '${daySubjects.length} ${daySubjects.length == 1 ? 'aula' : 'aulas'}',
      if (dayTasks.isNotEmpty)
        '${dayTasks.length} ${dayTasks.length == 1 ? 'tarefa fixa' : 'tarefas fixas'}',
    ];

    final eventDateKeys = agendaEvents.map((e) => e.dateKey).toSet();
    final today = DateTime(now.year, now.month, now.day);
    final isPastDate = selectedDate.isBefore(today);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        // Header: Mês e ano + navegação + engrenagem
        Row(
          children: [
            Expanded(
              child: Text(
                '${monthNamesPt[displayedMonth.month - 1]} ${displayedMonth.year}',
                style: Theme.of(context).textTheme.headlineLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Mês anterior',
              visualDensity: VisualDensity.compact,
              onPressed: () => _changeMonth(-1),
              icon: const Icon(Icons.chevron_left_rounded, color: muted),
            ),
            IconButton(
              tooltip: 'Próximo mês',
              visualDensity: VisualDensity.compact,
              onPressed: () => _changeMonth(1),
              icon: const Icon(Icons.chevron_right_rounded, color: muted),
            ),
            const SizedBox(width: 4),
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
        const SizedBox(height: 18),

        // Calendário mensal
        SurfaceCard(
          borderRadius: 22,
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
          child: Column(
            children: [
              Row(
                children: dayHeaders
                    .map(
                      (day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: const TextStyle(
                              color: muted,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: totalCells,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 6,
                ),
                itemBuilder: (_, i) {
                  final dayNumber = i - startOffset + 1;
                  if (dayNumber < 1 || dayNumber > daysInMonth) {
                    return const SizedBox.shrink();
                  }
                  final cellDate = DateTime(
                    displayedMonth.year,
                    displayedMonth.month,
                    dayNumber,
                  );
                  final cellKey = dateKey(cellDate);
                  final isSelected = cellDate.year == selectedDate.year &&
                      cellDate.month == selectedDate.month &&
                      cellDate.day == selectedDate.day;
                  final isToday = cellDate.year == now.year &&
                      cellDate.month == now.month &&
                      cellDate.day == now.day;
                  final hasClass =
                      subjects.any((s) => s.occursOnWeekday(cellDate.weekday));
                  final hasEvent = eventDateKeys.contains(cellKey);

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (isSelected) {
                        _openEventSheet(initialDate: cellDate);
                      } else {
                        setState(() => selectedDate = cellDate);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? blue
                            : isToday
                                ? paleBlue
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNumber',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : isToday
                                      ? blue
                                      : ink,
                              fontWeight: isSelected || isToday
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          if (hasClass || hasEvent)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (hasClass)
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white70
                                            : blue,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  if (hasClass && hasEvent)
                                    const SizedBox(width: 3),
                                  if (hasEvent)
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? brandTeal
                                            : orange,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              const Text(
                'Toque em uma data para selecionar ou toque novamente para adicionar um compromisso.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Cabeçalho do dia selecionado + botão direto "+ Adicionar"
        Row(
          children: [
            Expanded(
              child: RichText(
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(fontSize: 15, color: ink),
                  children: [
                    TextSpan(
                      text:
                          'Dia ${selectedDate.day} de ${monthShortNamesPt[selectedDate.month - 1]}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(
                      text: ' · ${summaryParts.join(' · ')}',
                      style: const TextStyle(color: muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => _openEventSheet(initialDate: selectedDate),
              style: FilledButton.styleFrom(
                backgroundColor: blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text(
                'Adicionar',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (dayEvents.isEmpty && daySubjects.isEmpty && dayTasks.isEmpty)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _openEventSheet(initialDate: selectedDate),
              child: SurfaceCard(
                borderRadius: 18,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: paleBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.event_note_rounded,
                        color: blue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nada agendado para ${formatShortDayMonth(selectedDate)}',
                            style: const TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Toque aqui para adicionar uma tarefa, prova ou lembrete com notificação.',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.add_circle_outline_rounded, color: blue),
                  ],
                ),
              ),
            ),
          )
        else ...[
          // Compromissos específicos desta data
          for (final event in dayEvents) ...[
            _AgendaEventCard(
              event: event,
              onToggle: () => _toggleEventCompleted(event),
              onEdit: () => _openEventSheet(
                initialDate: event.date,
                existing: event,
              ),
              onDelete: () => _deleteEvent(event),
            ),
            const SizedBox(height: 10),
          ],
          // Aulas do dia da semana
          for (final subject in daySubjects) ...[
            SubjectTile(
              name: subject.name,
              days: 'Aula',
              time: subject.startTime,
              color: subjectColorAt(subject.colorIndex),
              notesCount: noteCounts[subject.id] ?? 0,
              onTap: () async {
                await pushScreen<void>(
                  context,
                  SubjectNotesScreen(subject: subject),
                );
                await _loadData();
                widget.onDataChanged();
              },
            ),
            const SizedBox(height: 10),
          ],
          // Tarefas fixas do dia da semana
          for (final task in dayTasks) ...[
            Builder(
              builder: (_) {
                final status = task.statusForDate(selectedKey);
                final label = status == FixedTaskStatus.completed
                    ? 'Feita'
                    : status == FixedTaskStatus.missed
                        ? 'Não feita'
                        : isPastDate
                            ? 'Sem registro'
                            : 'Rotina';
                final bg = status == FixedTaskStatus.completed
                    ? paleBlue
                    : status == FixedTaskStatus.missed
                        ? paleRed
                        : paleOrange;
                final fg = status == FixedTaskStatus.completed
                    ? blue
                    : status == FixedTaskStatus.missed
                        ? red
                        : orange;

                return SurfaceCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 40,
                            decoration: BoxDecoration(
                              color: subjectColorAt(task.colorIndex),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  style: const TextStyle(
                                    color: ink,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tarefa fixa · ${task.time}',
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PillBadge(
                            label: label,
                            backgroundColor: bg,
                            textColor: fg,
                          ),
                        ],
                      ),
                      if (isPastDate && status != FixedTaskStatus.completed)
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: () => _markFixedTaskCompleted(task),
                            style: FilledButton.styleFrom(
                              backgroundColor: blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: const Text(
                              'Marcar feita',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ],

        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Todas as disciplinas',
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
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
              style: TextButton.styleFrom(foregroundColor: blue),
              child: const Text(
                '+ Adicionar',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (subjects.isEmpty)
          const SurfaceCard(
            borderRadius: 18,
            child: Text(
              'Nenhuma disciplina cadastrada ainda.',
              style: TextStyle(color: muted, fontSize: 13),
            ),
          )
        else
          for (final subject in subjects) ...[
            SubjectTile(
              name: subject.name,
              days: subject.daysLabel,
              time: subject.timeLabel,
              color: subjectColorAt(subject.colorIndex),
              notesCount: noteCounts[subject.id] ?? 0,
              onTap: () async {
                await pushScreen<void>(
                  context,
                  SubjectNotesScreen(subject: subject),
                );
                await _loadData();
                widget.onDataChanged();
              },
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _AgendaEventCard extends StatelessWidget {
  const _AgendaEventCard({
    required this.event,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final AgendaEvent event;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = subjectColorAt(event.colorIndex);
    final hasReminder = event.reminderMinutesBefore != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onEdit,
        child: SurfaceCard(
          borderRadius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onToggle,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: TextStyle(
                              color: event.completed ? muted : ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              decoration: event.completed
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        PillBadge(
                          label: event.category,
                          backgroundColor: accent.withValues(alpha: 0.12),
                          textColor: accent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          event.time,
                          style: const TextStyle(
                            color: muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          hasReminder
                              ? Icons.notifications_active_outlined
                              : Icons.notifications_off_outlined,
                          size: 13,
                          color: hasReminder ? blue : muted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.reminderLabel,
                            style: TextStyle(
                              color: hasReminder ? blue : muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (event.notes.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        event.notes.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Excluir compromisso',
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: muted,
                  size: 19,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgendaEventSheet extends StatefulWidget {
  const _AgendaEventSheet({
    required this.initialDate,
    this.existing,
  });

  final DateTime initialDate;
  final AgendaEvent? existing;

  @override
  State<_AgendaEventSheet> createState() => _AgendaEventSheetState();
}

class _AgendaEventSheetState extends State<_AgendaEventSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late DateTime _pickedDate;
  late TimeOfDay _pickedTime;
  late String _category;
  int? _reminderMinutes;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _pickedDate = existing?.date ?? widget.initialDate;
    _pickedTime = existing != null
        ? _parseTimeOfDay(existing.time)
        : const TimeOfDay(hour: 9, minute: 0);
    _category = existing?.category ?? agendaEventCategories.first;
    _reminderMinutes = existing != null ? existing.reminderMinutesBefore : 30;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatTimeOfDay(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  TimeOfDay _parseTimeOfDay(String raw) {
    final parts = raw.split(':');
    final h = int.tryParse(parts.first) ?? 9;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite o que você precisa fazer nesta data.'),
        ),
      );
      return;
    }
    final event = AgendaEvent(
      id: widget.existing?.id ??
          'event_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      dateKey: dateKey(_pickedDate),
      time: _formatTimeOfDay(_pickedTime),
      notes: _notesController.text.trim(),
      category: _category,
      colorIndex: colorIndexForAgendaCategory(_category),
      reminderMinutesBefore: _reminderMinutes,
      completed: widget.existing?.completed ?? false,
    );
    Navigator.pop(context, event);
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTimeOfDay(_pickedTime);
    final eventDateTime = DateTime(
      _pickedDate.year,
      _pickedDate.month,
      _pickedDate.day,
      _pickedTime.hour,
      _pickedTime.minute,
    );
    final alertDateTime = _reminderMinutes == null
        ? null
        : eventDateTime.subtract(Duration(minutes: _reminderMinutes!));

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.existing == null
                  ? 'Novo compromisso'
                  : 'Editar compromisso',
              style: const TextStyle(
                color: ink,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Agende o que você precisa fazer em uma data específica com aviso no celular.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            AppField(
              label: 'O que você precisa fazer?',
              hintText: 'Ex.: Prova de Cálculo, Entregar trabalho...',
              controller: _titleController,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Data',
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: _pickedDate,
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2035),
                          );
                          if (selected != null) {
                            setState(() => _pickedDate = selected);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFD8DCE8),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 16,
                                color: blue,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${_pickedDate.day.toString().padLeft(2, '0')}/${_pickedDate.month.toString().padLeft(2, '0')}/${_pickedDate.year}',
                                  style: const TextStyle(
                                    color: ink,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Horário',
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          final selected = await showTimePicker(
                            context: context,
                            initialTime: _pickedTime,
                          );
                          if (selected != null) {
                            setState(() => _pickedTime = selected);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFD8DCE8),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 16,
                                color: blue,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                timeStr,
                                style: const TextStyle(
                                  color: ink,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Categoria',
              style: TextStyle(
                color: ink,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: agendaEventCategories.map((cat) {
                final selected = _category == cat;
                final catColor =
                    subjectColorAt(colorIndexForAgendaCategory(cat));
                return ChoiceChip(
                  label: Text(cat),
                  selected: selected,
                  selectedColor: catColor,
                  backgroundColor: canvas,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: selected ? catColor : borderColor,
                    ),
                  ),
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _category = cat),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            const Text(
              'Quando receber notificação?',
              style: TextStyle(
                color: ink,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: agendaReminderOptions.map((option) {
                final selected = _reminderMinutes == option.minutesBefore;
                return ChoiceChip(
                  label: Text(option.label),
                  selected: selected,
                  selectedColor: blue,
                  backgroundColor: canvas,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: selected ? blue : borderColor,
                    ),
                  ),
                  showCheckmark: false,
                  onSelected: (_) => setState(
                    () => _reminderMinutes = option.minutesBefore,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: alertDateTime == null ? canvas : paleBlue,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: alertDateTime == null ? borderColor : paleBlueBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    alertDateTime == null
                        ? Icons.notifications_off_outlined
                        : Icons.notifications_active_outlined,
                    size: 18,
                    color: alertDateTime == null ? muted : blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alertDateTime == null
                          ? 'Sem notificação no celular para este compromisso.'
                          : 'Notificação agendada para ${formatDateTimePt(alertDateTime)}',
                      style: TextStyle(
                        color: alertDateTime == null ? muted : blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppField(
              label: 'Detalhes (opcional)',
              hintText: 'Sala, conteúdo, link ou observação...',
              controller: _notesController,
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: widget.existing == null
                  ? 'Salvar compromisso'
                  : 'Salvar alterações',
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
