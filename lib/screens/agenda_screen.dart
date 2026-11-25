import 'package:material_ui/material_ui.dart';

import '../models/app_models.dart';
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
    if (!mounted) return;
    setState(() {
      subjects = loadedSubjects;
      noteCounts = counts;
      fixedTasks = loadedTasks;
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

  @override
  Widget build(BuildContext context) {
    const dayHeaders = <String>['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
    final firstOfMonth = DateTime(displayedMonth.year, displayedMonth.month, 1);
    final startOffset = firstOfMonth.weekday % 7;
    final daysInMonth =
        DateTime(displayedMonth.year, displayedMonth.month + 1, 0).day;
    final totalCells = ((startOffset + daysInMonth + 6) ~/ 7) * 7;
    final now = DateTime.now();

    final daySubjects = subjects
        .where((s) => s.occursOnWeekday(selectedDate.weekday))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final dayTasks = fixedTasks
        .where((t) => t.isScheduledForWeekday(selectedDate.weekday))
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    final selectedKey = dateKey(selectedDate);
    final summaryParts = <String>[
      '${daySubjects.length} ${daySubjects.length == 1 ? 'aula' : 'aulas'}',
      if (dayTasks.isNotEmpty)
        '${dayTasks.length} ${dayTasks.length == 1 ? 'tarefa fixa' : 'tarefas fixas'}',
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        // Header estilo Page 3: "Novembro 2026" grande + engrenagem
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

        // Calendário mensal (estilo Page 3)
        SurfaceCard(
          borderRadius: 22,
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
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
                  final isSelected = cellDate.year == selectedDate.year &&
                      cellDate.month == selectedDate.month &&
                      cellDate.day == selectedDate.day;
                  final isToday = cellDate.year == now.year &&
                      cellDate.month == now.month &&
                      cellDate.day == now.day;
                  final hasClass =
                      subjects.any((s) => s.occursOnWeekday(cellDate.weekday));

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => selectedDate = cellDate),
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
                          if (hasClass && !isSelected)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Linha "Dia 10 · 2 aulas"
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 15, color: ink),
            children: [
              TextSpan(
                text: 'Dia ${selectedDate.day}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(
                text: '  ·  ${summaryParts.join(' e ')}',
                style: const TextStyle(color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (daySubjects.isEmpty && dayTasks.isEmpty)
          const SurfaceCard(
            borderRadius: 18,
            child: Text(
              'Nenhuma aula ou tarefa fixa agendada para este dia da semana.',
              style: TextStyle(color: muted, fontSize: 13),
            ),
          )
        else ...[
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
          for (final task in dayTasks) ...[
            Builder(
              builder: (_) {
                final status = task.statusForDate(selectedKey);
                final label = status == FixedTaskStatus.completed
                    ? 'Feita'
                    : status == FixedTaskStatus.missed
                        ? 'Não feita'
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
                  child: Row(
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
                              style:
                                  const TextStyle(color: muted, fontSize: 12),
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
