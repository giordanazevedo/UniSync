import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'agenda_screen.dart';
import 'finance_screen.dart';
import 'home_screen.dart';
import 'summary_screen.dart';

final ValueNotifier<int> appRefreshNotifier = ValueNotifier<int>(0);

void notifyAppDataChanged() {
  appRefreshNotifier.value = appRefreshNotifier.value + 1;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: appRefreshNotifier,
      builder: (context, refreshTick, _) {
        final pages = <Widget>[
          HomeScreen(
            refreshTick: refreshTick,
            onDataChanged: notifyAppDataChanged,
          ),
          AgendaScreen(
            refreshTick: refreshTick,
            onDataChanged: notifyAppDataChanged,
          ),
          FinanceScreen(
            refreshTick: refreshTick,
            onDataChanged: notifyAppDataChanged,
          ),
          SummaryScreen(
            refreshTick: refreshTick,
            onDataChanged: notifyAppDataChanged,
          ),
        ];

        return MobileFrame(
          child: Scaffold(
            body: SafeArea(child: pages[index]),
            bottomNavigationBar: ControlBottomBar(
              selectedIndex: index,
              onSelected: (value) => setState(() => index = value),
            ),
          ),
        );
      },
    );
  }
}
