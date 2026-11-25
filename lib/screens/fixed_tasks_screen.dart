import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../models/app_models.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

enum _TaskFrequency {
  everyDay('Todos os dias'),
  weekdays('Segunda a sexta'),
  weekends('Fins de semana'),
  custom('Dias específicos');

  const _TaskFrequency(this.label);
  final String label;
}

Future<FixedTask?> showFixedTaskEditorSheet(
  BuildContext context, {
  FixedTask? existing,
}) async {
  final titleController = TextEditingController(text: existing?.title ?? '');
  var selectedTime = const TimeOfDay(hour: 20, minute: 0);
  if (existing != null) {
    final parts = existing.time.split(':');
    selectedTime = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 20,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }
  final selectedDays = <int>{
    ...(existing?.weekdays ?? const <int>[1, 2, 3, 4, 5, 6, 7]),
  };
  var selectedColorIndex = existing?.colorIndex ?? 0;

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: canvas,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final formattedTime =
              '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null
                        ? 'Nova tarefa fixa'
                        : 'Editar tarefa fixa',
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'No horário escolhido, uma notificação chegará no celular perguntando se você fez a tarefa.',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  AppField(
                    label: 'Nome da tarefa',
                    hintText: 'Ex.: Pegar carona com o Mikael',
                    controller: titleController,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Horário da notificação',
                    style: TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 7),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setSheetState(() => selectedTime = picked);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: ink,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: Text(
                      'Notificação às $formattedTime',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Dias da semana',
                    style: TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 7,
                    runSpacing: 6,
                    children: const <int>[1, 2, 3, 4, 5, 6, 7].map((day) {
                      final selected = selectedDays.contains(day);
                      return FilterChip(
                        selected: selected,
                        selectedColor: paleBlue,
                        checkmarkColor: blue,
                        label: Text(weekdayShortNames[day]!),
                        onSelected: (value) {
                          setSheetState(() {
                            if (value) {
                              selectedDays.add(day);
                            } else {
                              selectedDays.remove(day);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Cor',
                    style: TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ColorDotPicker(
                    selectedIndex: selectedColorIndex,
                    onSelect: (i) =>
                        setSheetState(() => selectedColorIndex = i),
                  ),
                  const SizedBox(height: 18),
                  PrimaryButton(
                    label: existing == null
                        ? '+ Adicionar tarefa fixa'
                        : 'Salvar alterações',
                    onPressed: () {
                      if (titleController.text.trim().isEmpty ||
                          selectedDays.isEmpty) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Informe o nome e pelo menos um dia da semana.',
                            ),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(sheetContext, true);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  final title = titleController.text.trim();
  titleController.dispose();

  if (result != true || title.isEmpty || selectedDays.isEmpty) return null;

  final sortedDays = selectedDays.toList()..sort();
  final timeString =
      '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

  if (existing != null) {
    return existing.copyWith(
      title: title,
      time: timeString,
      weekdays: sortedDays,
      colorIndex: selectedColorIndex,
    );
  }

  return FixedTask(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    title: title,
    time: timeString,
    weekdays: sortedDays,
    completedDates: const <String>[],
    missedDates: const <String>[],
    colorIndex: selectedColorIndex,
  );
}

class FixedTasksScreen extends StatefulWidget {
  const FixedTasksScreen({super.key});

  @override
  State<FixedTasksScreen> createState() => _FixedTasksScreenState();
}

class _FixedTasksScreenState extends State<FixedTasksScreen> {
  final TextEditingController _nameController = TextEditingController();
  _TaskFrequency _frequency = _TaskFrequency.everyDay;
  final Set<int> _customDays = <int>{1, 2, 3, 4, 5};
  TimeOfDay _selectedTime = const TimeOfDay(hour: 20, minute: 0);
  int _selectedColorIndex = 0;

  List<FixedTask> tasks = <FixedTask>[];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final loaded = await AppStorage.loadFixedTasks();
    if (!mounted) return;
    setState(() {
      tasks = loaded;
      loading = false;
    });
  }

  List<int> _resolvedWeekdays() {
    switch (_frequency) {
      case _TaskFrequency.everyDay:
        return <int>[1, 2, 3, 4, 5, 6, 7];
      case _TaskFrequency.weekdays:
        return <int>[1, 2, 3, 4, 5];
      case _TaskFrequency.weekends:
        return <int>[6, 7];
      case _TaskFrequency.custom:
        return _customDays.toList()..sort();
    }
  }

  Future<void> _createTaskFromForm() async {
    final title = _nameController.text.trim();
    final weekdays = _resolvedWeekdays();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite o nome da tarefa fixa.')),
      );
      return;
    }
    if (weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos um dia.')),
      );
      return;
    }

    final formattedTime =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
    final task = FixedTask(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      time: formattedTime,
      weekdays: weekdays,
      completedDates: const <String>[],
      missedDates: const <String>[],
      colorIndex: _selectedColorIndex,
    );

    final updated = <FixedTask>[...tasks, task];
    await AppStorage.saveFixedTasks(updated);
    await NotificationService.instance.scheduleFixedTask(task);
    if (!mounted) return;
    setState(() {
      tasks = updated;
      _nameController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Rotina "${task.title}" criada! Notificação agendada para $formattedTime.',
        ),
      ),
    );
  }

  Future<void> _answerToday(FixedTask task, bool done) async {
    final updated = await AppStorage.recordFixedTaskResponse(
      taskId: task.id,
      date: DateTime.now(),
      done: done,
    );
    if (!mounted) return;
    setState(() => tasks = updated);
  }

  Future<void> _removeTask(FixedTask task) async {
    final updated = tasks.where((item) => item.id != task.id).toList();
    await AppStorage.saveFixedTasks(updated);
    await NotificationService.instance.cancelFixedTask(task);
    if (!mounted) return;
    setState(() => tasks = updated);
  }

  Future<void> _sendTestNotification(FixedTask task) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notificações locais funcionam no celular (Android/iOS).',
          ),
        ),
      );
      return;
    }
    final sent =
        await NotificationService.instance.showTestQuestionNotification(task);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'Notificação de teste enviada para o celular!'
              : 'Permita notificações nas configurações do aparelho.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayKey = dateKey(now);
    final formattedTime =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

    return MobileFrame(
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              // Header estilo Page 6: "< Tarefas fixas" + subtítulo
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.chevron_left_rounded, size: 28),
                    color: ink,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tarefas fixas',
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 26,
                            letterSpacing: -0.6,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Rotinas que você quer acompanhar',
                          style: TextStyle(color: muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Card NOVA ROTINA (exato ao Page 6!)
              SurfaceCard(
                borderRadius: 22,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'NOVA ROTINA',
                      style: TextStyle(
                        color: blue,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'O que você quer lembrar e contar?',
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 18),
                    AppField(
                      label: 'Nome da tarefa',
                      hintText: 'Ex.: Pegar carona com o Mikael',
                      controller: _nameController,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Frequência',
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFD8DCE8)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<_TaskFrequency>(
                          value: _frequency,
                          isExpanded: true,
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: muted,
                          ),
                          style: const TextStyle(color: ink, fontSize: 15),
                          items: _TaskFrequency.values
                              .map(
                                (freq) => DropdownMenuItem<_TaskFrequency>(
                                  value: freq,
                                  child: Text(freq.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _frequency = value);
                            }
                          },
                        ),
                      ),
                    ),
                    if (_frequency == _TaskFrequency.custom) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 7,
                        runSpacing: 6,
                        children: const <int>[1, 2, 3, 4, 5, 6, 7].map((day) {
                          final selected = _customDays.contains(day);
                          return FilterChip(
                            selected: selected,
                            selectedColor: paleBlue,
                            checkmarkColor: blue,
                            label: Text(weekdayShortNames[day]!),
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  _customDays.add(day);
                                } else {
                                  _customDays.remove(day);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      'Horário da notificação no celular',
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime,
                        );
                        if (picked != null) {
                          setState(() => _selectedTime = picked);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: ink,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFD8DCE8)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(
                        Icons.notifications_active_outlined,
                        color: blue,
                        size: 19,
                      ),
                      label: Text(
                        'Notificação às $formattedTime',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Cor',
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ColorDotPicker(
                      selectedIndex: _selectedColorIndex,
                      onSelect: (i) =>
                          setState(() => _selectedColorIndex = i),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: '+ Adicionar tarefa fixa',
                      onPressed: _createTaskFromForm,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Seção Suas rotinas (exato ao Page 6!)
              const Text(
                'Suas rotinas',
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                ),
              ),
              const SizedBox(height: 12),
              if (loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (tasks.isEmpty)
                const SurfaceCard(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                  child: Column(
                    children: [
                      Text(
                        'Nenhuma tarefa fixa ainda',
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Cadastre uma rotina acima para começar a acompanhar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: muted, fontSize: 13),
                      ),
                    ],
                  ),
                )
              else
                for (final task in tasks) ...[
                  Builder(
                    builder: (_) {
                      final status = task.statusForDate(todayKey);
                      final monthCount =
                          task.completedCountInMonth(now.year, now.month);
                      final timesLabel = monthCount == 1
                          ? '1 vez no mês'
                          : '$monthCount vezes no mês';
                      final taskColor = subjectColorAt(task.colorIndex);

                      return SurfaceCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: taskColor,
                                    borderRadius: BorderRadius.circular(4),
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
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${task.time} · ${formatWeekdays(task.weekdays)}',
                                        style: const TextStyle(
                                          color: muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Testar notificação',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _sendTestNotification(task),
                                  icon: const Icon(
                                    Icons.notifications_active_outlined,
                                    color: orange,
                                    size: 20,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Excluir',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _removeTask(task),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: muted,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: PillBadge(label: timesLabel),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 44,
                                    child: FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            status == FixedTaskStatus.missed
                                                ? paleBlue
                                                : blue,
                                        foregroundColor:
                                            status == FixedTaskStatus.missed
                                                ? blue
                                                : Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: () => _answerToday(task, true),
                                      child: const Text(
                                        'Sim',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SizedBox(
                                    height: 44,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor:
                                            status == FixedTaskStatus.missed
                                                ? orange
                                                : Colors.white,
                                        foregroundColor:
                                            status == FixedTaskStatus.missed
                                                ? Colors.white
                                                : ink,
                                        side: BorderSide(
                                          color:
                                              status == FixedTaskStatus.missed
                                                  ? orange
                                                  : borderColor,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: () =>
                                          _answerToday(task, false),
                                      child: const Text(
                                        'Não',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorDotPicker extends StatelessWidget {
  const _ColorDotPicker({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    // Cores exatas do Page 6: azul, laranja, roxo (e vermelho)
    const palette = <Color>[blue, orange, purple];
    return Row(
      children: List<Widget>.generate(palette.length, (i) {
        final selected = selectedIndex == i;
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onSelect(i),
            child: Container(
              width: 36,
              height: 36,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? palette[i] : borderColor,
                  width: selected ? 2.2 : 1,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette[i],
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
