import 'package:material_ui/material_ui.dart';

import '../models/app_models.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'settings_screen.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({
    super.key,
    required this.refreshTick,
    required this.onDataChanged,
  });

  final int refreshTick;
  final VoidCallback onDataChanged;

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  static const List<String> _expenseCategories = <String>[
    'Transporte',
    'Alimentação',
    'Estudos',
    'Moradia',
    'Lazer',
    'Outros',
  ];

  static const List<String> _incomeCategories = <String>[
    'Entrada',
    'Estágio',
    'Bolsa',
    'Mesada',
    'Freelance',
  ];

  List<FinanceEntry> entries = <FinanceEntry>[];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void didUpdateWidget(covariant FinanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      _loadEntries();
    }
  }

  Future<void> _loadEntries() async {
    final loaded = await AppStorage.loadFinanceEntries();
    if (!mounted) return;
    setState(() => entries = loaded);
  }

  Future<void> _addEntry() async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    var isIncome = false;
    var category = _expenseCategories.first;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: canvas,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final categories =
                isIncome ? _incomeCategories : _expenseCategories;
            if (!categories.contains(category)) {
              category = categories.first;
            }

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
                    const Text(
                      'Novo lançamento',
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            selected: !isIncome,
                            showCheckmark: false,
                            selectedColor: red,
                            backgroundColor: paleRed,
                            side: BorderSide.none,
                            onSelected: (_) => setSheetState(() {
                              isIncome = false;
                              category = _expenseCategories.first;
                            }),
                            label: SizedBox(
                              width: double.infinity,
                              child: Text(
                                'Saída',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: !isIncome ? Colors.white : red,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChoiceChip(
                            selected: isIncome,
                            showCheckmark: false,
                            selectedColor: blue,
                            backgroundColor: paleBlue,
                            side: BorderSide.none,
                            onSelected: (_) => setSheetState(() {
                              isIncome = true;
                              category = _incomeCategories.first;
                            }),
                            label: SizedBox(
                              width: double.infinity,
                              child: Text(
                                'Entrada',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isIncome ? Colors.white : blue,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    AppField(
                      label: 'Descrição',
                      hintText: isIncome
                          ? 'Ex.: Estágio ou bolsa'
                          : 'Ex.: Passagem de ônibus, xerox, almoço',
                      controller: titleController,
                    ),
                    const SizedBox(height: 12),
                    AppField(
                      label: 'Valor (R\$)',
                      hintText: 'Ex.: 25,50',
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Categoria',
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: categories
                          .map(
                            (cat) => ChoiceChip(
                              selected: category == cat,
                              selectedColor: paleBlue,
                              label: Text(cat),
                              onSelected: (_) =>
                                  setSheetState(() => category = cat),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    PrimaryButton(
                      label: 'Salvar lançamento',
                      onPressed: () {
                        final raw = amountController.text
                            .trim()
                            .replaceAll('R\$', '')
                            .replaceAll(' ', '')
                            .replaceAll(',', '.');
                        final value = double.tryParse(raw);
                        if (titleController.text.trim().isEmpty ||
                            value == null ||
                            value <= 0) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Informe descrição e valor válido.'),
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
    final rawAmount = amountController.text
        .trim()
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.');
    final amount = double.tryParse(rawAmount);

    titleController.dispose();
    amountController.dispose();

    if (saved != true || title.isEmpty || amount == null || amount <= 0) return;

    final entry = FinanceEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      category: category,
      amount: amount,
      isIncome: isIncome,
      date: DateTime.now(),
    );

    final updated = <FinanceEntry>[entry, ...entries];
    await AppStorage.saveFinanceEntries(updated);
    if (!mounted) return;
    setState(() => entries = updated);
    widget.onDataChanged();
  }

  Future<void> _removeEntry(FinanceEntry entry) async {
    final updated = entries.where((e) => e.id != entry.id).toList();
    await AppStorage.saveFinanceEntries(updated);
    if (!mounted) return;
    setState(() => entries = updated);
    widget.onDataChanged();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthEntries = entries
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .toList();

    final incomeTotal = monthEntries
        .where((e) => e.isIncome)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final expenseTotal = monthEntries
        .where((e) => !e.isIncome)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final balance = incomeTotal - expenseTotal;
    final currentMonthName = monthNamesPt[now.month - 1];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            children: [
              // Header estilo Page 5: "Financeiro" + engrenagem
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Financeiro',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ),
                  SettingsButton(
                    onPressed: () async {
                      await pushScreen<void>(
                        context,
                        SettingsScreen(onDataChanged: widget.onDataChanged),
                      );
                      await _loadEntries();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Card de Saldo (estilo Page 5)
              SurfaceCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saldo de ${currentMonthName.toLowerCase()}',
                      style: const TextStyle(color: muted, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatCurrencyBr(balance),
                      style: TextStyle(
                        color: balance < 0 ? red : ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 32,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Entradas',
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatCurrencyBr(incomeTotal),
                                style: const TextStyle(
                                  color: blue,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Saídas',
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatCurrencyBr(expenseTotal),
                                style: const TextStyle(
                                  color: red,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Lançamentos + pill do mês
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Lançamentos',
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                      ),
                    ),
                  ),
                  PillBadge(label: currentMonthName),
                ],
              ),
              const SizedBox(height: 12),
              if (monthEntries.isEmpty)
                const SurfaceCard(
                  child: Text(
                    'Nenhum lançamento registrado neste mês. Toque em "+ Novo lançamento" abaixo.',
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                )
              else
                SurfaceCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  child: Column(
                    children: List<Widget>.generate(monthEntries.length, (i) {
                      final entry = monthEntries[i];
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.title,
                                        style: const TextStyle(
                                          color: ink,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${entry.category} · ${formatShortDayMonth(entry.date)}',
                                        style: const TextStyle(
                                          color: muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${entry.isIncome ? '+ ' : '− '}${formatCurrencyBr(entry.amount)}',
                                  style: TextStyle(
                                    color: entry.isIncome ? blue : red,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  tooltip: 'Excluir',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _removeEntry(entry),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (i != monthEntries.length - 1)
                            const Divider(height: 1, color: borderColor),
                        ],
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: PrimaryButton(
            label: '+ Novo lançamento',
            onPressed: _addEntry,
          ),
        ),
      ],
    );
  }
}
