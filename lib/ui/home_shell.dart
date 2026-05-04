import 'package:flutter/material.dart';
import '../theme/theme.dart';
import 'pages/today_page.dart';
import 'pages/records_page.dart';
import 'pages/plan_page.dart';
import 'pages/diary_page.dart';
import 'pages/settings_page.dart';

/// DAILY HomeShell · 4탭 v13 (사용자 5/5 02:33 + 05:01 명시 · 단순화 / self_care 흡수 / 일기 신규)
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _idx = 0;
  static const _pages = <Widget>[
    TodayPage(),
    RecordsPage(),
    PlanPage(),
    DiaryPage(),
  ];

  void _openSettings() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: DailyPalette.paper,
        elevation: 0,
        title: const Text('Daily', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: _openSettings,
            tooltip: '설정',
          ),
        ],
      ),
      body: IndexedStack(index: _idx, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        backgroundColor: DailyPalette.paper,
        indicatorColor: DailyPalette.goldSurface,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.wb_sunny_outlined), selectedIcon: Icon(Icons.wb_sunny), label: '오늘'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: '기록'),
          NavigationDestination(icon: Icon(Icons.timeline_outlined), selectedIcon: Icon(Icons.timeline), label: '계획'),
          NavigationDestination(icon: Icon(Icons.edit_note_outlined), selectedIcon: Icon(Icons.edit_note), label: '일기'),
        ],
      ),
    );
  }
}
