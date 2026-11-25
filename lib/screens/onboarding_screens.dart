import 'package:material_ui/material_ui.dart';

import '../models/app_models.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'app_shell.dart';
import 'fixed_tasks_screen.dart';
import 'subject_notes_screen.dart';

const String _otherCourseOption = 'Outro curso...';

const List<String> _courseOptions = <String>[
  'Administração',
  'Análise e Desenvolvimento de Sistemas',
  'Arquitetura e Urbanismo',
  'Biomedicina',
  'Ciência da Computação',
  'Ciências Contábeis',
  'Design',
  'Direito',
  'Educação Física',
  'Enfermagem',
  'Engenharia Civil',
  'Engenharia de Produção',
  'Engenharia de Software',
  'Engenharia Elétrica',
  'Engenharia Mecânica',
  'Farmácia',
  'Fisioterapia',
  'Medicina',
  'Medicina Veterinária',
  'Nutrição',
  'Odontologia',
  'Pedagogia',
  'Psicologia',
  'Sistemas de Informação',
  _otherCourseOption,
];

const List<String> _periodOptions = <String>[
  '1º período',
  '2º período',
  '3º período',
  '4º período',
  '5º período',
  '6º período',
  '7º período',
  '8º período',
  '9º período',
  '10º período',
  '11º período',
  '12º período',
  'Pós-graduação',
  'Mestrado / Doutorado',
];

const List<String> _shiftOptions = <String>[
  'Matutino',
  'Vespertino',
  'Noturno',
  'Integral',
  'EAD',
];

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, this.isEditing = false});

  final bool isEditing;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final nameController = TextEditingController();
  final customCourseController = TextEditingController();
  String? selectedCourse;
  String? selectedPeriod;
  String? selectedShift;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  Future<void> _loadExistingProfile() async {
    final profile = await AppStorage.loadProfile();
    if (!mounted) return;
    setState(() {
      if (profile.name.isNotEmpty) {
        nameController.text = profile.name;
      }
      if (profile.course.isNotEmpty) {
        if (_courseOptions.contains(profile.course) &&
            profile.course != _otherCourseOption) {
          selectedCourse = profile.course;
        } else {
          selectedCourse = _otherCourseOption;
          customCourseController.text = profile.course;
        }
      }
      if (profile.period.isNotEmpty) {
        final normalized = profile.period.replaceAll('semestre', 'período');
        if (_periodOptions.contains(normalized)) {
          selectedPeriod = normalized;
        }
      }
      if (profile.shift.isNotEmpty && _shiftOptions.contains(profile.shift)) {
        selectedShift = profile.shift;
      }
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    customCourseController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = nameController.text.trim();
    final course = selectedCourse == _otherCourseOption
        ? customCourseController.text.trim()
        : (selectedCourse ?? '').trim();
    final period = (selectedPeriod ?? '').trim();
    final shift = (selectedShift ?? '').trim();

    if (name.isEmpty || course.isEmpty || period.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe seu nome, escolha seu curso e o período.'),
        ),
      );
      return;
    }

    await AppStorage.saveProfile(
      UserProfile(name: name, course: course, period: period, shift: shift),
    );
    if (!mounted) return;

    if (widget.isEditing) {
      Navigator.pop(context, true);
    } else {
      await pushScreen<void>(
        context,
        const SubjectsSetupScreen(isOnboarding: true),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
        appBar: widget.isEditing
            ? AppBar(
                title: const Text(
                  'Editar perfil',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                backgroundColor: canvas,
                surfaceTintColor: canvas,
              )
            : null,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.isEditing) ...[
                  const StepHeader(step: 1, totalSteps: 3),
                  const SizedBox(height: 22),
                  const Row(
                    children: [
                      AppMark(),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: brandNavy,
                                  letterSpacing: -1,
                                  height: 1.05,
                                ),
                                children: [
                                  TextSpan(text: 'Uni'),
                                  TextSpan(
                                    text: 'Sync',
                                    style: TextStyle(color: brandIndigo),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Sua vida universitária em sintonia.',
                              style: TextStyle(
                                color: muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],
                Text(
                  widget.isEditing
                      ? 'Seus dados acadêmicos'
                      : 'Bem-vindo! Vamos começar',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Personalize o app informando seu nome e escolhendo seu curso, período e turno.',
                  style: TextStyle(color: muted, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 20),
                SurfaceCard(
                  borderRadius: 22,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'SEU PERFIL',
                        style: TextStyle(
                          color: blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(height: 14),
                      AppField(
                        label: 'Seu nome',
                        hintText: 'Ex.: Ana Souza',
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      AppDropdownField<String>(
                        label: 'Seu curso',
                        hintText: 'Selecione seu curso',
                        value: selectedCourse,
                        items: _courseOptions,
                        itemLabel: (course) => course,
                        onChanged: (value) {
                          setState(() => selectedCourse = value);
                        },
                      ),
                      if (selectedCourse == _otherCourseOption) ...[
                        const SizedBox(height: 12),
                        AppField(
                          label: 'Qual é o seu curso?',
                          hintText: 'Digite o nome do curso',
                          controller: customCourseController,
                        ),
                      ],
                      const SizedBox(height: 16),
                      AppDropdownField<String>(
                        label: 'Em qual período você está?',
                        hintText: 'Selecione o período atual',
                        value: selectedPeriod,
                        items: _periodOptions,
                        itemLabel: (period) => period,
                        onChanged: (value) {
                          setState(() => selectedPeriod = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      AppDropdownField<String>(
                        label: 'Turno das aulas (opcional)',
                        hintText: 'Selecione o turno',
                        value: selectedShift,
                        items: _shiftOptions,
                        itemLabel: (shift) => shift,
                        onChanged: (value) {
                          setState(() => selectedShift = value);
                        },
                      ),
                      const SizedBox(height: 22),
                      PrimaryButton(
                        label: widget.isEditing
                            ? 'Salvar dados'
                            : 'Continuar para disciplinas',
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SubjectsSetupScreen extends StatefulWidget {
  const SubjectsSetupScreen({super.key, this.isOnboarding = true});

  final bool isOnboarding;

  @override
  State<SubjectsSetupScreen> createState() => _SubjectsSetupScreenState();
}

class _SubjectsSetupScreenState extends State<SubjectsSetupScreen> {
  List<SubjectItem> subjects = <SubjectItem>[];
  Map<String, int> noteCounts = <String, int>{};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final loaded = await AppStorage.loadSubjects();
    final counts = await AppStorage.loadSubjectNoteCounts(loaded);
    if (!mounted) return;
    setState(() {
      subjects = loaded;
      noteCounts = counts;
      loading = false;
    });
  }

  TimeOfDay _parseTime(String value, TimeOfDay fallback) {
    final parts = value.split(':');
    if (parts.length < 2) return fallback;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return fallback;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Future<void> _openSubjectSheet({SubjectItem? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final selectedDays = <int>{...(existing?.weekdays ?? const <int>[1, 3])};
    var startTime = existing == null
        ? const TimeOfDay(hour: 8, minute: 0)
        : _parseTime(existing.startTime, const TimeOfDay(hour: 8, minute: 0));
    var endTime = existing == null
        ? const TimeOfDay(hour: 10, minute: 0)
        : _parseTime(existing.endTime, const TimeOfDay(hour: 10, minute: 0));
    var selectedColorIndex =
        existing?.colorIndex ?? (subjects.length % subjectColors.length);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: canvas,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                          ? 'Nova disciplina'
                          : 'Editar disciplina',
                      style: const TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppField(
                      label: 'Nome da disciplina',
                      hintText: 'Ex.: Cálculo II, Algoritmos, Anatomia',
                      controller: nameController,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Dias da semana',
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: const <int>[1, 2, 3, 4, 5, 6].map((day) {
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
                      'Horário da aula',
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: startTime,
                              );
                              if (picked != null) {
                                setSheetState(() => startTime = picked);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: ink,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              side: const BorderSide(color: Color(0xFFD9DBE4)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.schedule, size: 18),
                            label: Text('Início: ${_formatTime(startTime)}'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: endTime,
                              );
                              if (picked != null) {
                                setSheetState(() => endTime = picked);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: ink,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              side: const BorderSide(color: Color(0xFFD9DBE4)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.schedule_outlined, size: 18),
                            label: Text('Fim: ${_formatTime(endTime)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Cor da disciplina',
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List<Widget>.generate(subjectColors.length, (i) {
                        final selected = selectedColorIndex == i;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () =>
                                setSheetState(() => selectedColorIndex = i),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: subjectColors[i],
                                shape: BoxShape.circle,
                                border: selected
                                    ? Border.all(color: ink, width: 2.5)
                                    : null,
                              ),
                              child: selected
                                  ? const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 18),
                    PrimaryButton(
                      label: existing == null
                          ? 'Adicionar disciplina'
                          : 'Salvar disciplina',
                      onPressed: () {
                        if (nameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text('Digite o nome da disciplina.'),
                            ),
                          );
                          return;
                        }
                        if (selectedDays.isEmpty) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Escolha pelo menos um dia de aula.'),
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

    final name = nameController.text.trim();
    nameController.dispose();

    if (confirmed != true || name.isEmpty || selectedDays.isEmpty) return;

    final sortedDays = selectedDays.toList()..sort();
    final item = SubjectItem(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      weekdays: sortedDays,
      startTime: _formatTime(startTime),
      endTime: _formatTime(endTime),
      colorIndex: selectedColorIndex,
    );

    final updated = existing == null
        ? <SubjectItem>[...subjects, item]
        : subjects.map((s) => s.id == item.id ? item : s).toList();

    await AppStorage.saveSubjects(updated);
    final counts = await AppStorage.loadSubjectNoteCounts(updated);
    if (!mounted) return;
    setState(() {
      subjects = updated;
      noteCounts = counts;
    });
  }

  Future<void> _removeSubject(SubjectItem subject) async {
    final updated = subjects.where((s) => s.id != subject.id).toList();
    await AppStorage.saveSubjects(updated);
    if (!mounted) return;
    setState(() => subjects = updated);
  }

  Future<void> _continue() async {
    if (widget.isOnboarding && subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adicione pelo menos uma disciplina para continuar.'),
        ),
      );
      return;
    }

    await AppStorage.saveSubjects(subjects);
    if (!mounted) return;

    if (widget.isOnboarding) {
      await pushScreen<void>(context, const FixedTasksSetupScreen());
    } else {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isOnboarding ? 'Disciplinas' : 'Disciplinas e horários',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          backgroundColor: canvas,
          surfaceTintColor: canvas,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.isOnboarding) ...[
                  const StepHeader(step: 2, totalSteps: 3),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Suas disciplinas e horários',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Cadastre cada disciplina com os dias e horário da aula. Depois você pode tocar em qualquer disciplina para fazer anotações.',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : subjects.isEmpty
                          ? const Center(
                              child: SurfaceCard(
                                padding: EdgeInsets.all(22),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundColor: paleBlue,
                                      foregroundColor: blue,
                                      child: Icon(Icons.menu_book_rounded),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Nenhuma disciplina cadastrada',
                                      style: TextStyle(
                                        color: ink,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Toque em "+ Adicionar disciplina" para informar o nome, os dias e o horário de cada matéria.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: subjects.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, index) {
                                final subject = subjects[index];
                                return SubjectTile(
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
                                    await _loadSubjects();
                                  },
                                  trailingWidget: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Editar disciplina',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _openSubjectSheet(
                                          existing: subject,
                                        ),
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 19,
                                          color: blue,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Remover disciplina',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () =>
                                            _removeSubject(subject),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 19,
                                          color: muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  label: '+ Adicionar disciplina',
                  onPressed: () => _openSubjectSheet(),
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: widget.isOnboarding
                      ? 'Continuar para tarefas fixas'
                      : 'Salvar e voltar',
                  onPressed: _continue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FixedTasksSetupScreen extends StatefulWidget {
  const FixedTasksSetupScreen({super.key});

  @override
  State<FixedTasksSetupScreen> createState() => _FixedTasksSetupScreenState();
}

class _FixedTasksSetupScreenState extends State<FixedTasksSetupScreen> {
  List<FixedTask> tasks = <FixedTask>[];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final loaded = await AppStorage.loadFixedTasks();
    if (!mounted) return;
    setState(() {
      tasks = loaded;
      loading = false;
    });
  }

  Future<void> _addTask() async {
    final task = await showFixedTaskEditorSheet(context);
    if (task == null) return;
    final updated = <FixedTask>[...tasks, task];
    await AppStorage.saveFixedTasks(updated);
    await NotificationService.instance.scheduleFixedTask(task);
    if (!mounted) return;
    setState(() => tasks = updated);
  }

  Future<void> _removeTask(FixedTask task) async {
    final updated = tasks.where((t) => t.id != task.id).toList();
    await AppStorage.saveFixedTasks(updated);
    await NotificationService.instance.cancelFixedTask(task);
    if (!mounted) return;
    setState(() => tasks = updated);
  }

  Future<void> _finishOnboarding() async {
    await AppStorage.saveFixedTasks(tasks);
    await AppStorage.setOnboardingComplete(true);
    await NotificationService.instance.rescheduleAllFixedTasks(tasks);
    if (!mounted) return;
    replaceScreen(context, const AppShell());
  }

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Tarefas fixas',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          backgroundColor: canvas,
          surfaceTintColor: canvas,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const StepHeader(step: 3, totalSteps: 3),
                const SizedBox(height: 16),
                Text(
                  'Agende suas tarefas fixas',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                const Text(
                  'O UniSync enviará uma notificação no seu celular perguntando se você fez cada tarefa e mostrará no Resumo quantas vezes você concluiu no mês.',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : tasks.isEmpty
                          ? const Center(
                              child: SurfaceCard(
                                padding: EdgeInsets.all(22),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundColor: paleBlue,
                                      foregroundColor: blue,
                                      child: Icon(
                                        Icons.notifications_active_outlined,
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Nenhuma tarefa fixa ainda',
                                      style: TextStyle(
                                        color: ink,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Ex.: "Revisar conteúdo às 20:00", "Academia às 07:00". Você também pode adicionar depois no app.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: tasks.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, index) {
                                final task = tasks[index];
                                return SurfaceCard(
                                  child: Row(
                                    children: [
                                      const CircleAvatar(
                                        radius: 18,
                                        backgroundColor: paleBlue,
                                        foregroundColor: blue,
                                        child: Icon(Icons.repeat_rounded),
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
                                              ),
                                            ),
                                            Text(
                                              'Perguntar às ${task.time} · ${formatWeekdays(task.weekdays)}',
                                              style: const TextStyle(
                                                color: muted,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Remover',
                                        onPressed: () => _removeTask(task),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  label: '+ Adicionar tarefa fixa',
                  onPressed: _addTask,
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: 'Concluir e entrar no app',
                  onPressed: _finishOnboarding,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
