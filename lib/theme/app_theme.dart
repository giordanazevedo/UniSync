import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

// Paleta oficial do UniSync
const Color blue = Color(0xFF2F479D); // Azul principal
const Color darkBlue = Color(0xFF223A80); // Azul escuro (destaques)
const Color paleBlue = Color(0xFFE7EDFB); // Azul claro (cards)
const Color canvas = Color(0xFFF5F4F9); // Fundo das telas
const Color orange = Color(0xFFE18137); // Laranja (alerta, disciplina)
const Color red = Color(0xFFC6514A); // Vermelho (saídas, provas)
const Color purple = Color(0xFF844EBE); // Roxo (categoria)
const Color brandIndigo = Color(0xFF4F46E5); // Índigo da marca UniSync
const Color brandTeal = Color(0xFF5EEAD4); // Turquesa da marca UniSync
const Color brandNavy = Color(0xFF1E1B4B); // Marinho da marca UniSync
const Color ink = Color(0xFF171A20);
const Color muted = Color(0xFF7B8090);
const Color borderColor = Color(0xFFE6E8F2);
const Color paleBlueBorder = Color(0xFFD5E0FA);
const Color paleOrange = Color(0xFFFFF1E6);
const Color paleRed = Color(0xFFFDECEC);
const Color green = Color(0xFF1E8E5A);
const Color paleGreen = Color(0xFFE6F6EE);

const List<Color> subjectColors = <Color>[blue, orange, purple, red];

Color subjectColorAt(int index) =>
    subjectColors[index.abs() % subjectColors.length];

ThemeData buildUniSyncTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'PlusJakartaSans',
    scaffoldBackgroundColor: canvas,
    colorScheme: ColorScheme.fromSeed(
      seedColor: blue,
      primary: blue,
      surface: Colors.white,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: ink,
        fontWeight: FontWeight.w900,
        fontSize: 30,
        letterSpacing: -0.9,
      ),
      headlineMedium: TextStyle(
        color: ink,
        fontWeight: FontWeight.w800,
        fontSize: 26,
        letterSpacing: -0.6,
      ),
      titleLarge: TextStyle(
        color: ink,
        fontWeight: FontWeight.w800,
        fontSize: 21,
        letterSpacing: -0.4,
      ),
      titleMedium: TextStyle(
        color: ink,
        fontWeight: FontWeight.w800,
        fontSize: 16,
      ),
      bodyLarge: TextStyle(
        color: ink,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: TextStyle(
        color: muted,
        fontWeight: FontWeight.w500,
        height: 1.35,
      ),
      labelLarge: TextStyle(
        fontWeight: FontWeight.w700,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD8DCE8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD8DCE8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: blue, width: 1.6),
      ),
    ),
  );
}

class MobileFrame extends StatelessWidget {
  const MobileFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFEBEAEF),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ColoredBox(color: canvas, child: child),
        ),
      ),
    );
  }
}

class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.13),
      decoration: BoxDecoration(
        color: brandIndigo,
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x334F46E5),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: CustomPaint(painter: _UniSyncMarkPainter()),
    );
  }
}

class _UniSyncMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 120.0, size.height / 120.0);

    final circleRect = Rect.fromCircle(
      center: const Offset(60, 60),
      radius: 44,
    );

    // Arco superior branco + ponta de seta
    final topStroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      circleRect,
      -2.7925,
      2.4435,
      false,
      topStroke,
    );

    final topArrow = Path()
      ..moveTo(104.4, 53.4)
      ..lineTo(109.8, 41.9)
      ..lineTo(92.9, 48.0)
      ..close();
    canvas.drawPath(topArrow, Paint()..color = Colors.white);
    canvas.drawPath(
      topArrow,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );

    // Arco inferior turquesa + ponta de seta
    final bottomStroke = Paint()
      ..color = brandTeal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      circleRect,
      0.3491,
      2.4435,
      false,
      bottomStroke,
    );

    final bottomArrow = Path()
      ..moveTo(15.6, 66.6)
      ..lineTo(10.2, 78.1)
      ..lineTo(27.1, 72.0)
      ..close();
    canvas.drawPath(bottomArrow, Paint()..color = brandTeal);
    canvas.drawPath(
      bottomArrow,
      Paint()
        ..color = brandTeal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );

    // Letra U central branca
    final uPath = Path()
      ..moveTo(44, 44)
      ..lineTo(44, 66)
      ..arcTo(
        Rect.fromCircle(center: const Offset(60, 66), radius: 16),
        math.pi,
        -math.pi,
        false,
      )
      ..lineTo(76, 44);
    canvas.drawPath(
      uPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.label,
    this.hintText,
    this.obscureText = false,
    this.controller,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final String label;
  final String? hintText;
  final bool obscureText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: ink,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              color: Color(0xFF9EA3B0),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          style: const TextStyle(
            color: ink,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.hintText,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final String hintText;
  final T? value;
  final List<T> items;
  final String Function(T item) itemLabel;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: ink,
            fontWeight: FontWeight.w700,
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
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              borderRadius: BorderRadius.circular(16),
              dropdownColor: Colors.white,
              menuMaxHeight: 320,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: blue,
                size: 24,
              ),
              hint: Text(
                hintText,
                style: const TextStyle(
                  color: Color(0xFF9EA3B0),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: const TextStyle(
                color: ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              items: items
                  .map(
                    (item) => DropdownMenuItem<T>(
                      value: item,
                      child: Text(
                        itemLabel(item),
                        style: const TextStyle(
                          color: ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          backgroundColor: Colors.white,
          side: const BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }
}

class PillBadge extends StatelessWidget {
  const PillBadge({
    super.key,
    required this.label,
    this.backgroundColor = paleBlue,
    this.textColor = blue,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class StepHeader extends StatelessWidget {
  const StepHeader({
    super.key,
    required this.step,
    this.totalSteps = 3,
  });

  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Passo $step de $totalSteps',
          style: const TextStyle(
            color: ink,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        ProgressLine(value: step / totalSteps),
      ],
    );
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = Colors.white,
    this.borderRadius = 20,
    this.borderSideColor = borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double borderRadius;
  final Color borderSideColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderSideColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1B2559),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class SubjectTile extends StatelessWidget {
  const SubjectTile({
    super.key,
    required this.name,
    required this.days,
    required this.time,
    required this.color,
    this.notesCount,
    this.onTap,
    this.trailingWidget,
  });

  final String name;
  final String days;
  final String time;
  final Color color;
  final int? notesCount;
  final VoidCallback? onTap;
  final Widget? trailingWidget;

  @override
  Widget build(BuildContext context) {
    final notesHint = notesCount == null
        ? null
        : notesCount == 0
            ? 'Toque para anotar'
            : notesCount == 1
                ? '1 anotação'
                : '$notesCount anotações';

    final tile = SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      borderRadius: 18,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notesHint == null ? days : '$days · $notesHint',
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (trailingWidget != null)
            trailingWidget!
          else
            Text(
              time,
              style: const TextStyle(
                color: ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );

    return onTap == null
        ? tile
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: tile,
            ),
          );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, this.initials = 'US', this.radius = 24});

  final String initials;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: blue,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1B2559),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.settings_outlined, color: ink, size: 22),
      ),
    );
  }
}

class Metric extends StatelessWidget {
  const Metric({
    super.key,
    required this.label,
    required this.value,
    this.valueColor = ink,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: muted,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: .4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class ProgressLine extends StatelessWidget {
  const ProgressLine({
    super.key,
    required this.value,
    this.color = blue,
    this.height = 7,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: const Color(0xFFECEEF5),
        color: color,
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(
          color: ink,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: muted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: muted),
    );
  }
}

class ControlBottomBar extends StatelessWidget {
  const ControlBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = <({IconData icon, String label})>[
    (icon: Icons.home_outlined, label: 'Início'),
    (icon: Icons.calendar_today_outlined, label: 'Agenda'),
    (icon: Icons.account_balance_wallet_outlined, label: 'Finanças'),
    (icon: Icons.bar_chart_rounded, label: 'Resumo'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: List<Widget>.generate(_items.length, (i) {
              final item = _items[i];
              final selected = i == selectedIndex;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onSelected(i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: selected ? paleBlue : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item.icon,
                          size: 21,
                          color: selected ? blue : const Color(0xFF8B90A0),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: selected ? blue : const Color(0xFF8B90A0),
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

Future<T?> pushScreen<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    MaterialPageRoute<T>(builder: (_) => page),
  );
}

void replaceScreen(BuildContext context, Widget page) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => page),
    (_) => false,
  );
}
