import 'package:material_ui/material_ui.dart';

import '../models/app_models.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class SubjectNotesScreen extends StatefulWidget {
  const SubjectNotesScreen({super.key, required this.subject});

  final SubjectItem subject;

  @override
  State<SubjectNotesScreen> createState() => _SubjectNotesScreenState();
}

class _SubjectNotesScreenState extends State<SubjectNotesScreen> {
  List<SubjectNote> notes = <SubjectNote>[];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final loaded = await AppStorage.loadSubjectNotes(widget.subject);
    if (!mounted) return;
    setState(() {
      notes = loaded;
      loading = false;
    });
  }

  Future<void> _openNoteEditor({SubjectNote? existing}) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final contentController =
        TextEditingController(text: existing?.content ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: canvas,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  existing == null ? 'Nova anotação' : 'Editar anotação',
                  style: const TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subject.name,
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                AppField(
                  label: 'Título (opcional)',
                  hintText: 'Ex.: Aula 04 - Resumo para a prova',
                  controller: titleController,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Anotação',
                  style: TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 7),
                TextField(
                  controller: contentController,
                  minLines: 5,
                  maxLines: 10,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText:
                        'Escreva conteúdos vistos, dúvidas, datas de provas ou exercícios...',
                    hintStyle: TextStyle(color: muted, fontSize: 13),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: existing == null
                      ? 'Salvar anotação'
                      : 'Atualizar anotação',
                  onPressed: () {
                    if (titleController.text.trim().isEmpty &&
                        contentController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(
                          content: Text('Digite algum texto para salvar.'),
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

    final title = titleController.text.trim();
    final content = contentController.text.trim();
    titleController.dispose();
    contentController.dispose();

    if (saved != true || (title.isEmpty && content.isEmpty)) return;

    final now = DateTime.now();
    List<SubjectNote> updated;
    if (existing == null) {
      final newNote = SubjectNote(
        id: now.microsecondsSinceEpoch.toString(),
        title: title.isEmpty ? 'Anotação de ${formatDatePt(now)}' : title,
        content: content,
        updatedAt: now,
      );
      updated = <SubjectNote>[newNote, ...notes];
    } else {
      updated = notes
          .map(
            (note) => note.id == existing.id
                ? SubjectNote(
                    id: note.id,
                    title: title.isEmpty ? note.title : title,
                    content: content,
                    updatedAt: now,
                  )
                : note,
          )
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }

    await AppStorage.saveSubjectNotes(widget.subject.id, updated);
    if (!mounted) return;
    setState(() => notes = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null ? 'Anotação salva.' : 'Anotação atualizada.',
        ),
      ),
    );
  }

  Future<void> _deleteNote(SubjectNote note) async {
    final updated = notes.where((item) => item.id != note.id).toList();
    await AppStorage.saveSubjectNotes(widget.subject.id, updated);
    if (!mounted) return;
    setState(() => notes = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Anotação removida.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = subjectColorAt(widget.subject.colorIndex);
    return MobileFrame(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.subject.name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          backgroundColor: canvas,
          surfaceTintColor: canvas,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SurfaceCard(
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.subject.name,
                              style: const TextStyle(
                                color: ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.subject.daysLabel} · ${widget.subject.timeLabel}',
                              style:
                                  const TextStyle(color: muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Chip(
                        label: Text(
                          notes.length == 1
                              ? '1 nota'
                              : '${notes.length} notas',
                        ),
                        backgroundColor: paleBlue,
                        side: BorderSide.none,
                        labelStyle: const TextStyle(
                          color: blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : notes.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircleAvatar(
                                    radius: 28,
                                    backgroundColor: paleBlue,
                                    foregroundColor: blue,
                                    child: Icon(
                                      Icons.edit_note_rounded,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'Nenhuma anotação ainda',
                                    style: TextStyle(
                                      color: ink,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Registre conteúdos das aulas, resumos, dúvidas e lembretes de ${widget.subject.name}.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                            itemCount: notes.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, index) {
                              final note = notes[index];
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _openNoteEditor(existing: note),
                                  child: SurfaceCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                note.title,
                                                style: const TextStyle(
                                                  color: ink,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Editar anotação',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: () => _openNoteEditor(
                                                existing: note,
                                              ),
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 18,
                                                color: blue,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Excluir anotação',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: () =>
                                                  _deleteNote(note),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                size: 18,
                                                color: muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (note.content.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            note.content,
                                            style: const TextStyle(
                                              color: ink,
                                              fontSize: 13,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Text(
                                          'Atualizada em ${formatDateTimePt(note.updatedAt)}',
                                          style: const TextStyle(
                                            color: muted,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: PrimaryButton(
                  label: '+ Nova anotação',
                  onPressed: () => _openNoteEditor(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
