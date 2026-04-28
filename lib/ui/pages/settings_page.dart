import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../widgets/common.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            const HeroCard(
              title: '설정',
              subtitle: '앱 정보 · 연동 · 역할',
              icon: Icons.settings_outlined,
            ),
            const SizedBox(height: DailySpace.lg),
            SectionHeader(title: '앱', accent: theme.colorScheme.primary),
            const SizedBox(height: DailySpace.sm),
            _row('앱 버전', 'DAILY v2.0.0 (scratch 2026-04-24)', theme, isDark),
            _row('Firestore', 'cheonhong-studio', theme, isDark),
            _row('UID', 'sJ8Pxusw9gR0tNR44RhkIge7OiG2', theme, isDark),
            const SizedBox(height: DailySpace.lg),
            SectionHeader(title: '도메인 · 연동', accent: DailyPalette.gold),
            const SizedBox(height: DailySpace.sm),
            _row('역할', '일상·수면·심리·life_logs (공부는 STUDY)', theme, isDark),
            _row('HB 텔레그램', '@Chhabitbot_bot', theme, isDark),
            _row('테마 모드', isDark ? 'Dark (system)' : 'Light (system)', theme, isDark),
            const SizedBox(height: DailySpace.xl),
            Text(
              '데이터는 HB 텔레그램으로 기입하세요. 앱은 조회·시각화 전용.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v, ThemeData theme, bool isDark) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(DailySpace.md),
        decoration: BoxDecoration(
          color: isDark ? DailyPalette.cardDark : DailyPalette.card,
          borderRadius: BorderRadius.circular(DailySpace.radius),
          border: Border.all(color: isDark ? DailyPalette.lineDark : DailyPalette.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(k, style: theme.textTheme.labelMedium)),
            Expanded(child: Text(v, style: theme.textTheme.bodyMedium)),
          ],
        ),
      );
}
