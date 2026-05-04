// DAILY 계획 탭 — plan v6.2 발효 (HQ 1936 결재)
// W1~W5+ 사다리 + Phase 1/2 시기별 일과.
// 사용자 5/5 02:33 명시 = 단순·직관 / 핵심 4 기능.
import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../widgets/common.dart';

class PlanPage extends StatelessWidget {
  const PlanPage({super.key});

  static final _w1Start = DateTime(2026, 5, 5);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final daysFromW1 = now.difference(_w1Start).inDays;
    final currentWeek = (daysFromW1 / 7).floor() + 1;
    final isPhase1 = now.isBefore(DateTime(2026, 8, 15));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            _PhaseHeader(isPhase1: isPhase1, currentWeek: currentWeek),
            const SizedBox(height: DailySpace.lg),
            SectionHeader(title: '7주 사다리 · D-74 → 7/19', accent: DailyPalette.gold),
            const SizedBox(height: DailySpace.sm),
            _LadderCard(currentWeek: currentWeek),
            const SizedBox(height: DailySpace.lg),
            SectionHeader(title: 'Phase 시기별 일과', accent: theme.colorScheme.primary),
            const SizedBox(height: DailySpace.sm),
            _PhaseCard(
              label: 'Phase 1 · 1차 PSAT 시기',
              period: '2026-05-05 ~ 2026-07-19',
              total: '10h',
              t1: 'T1 4h · PSAT 자해 + 언논',
              t2: 'T2 4h · PSAT 상판 + 헌법 강의',
              t3: 'T3 2h · light 회독 + 정보 수급',
              active: isPhase1,
            ),
            const SizedBox(height: DailySpace.sm),
            _PhaseCard(
              label: 'Phase 2 · 2차 시기',
              period: '2026-08-15 ~ 2026-10-15',
              total: '12h',
              t1: 'T1 4h · 헌법',
              t2: 'T2 4h · 국제법',
              t3: 'T3 4h · 국정 + 이슈',
              active: !isPhase1,
            ),
            const SizedBox(height: DailySpace.lg),
            SectionHeader(title: '24h 정착 routine', accent: DailyPalette.gold),
            const SizedBox(height: DailySpace.sm),
            const _RoutineCard(),
          ],
        ),
      ),
    );
  }
}

class _PhaseHeader extends StatelessWidget {
  final bool isPhase1;
  final int currentWeek;
  const _PhaseHeader({required this.isPhase1, required this.currentWeek});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dDay = DateTime(2026, 7, 19).difference(DateTime.now()).inDays;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [DailyPalette.goldSurface, DailyPalette.cream],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DailyPalette.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('plan v6.2 발효',
              style: theme.textTheme.bodySmall?.copyWith(color: DailyPalette.gold, fontWeight: FontWeight.w600, letterSpacing: 1.0)),
          const SizedBox(height: 6),
          Text(
            'W$currentWeek · D-$dDay',
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            isPhase1 ? '1차 PSAT 시기 · 7월 19일 시험' : '2차 시기 · 10월 15일 시험',
            style: theme.textTheme.titleSmall?.copyWith(color: DailyPalette.ink),
          ),
        ],
      ),
    );
  }
}

class _LadderCard extends StatelessWidget {
  final int currentWeek;
  const _LadderCard({required this.currentWeek});

  static const _weeks = <Map<String, String>>[
    {'w': 'W1', 'p': '5/5~5/11', 'k': '적응기', 'wake': '07:30', 'study': '5h', 'note': '야행 회복 · T1 4h만 deliberate'},
    {'w': 'W2', 'p': '5/12~5/18', 'k': '안정기', 'wake': '07:00', 'study': '8h', 'note': 'T1·T2 풀가동 + T3 light 시작'},
    {'w': 'W3', 'p': '5/19~5/25', 'k': '가속기', 'wake': '06:30', 'study': '10h', 'note': 'T3 진입 · 모의고사 주 3회'},
    {'w': 'W4', 'p': '5/26~5/31', 'k': '정착 ★', 'wake': '06:30', 'study': '10~11h', 'note': 'routine 발효 · 시운전'},
    {'w': 'W5+', 'p': '6/1~7/18', 'k': '발효', 'wake': '06:30', 'study': '10h', 'note': '6주 유지 → 7/19 1차 PSAT'},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: DailyPalette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            for (var i = 0; i < _weeks.length; i++)
              _row(theme, _weeks[i], (i + 1) == currentWeek, i == _weeks.length - 1),
          ],
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, Map<String, String> w, bool active, bool isLast) {
    return Container(
      decoration: BoxDecoration(
        color: active ? DailyPalette.goldSurface : null,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      margin: EdgeInsets.only(bottom: isLast ? 0 : 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12, height: 12, margin: const EdgeInsets.only(top: 4, right: 12),
            decoration: BoxDecoration(
              color: active ? DailyPalette.gold : DailyPalette.line,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(w['w']!, style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: active ? DailyPalette.gold : DailyPalette.ink,
                    )),
                    const SizedBox(width: 8),
                    Text(w['k']!, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('${w['wake']} · ${w['study']}',
                        style: theme.textTheme.bodySmall?.copyWith(color: DailyPalette.ash, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(w['p']!, style: theme.textTheme.bodySmall?.copyWith(color: DailyPalette.ash, fontSize: 11)),
                const SizedBox(height: 2),
                Text(w['note']!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseCard extends StatelessWidget {
  final String label;
  final String period;
  final String total;
  final String t1, t2, t3;
  final bool active;

  const _PhaseCard({
    required this.label,
    required this.period,
    required this.total,
    required this.t1,
    required this.t2,
    required this.t3,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: active ? DailyPalette.gold : DailyPalette.line, width: active ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: active ? DailyPalette.gold : DailyPalette.ink,
                      )),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: active ? DailyPalette.gold : DailyPalette.line,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(total,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: active ? Colors.white : DailyPalette.ash,
                        fontWeight: FontWeight.w700,
                      )),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(period, style: theme.textTheme.bodySmall?.copyWith(color: DailyPalette.ash)),
            const SizedBox(height: 12),
            Text(t1, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(t2, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(t3, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard();

  static const _slots = <List<String>>[
    ['06:30', '기상 + 광노출 5분', '🌅'],
    ['06:50', '아침 30분 (소음인)', '🍚'],
    ['07:30', 'T1 deliberate 4h', '📚'],
    ['12:30', '점심 30분 + 산책', '🍱'],
    ['13:00', 'T2 review 4h', '📖'],
    ['17:00', '운동 30분 (홈 스트레칭)', '🤸'],
    ['18:00', '저녁 30분', '🍽'],
    ['19:00', 'T3 light 2~4h', '✏️'],
    ['22:30', '생활 정리 30분', '🧼'],
    ['23:00', '디지털 일기 (D5)', '📝'],
    ['23:30', '취침 (W4 = 23:00)', '🌙'],
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: DailyPalette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final s in _slots)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(s[0], style: theme.textTheme.bodySmall?.copyWith(
                        color: DailyPalette.gold, fontWeight: FontWeight.w700, fontFamily: 'monospace',
                      )),
                    ),
                    Text('${s[2]}  ', style: theme.textTheme.bodyMedium),
                    Expanded(child: Text(s[1], style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
