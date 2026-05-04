// DAILY 오늘 탭 — 일상 dashboard (사용자 명시 2026-05-01 14:32 = 공부 관련 전부 제거).
// v13 재구성 (사용자 5/5 02:33 + 05:01) — Hero + 진도 + 습관 + 이관 + self_care FAB.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/app.dart';
import '../../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/routine_checklist.dart';
import '../widgets/today_timeline.dart';
import 'self_care_page.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: DailyPalette.gold,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.favorite),
        label: const Text('self_care'),
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SelfCarePage()));
        },
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => await Future.delayed(const Duration(milliseconds: 300)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
            children: [
              const _HeroToday(),
              const SizedBox(height: DailySpace.lg),
              SectionHeader(title: '오늘의 진도', accent: DailyPalette.gold),
              const SizedBox(height: DailySpace.sm),
              const _StudyProgressCard(),
              const SizedBox(height: DailySpace.lg),
              SectionHeader(title: '오늘의 습관', accent: theme.colorScheme.primary),
              const SizedBox(height: DailySpace.sm),
              const RoutineChecklist(),
              const SizedBox(height: DailySpace.lg),
              SectionHeader(title: 'ST·HQ 자동 이관', accent: DailyPalette.gold),
              const SizedBox(height: DailySpace.sm),
              const _ImportSourcesCard(),
              const SizedBox(height: DailySpace.lg),
              SectionHeader(title: '오늘 일정', accent: theme.colorScheme.primary),
              const SizedBox(height: DailySpace.sm),
              const TodayTimeline(),
            ],
          ),
        ),
      ),
    );
  }
}

/// 학업 진도 카드 — T1 / T2 / T3 progress bar (Phase 1 = 10h / Phase 2 = 12h).
class _StudyProgressCard extends StatelessWidget {
  const _StudyProgressCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final examDate = DateTime(2026, 7, 19);
    final dDay = examDate.difference(DateTime.now()).inDays;
    // Phase: 5/5~7/19 = Phase 1 (1차 PSAT) / 8/15~10/15 = Phase 2 (2차).
    final isPhase1 = DateTime.now().isBefore(DateTime(2026, 8, 15));
    final t3Target = isPhase1 ? 120 : 240;
    final phaseLabel = isPhase1 ? 'Phase 1 · 1차 PSAT (10h)' : 'Phase 2 · 2차 (12h)';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users/$kUid/daily_log').doc(today).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final progress = data['study_progress'] as Map<String, dynamic>? ?? {};
        final t1 = (progress['t1'] as Map<String, dynamic>? ?? {})['actual_min'] as int? ?? 0;
        final t2 = (progress['t2'] as Map<String, dynamic>? ?? {})['actual_min'] as int? ?? 0;
        final t3 = (progress['t3'] as Map<String, dynamic>? ?? {})['actual_min'] as int? ?? 0;
        final totalActual = t1 + t2 + t3;
        final totalTarget = 240 + 240 + t3Target;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: DailyPalette.line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('D-$dDay · $phaseLabel',
                        style: theme.textTheme.bodyMedium?.copyWith(color: DailyPalette.gold, fontWeight: FontWeight.w600)),
                    Text('${(totalActual / 60).toStringAsFixed(1)}h / ${(totalTarget / 60).toStringAsFixed(0)}h',
                        style: theme.textTheme.bodySmall?.copyWith(color: DailyPalette.ash)),
                  ],
                ),
                const SizedBox(height: 12),
                _progressRow(theme, 'T1 deliberate', t1, 240),
                const SizedBox(height: 8),
                _progressRow(theme, 'T2 review', t2, 240),
                const SizedBox(height: 8),
                _progressRow(theme, isPhase1 ? 'T3 light' : 'T3 deliberate', t3, t3Target),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _progressRow(ThemeData theme, String label, int actual, int target) {
    final ratio = target > 0 ? (actual / target).clamp(0.0, 1.0) : 0.0;
    final complete = actual >= target;
    return Row(
      children: [
        SizedBox(width: 110, child: Text(label, style: theme.textTheme.bodyMedium)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 12,
              backgroundColor: DailyPalette.line,
              valueColor: AlwaysStoppedAnimation(complete ? Colors.green : DailyPalette.gold),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(complete ? '✓' : '${(ratio * 100).toStringAsFixed(0)}%',
            style: theme.textTheme.bodySmall?.copyWith(color: complete ? Colors.green : DailyPalette.ash)),
      ],
    );
  }
}

/// ST·HQ 자동 이관 카드 — 매일 23:30 cron pull.
class _ImportSourcesCard extends StatelessWidget {
  const _ImportSourcesCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users/$kUid/daily_log').doc(today).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final st = data['imported_st'] as Map<String, dynamic>?;
        final hq = data['imported_hq'] as Map<String, dynamic>?;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: DailyPalette.line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sourceRow(theme, '🎓 ST 학습', st, '학습 카드·답안 작성 기록'),
                const Divider(height: 24),
                _sourceRow(theme, '📍 HQ 일상', hq, '위치·외출·만남 자동'),
                const SizedBox(height: 8),
                Text('자동 이관 = 매일 23:30 KST',
                    style: theme.textTheme.bodySmall?.copyWith(color: DailyPalette.ash, fontSize: 11)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sourceRow(ThemeData theme, String label, Map<String, dynamic>? src, String fallback) {
    final hasData = src != null && src.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(hasData ? Icons.check_circle : Icons.schedule, size: 18, color: hasData ? Colors.green : DailyPalette.ash),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                hasData ? (src['summary']?.toString() ?? src.keys.take(3).join(' · ')) : fallback,
                style: theme.textTheme.bodySmall?.copyWith(color: DailyPalette.ash),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


/// Hero · v12 luminous bento + 수면 위상 중심 (사용자 명시 2026-05-01 14:32 · 공부 도메인 제거).
class _HeroToday extends StatelessWidget {
  const _HeroToday();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // 수면 위상 사다리 = plan v6.2 정합 (-30분/일 · D9 02:30 → D16 23:00)
    final phase1Start = DateTime(2026, 4, 23); // D1
    final dn = now.difference(DateTime(phase1Start.year, phase1Start.month, phase1Start.day)).inDays + 1;
    String sleepTarget;
    if (dn <= 9) {sleepTarget = '02:30';}
    else if (dn == 10) {sleepTarget = '02:00';}
    else if (dn == 11) {sleepTarget = '01:30';}
    else if (dn == 12) {sleepTarget = '01:00';}
    else if (dn == 13) {sleepTarget = '00:30';}
    else if (dn == 14) {sleepTarget = '00:00';}
    else if (dn == 15) {sleepTarget = '23:30';}
    else {sleepTarget = '23:00';}
    final wakeTarget = '+8h 후';
    final dayLabel = DateFormat('M.d EEEE', 'ko').format(now);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 32, 26, 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF6E0), Color(0xFFFFEAC4), Color(0xFFF4D9A8)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: DailyV12Radius.card,
        boxShadow: DailyV12Shadow.card(),
        border: Border.all(color: DailyV12.bronze.withValues(alpha: 0.18), width: 1),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -50, top: -50,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [DailyV12.bronzeGlow, DailyV12.bronzeGlow.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    DateFormat('yyyy.MM.dd EEEE', 'ko').format(now),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: DailyV12.bronzeDeep, letterSpacing: 1.2),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: DailyV12.bronze.withValues(alpha: 0.16),
                      borderRadius: DailyV12Radius.capsule,
                      border: Border.all(color: DailyV12.bronze.withValues(alpha: 0.55)),
                    ),
                    child: Text(
                      '오늘 $dayLabel',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: DailyV12.bronzeDeep, letterSpacing: 0.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '수면 위상 정진',
                style: TextStyle(fontSize: 14, color: DailyV12.bronzeDeep, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Color(0xFFB87020), Color(0xFF824A14), Color(0xFF5A3008)],
                      stops: [0, 0.55, 1.0],
                    ).createShader(rect),
                    blendMode: BlendMode.srcIn,
                    child: Text(
                      sleepTarget,
                      style: const TextStyle(
                        fontSize: 64, fontWeight: FontWeight.w900,
                        height: 0.95, letterSpacing: -2.4,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 10, bottom: 12),
                    child: Text(
                      '취침 목표',
                      style: TextStyle(fontSize: 14, color: DailyV12.ink3, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '기상 = 취침 $wakeTarget · 광노출 산책 30m',
                style: const TextStyle(fontSize: 13, color: DailyV12.ink2, height: 1.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  _badge('일상', DailyV12.bronzeDeep),
                  _badge('수면·식사·routine', DailyV12.bronze),
                  _badge('학업 = ST 앱', DailyV12.ink3),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
        ),
        child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
      );
}

// _QuickStats 폐기 (v13 재구성 시) — 진도 카드·이관 카드로 대체. 2026-05-05.
