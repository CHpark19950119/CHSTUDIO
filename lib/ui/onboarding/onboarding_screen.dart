import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/theme.dart';

const _kOnboardingDoneKey = 'daily_onboarding_done_v1';

Future<bool> shouldShowDailyOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return !(prefs.getBool(_kOnboardingDoneKey) ?? false);
}

Future<void> markDailyOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingDoneKey, true);
}

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _idx = 0;

  static const _pages = <_OnPage>[
    _OnPage(
      icon: Icons.wb_sunny_outlined,
      title: 'DAILY 에 오신 걸 환영합니다',
      body: '일상·수면·심리·식사·외출을 한 곳에 기록하고\n시각화해서 패턴을 찾는 앱입니다.',
      accent: 0xFF8B6F47,
    ),
    _OnPage(
      icon: Icons.send_outlined,
      title: 'HB 텔레그램 봇으로 기입',
      body: '@Chhabitbot_bot 으로 메시지만 보내면\n자동으로 Firestore 에 기록되고\n앱은 시각화·조회 전용입니다.',
      accent: 0xFFC8975B,
    ),
    _OnPage(
      icon: Icons.dashboard_outlined,
      title: '오늘 · 기록 · 계획 · 설정',
      body: '오늘 탭은 Quick stats, 기록 탭은 캘린더,\n계획 탭은 시험 D-day · 수면 위상.\n다크 모드는 시스템 설정을 따라갑니다.',
      accent: 0xFF7A8A6E,
    ),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _idx == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _idx = i),
                itemBuilder: (_, i) => _PageBody(page: _pages[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _idx;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: active ? 18 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: active ? theme.colorScheme.primary : (theme.dividerTheme.color ?? DailyPalette.line),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () async {
                      await markDailyOnboardingDone();
                      if (mounted) widget.onDone();
                    },
                    child: const Text('건너뛰기'),
                  ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      if (isLast) {
                        await markDailyOnboardingDone();
                        if (mounted) widget.onDone();
                      } else {
                        _ctrl.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
                      }
                    },
                    child: Text(isLast ? '시작' : '다음'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnPage {
  final IconData icon;
  final String title;
  final String body;
  final int accent;
  const _OnPage({required this.icon, required this.title, required this.body, required this.accent});
}

class _PageBody extends StatelessWidget {
  final _OnPage page;
  const _PageBody({required this.page});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = Color(page.accent);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 56, color: accent),
          ),
          const Spacer(),
          Text(page.title, style: theme.textTheme.displayLarge?.copyWith(letterSpacing: -0.8, fontSize: 28)),
          const SizedBox(height: 14),
          Text(page.body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6, fontSize: 15)),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
