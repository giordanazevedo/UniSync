import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/app_models.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'fixed_tasks_screen.dart';
import 'settings_screen.dart';
import 'subject_notes_screen.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({
    super.key,
    required this.refreshTick,
    required this.onDataChanged,
  });

  final int refreshTick;
  final VoidCallback onDataChanged;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  late DateTime selectedMonth;
  List<FixedTask> fixedTasks = <FixedTask>[];
  List<SubjectItem> subjects = <SubjectItem>[];
  Map<String, int> noteCounts = <String, int>{};
  Map<String, bool> attendanceRecords = <String, bool>{};
  List<FinanceEntry> financeEntries = <FinanceEntry>[];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedMonth = DateTime(now.year, now.month);
    _loadData();
  }

  @override
  void didUpdateWidget(covariant SummaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final loadedTasks = await AppStorage.loadFixedTasks();
    final loadedSubjects = await AppStorage.loadSubjects();
    final loadedCounts = await AppStorage.loadSubjectNoteCounts(loadedSubjects);
    final loadedAttendance = await AppStorage.loadAttendanceMap();
    final loadedFinance = await AppStorage.loadFinanceEntries();

    if (!mounted) return;
    setState(() {
      fixedTasks = loadedTasks;
      subjects = loadedSubjects;
      noteCounts = loadedCounts;
      attendanceRecords = loadedAttendance;
      financeEntries = loadedFinance;
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      selectedMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month + delta,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final year = selectedMonth.year;
    final month = selectedMonth.month;
    final monthName = monthNamesPt[month - 1];
    final prefix = monthKey(year, month);

    // Frequência nas aulas no mês + por semana (S1..S4)
    final monthAttendanceEntries = attendanceRecords.entries
        .where((e) => e.key.startsWith(prefix))
        .toList();
    final attendedDays = monthAttendanceEntries.where((e) => e.value).length;
    final absentDays = monthAttendanceEntries.where((e) => !e.value).length;
    final totalClassDays = attendedDays + absentDays;
    final attendanceRate =
        totalClassDays == 0 ? 0.0 : attendedDays / totalClassDays;
    final attendancePercent = (attendanceRate * 100).round();

    final weekPresent = List<int>.filled(4, 0);
    final weekTotal = List<int>.filled(4, 0);
    for (final entry in monthAttendanceEntries) {
      final parts = entry.key.split('-');
      final day = parts.length == 3 ? (int.tryParse(parts[2]) ?? 1) : 1;
      final weekIdx = ((day - 1) ~/ 7).clamp(0, 3);
      weekTotal[weekIdx]++;
      if (entry.value) weekPresent[weekIdx]++;
    }

    // Gastos por categoria no mês
    final monthExpenses = financeEntries
        .where(
          (e) => !e.isIncome && e.date.year == year && e.date.month == month,
        )
        .toList();
    final totalExpenses = monthExpenses.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    final expensesByCategory = <String, double>{};
    for (final entry in monthExpenses) {
      expensesByCategory[entry.category] =
          (expensesByCategory[entry.category] ?? 0) + entry.amount;
    }
    final sortedCategories = expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalTaskDone = fixedTasks.fold<int>(
      0,
      (sum, task) => sum + task.completedCountInMonth(year, month),
    );
    final totalNotes =
        noteCounts.values.fold<int>(0, (sum, count) => sum + count);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        // Header estilo Page 7: "Resumo" + pill "Novembro" + engrenagem
        Row(
          children: [
            Expanded(
              child: Text(
                'Resumo',
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
            PillBadge(label: monthName),
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
        const SizedBox(height: 4),
        Text(
          'Seu desempenho em ${monthName.toLowerCase()}',
          style: const TextStyle(color: muted, fontSize: 13),
        ),
        const SizedBox(height: 18),

        // Hero card azul escuro -> azul principal (exato ao Page 7!)
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[darkBlue, Color(0xFF3955B2)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x38223A80),
                blurRadius: 26,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 112,
                      height: 112,
                      child: CircularProgressIndicator(
                        value: totalClassDays == 0 ? 0 : attendanceRate,
                        strokeWidth: 10,
                        strokeCap: StrokeCap.round,
                        color: Colors.white,
                        backgroundColor: const Color(0x38FFFFFF),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$attendancePercent%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 27,
                          ),
                        ),
                        const Text(
                          'presença',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FREQUÊNCIA GERAL',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                        letterSpacing: .8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      totalClassDays == 0
                          ? 'Sem registros ainda'
                          : attendancePercent >= 75
                              ? 'Você está indo bem'
                              : 'Atenção às faltas',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 19,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      totalClassDays == 0
                          ? 'Confirme sua presença na tela Início para acompanhar.'
                          : '$attendedDays de $totalClassDays dias com presença confirmada.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x28FFFFFF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        totalTaskDone == 1
                            ? '1 tarefa fixa feita no mês'
                            : '$totalTaskDone tarefas fixas feitas no mês',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Dois indicadores lado a lado (exato ao Page 7!)
        Row(
          children: [
            Expanded(
              child: _SummaryMetricCard(
                icon: Icons.calendar_today_outlined,
                label: 'Dias letivos',
                value: '$totalClassDays',
                iconColor: blue,
                iconBg: paleBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryMetricCard(
                icon: Icons.priority_high_rounded,
                label: 'Faltas no mês',
                value: '$absentDays',
                iconColor: orange,
                iconBg: paleOrange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Card Ritmo de frequência (S1..S4, exato ao Page 7!)
        SurfaceCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ritmo de frequência',
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Presença por semana',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  PillBadge(label: 'Média $attendancePercent%'),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 148,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List<Widget>.generate(4, (i) {
                    final total = weekTotal[i];
                    final present = weekPresent[i];
                    final ratio = total == 0 ? 0.0 : present / total;
                    final barColor =
                        (total > 0 && ratio < 0.7) ? orange : blue;
                    return _WeekCapsuleBar(
                      label: 'S${i + 1}',
                      amount: '$present/$total',
                      value: ratio,
                      color: barColor,
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Card Hábitos e tarefas fixas (design refinado)
        SurfaceCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hábitos e tarefas fixas',
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Contagem mensal das suas rotinas',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  PillBadge(label: '${monthName.toLowerCase()} de $year'),
                ],
              ),
              const SizedBox(height: 16),
              if (fixedTasks.isEmpty)
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    await pushScreen<void>(context, const FixedTasksScreen());
                    await _loadData();
                    widget.onDataChanged();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: canvas,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
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
                                'Adicionar tarefa fixa',
                                style: TextStyle(
                                  color: ink,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Acompanhe uma rotina e veja o total do mês aqui.',
                                style: TextStyle(color: muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: muted),
                      ],
                    ),
                  ),
                )
              else ...[
                for (var i = 0; i < fixedTasks.length; i++) ...[
                  Builder(
                    builder: (_) {
                      final task = fixedTasks[i];
                      final doneCount = task.completedCountInMonth(year, month);
                      final missedCount = task.missedCountInMonth(year, month);
                      final plannedInMonth =
                          task.scheduledOccurrencesInMonth(year, month);
                      final progress = plannedInMonth == 0
                          ? 0.0
                          : (doneCount / plannedInMonth).clamp(0.0, 1.0);
                      final percent = (progress * 100).round();
                      final countLabel = doneCount == 1
                          ? '1 vez no mês'
                          : '$doneCount vezes no mês';
                      final color = subjectColorAt(task.colorIndex);

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: canvas,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: color.withAlpha(28),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.repeat_rounded,
                                    color: color,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task.title,
                                        style: const TextStyle(
                                          color: ink,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${task.time} · ${formatWeekdays(task.weekdays)}',
                                        style: const TextStyle(
                                          color: muted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                PillBadge(
                                  label: countLabel,
                                  backgroundColor: color.withAlpha(26),
                                  textColor: color,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: color.withAlpha(26),
                                color: color,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    missedCount == 0
                                        ? '$doneCount de $plannedInMonth dias no mês'
                                        : '$doneCount de $plannedInMonth dias · $missedCount não',
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$percent%',
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (i != fixedTasks.length - 1) const SizedBox(height: 10),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  height: 44,
                  child: FilledButton.tonalIcon(
                    onPressed: () async {
                      await pushScreen<void>(
                        context,
                        const FixedTasksScreen(),
                      );
                      await _loadData();
                      widget.onDataChanged();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: paleBlue,
                      foregroundColor: blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 19),
                    label: const Text(
                      'Gerenciar tarefas fixas',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Card Para onde foi sua grana com gráfico Donut (exato ao Page 8!)
        SurfaceCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Para onde foi sua grana',
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Gastos por categoria',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatCurrencyBr(totalExpenses),
                    style: const TextStyle(
                      color: blue,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (sortedCategories.isEmpty)
                const Text(
                  'Nenhum gasto registrado neste mês.',
                  style: TextStyle(color: muted, fontSize: 13),
                )
              else
                Row(
                  children: [
                    SizedBox(
                      width: 124,
                      height: 124,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(124, 124),
                            painter: _DonutChartPainter(
                              slices: List<_DonutSlice>.generate(
                                sortedCategories.length,
                                (i) => _DonutSlice(
                                  fraction: totalExpenses == 0
                                      ? 0
                                      : sortedCategories[i].value /
                                          totalExpenses,
                                  color: subjectColorAt(i),
                                ),
                              ),
                            ),
                          ),
                          const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Total',
                                style: TextStyle(color: muted, fontSize: 11),
                              ),
                              Text(
                                '100%',
                                style: TextStyle(
                                  color: ink,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        children: List<Widget>.generate(
                          sortedCategories.length,
                          (i) {
                            final item = sortedCategories[i];
                            final pct = totalExpenses == 0
                                ? 0
                                : ((item.value / totalExpenses) * 100).round();
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom:
                                    i == sortedCategories.length - 1 ? 0 : 12,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(
                                      color: subjectColorAt(i),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.key,
                                          style: const TextStyle(
                                            color: ink,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          formatCurrencyBr(item.value),
                                          style: const TextStyle(
                                            color: muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '$pct%',
                                    style: const TextStyle(
                                      color: muted,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Anotações das disciplinas
        SurfaceCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Anotações das disciplinas',
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PillBadge(
                    label: totalNotes == 1
                        ? '1 anotação'
                        : '$totalNotes anotações',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (subjects.isEmpty)
                const Text(
                  'Nenhuma disciplina cadastrada ainda.',
                  style: TextStyle(color: muted, fontSize: 13),
                )
              else
                for (var i = 0; i < subjects.length; i++) ...[
                  Builder(
                    builder: (_) {
                      final subject = subjects[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () async {
                          await pushScreen<void>(
                            context,
                            SubjectNotesScreen(subject: subject),
                          );
                          await _loadData();
                          widget.onDataChanged();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: subjectColorAt(subject.colorIndex),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  subject.name,
                                  style: const TextStyle(
                                    color: ink,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Text(
                                '${noteCounts[subject.id] ?? 0} nota(s)',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: muted,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  if (i != subjects.length - 1)
                    const Divider(height: 1, color: borderColor),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  const _SummaryMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    required this.iconBg,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final Color iconBg;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: muted, fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekCapsuleBar extends StatelessWidget {
  const _WeekCapsuleBar({
    required this.label,
    required this.amount,
    required this.value,
    required this.color,
  });

  final String label;
  final String amount;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      child: Column(
        children: [
          Text(
            amount,
            style: const TextStyle(
              color: muted,
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: 24,
              alignment: Alignment.bottomCenter,
              decoration: BoxDecoration(
                color: const Color(0xFFEEEFF5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: FractionallySizedBox(
                heightFactor: value.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[color, color.withAlpha(210)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: muted,
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutSlice {
  const _DonutSlice({required this.fraction, required this.color});

  final double fraction;
  final Color color;
}

class _DonutChartPainter extends CustomPainter {
  const _DonutChartPainter({required this.slices});

  final List<_DonutSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 18.0;
    final rect = const Offset(strokeWidth / 2, strokeWidth / 2) &
        Size(size.width - strokeWidth, size.height - strokeWidth);

    var startAngle = -math.pi / 2;
    for (final slice in slices) {
      if (slice.fraction <= 0) continue;
      final sweep = slice.fraction * 2 * math.pi;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
      oldDelegate.slices != slices;
}
