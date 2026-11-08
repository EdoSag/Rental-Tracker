import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'models.dart';
import 'screens/month_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/summary_screen.dart';
import 'state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.load();
  runApp(RentalApp(state: state));
}

class RentalApp extends StatelessWidget {
  final AppState state;
  const RentalApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D6B), brightness: b),
          useMaterial3: true,
          cardTheme: const CardThemeData(elevation: 1),
        );
    return MaterialApp(
      title: 'ניהול שכירות',
      debugShowCheckedModeBanner: false,
      locale: const Locale('he', 'IL'),
      supportedLocales: const [Locale('he', 'IL')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: HomePage(state: state),
    );
  }
}

class HomePage extends StatefulWidget {
  final AppState state;
  const HomePage({super.key, required this.state});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _tab = 0;
  String _month = monthKey(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) widget.state.flush();
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['חודש', 'סיכום', 'הגדרות'];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_tab])),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListenableBuilder(
          listenable: widget.state,
          builder: (context, _) => switch (_tab) {
            0 => MonthScreen(state: widget.state, month: _month, onMonthChanged: (m) => setState(() => _month = m)),
            1 => SummaryScreen(state: widget.state),
            _ => SettingsScreen(state: widget.state, currentMonth: monthKey(DateTime.now().year, DateTime.now().month)),
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          FocusScope.of(context).unfocus();
          setState(() => _tab = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'חודש'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'סיכום'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'הגדרות'),
        ],
      ),
    );
  }
}
