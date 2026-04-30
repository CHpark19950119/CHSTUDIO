// DAILY 오늘 탭 — 상품급 전면개편 (사용자 지시 2026-04-28 23:18).
// Hero (날짜·Phase·D-day) + Quick stats + 오늘의 순서 + 오늘 일정.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/app.dart';
import '../../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/routine_checklist.dart';
import '../widgets/today_timeline.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => await Future.delayed(const Duration(milliseconds: 300)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              const _HeroToday(),
              const SizedBox(height: DailySpace.lg),
              const _QuickStats(),
              const SizedBox(height: DailySpace.lg),
              SectionHeader(title: '오늘의 순서', accent: theme.colorScheme.primary),
              const SizedBox(height: DailySpace.sm),
              const RoutineChecklist(),
              const SizedBox(height: DailySpace.lg),
              SectionHeader(title: '오늘 일정', accent: DailyPalette.gold),
              const SizedBox(height: DailySpace.sm),
              const TodayTimeline(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hero · v12 luminous bento (cream/bronze gradient + warm glow + bronze gradient text).
/// 사용자 명시 (2026-05-01 02:08): DAILY 디자인 전면 v12 적용.
class _HeroToday extends StatelessWidget {
  const _HeroToday();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final exam = DateTime(2026, 7, 18);
    final dDay = exam.difference(DateTime(now.year, now.month, now.day)).inDays;
    final phase1Start = DateTime(2026, 4, 25);
    final phaseDay = now.difference(phase1Start).inDays + 1;

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
                      'Phase 1 · D$phaseDay/14',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: DailyV12.bronzeDeep, letterSpacing: 0.4),
                    ),
                  ),
                ],
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
                      'D-$dDay',
                      style: const TextStyle(
                        fontSize: 80, fontWeight: FontWeight.w900,
                        height: 0.95, letterSpacing: -3.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                phaseDay <= 7 ? '오늘 취침/기상 = 08:30 / 01:30' : '오늘 취침/기상 = 07:30 / 23:30',
                style: const TextStyle(fontSize: 13, color: DailyV12.ink2, height: 1.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  _badge('Phase 1', DailyV12.bronzeDeep),
                  _badge('시험 D-$dDay', DailyV12.bronze),
                  _badge('plan v6.2', DailyV12.ink2),
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

/// Quick stats — 4-grid (수면·식사·외출·Detox).
class _QuickStats extends StatelessWidget {
  const _QuickStats();

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final ref = FirebaseFirestore.instance.doc('users/$kUid/life_logs/$today');
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (ctx, snap) {
        final data = snap.data?.data() ?? {};
        final wake = (data['wake'] as Map?)?['time']?.toString() ?? '—';
        final sleep = (data['sleep'] as Map?)?['time']?.toString() ?? '—';
        final mealsCount = (data['meals'] as List?)?.length ?? 0;
        final outingCount = (data['outing'] as List?)?.length ?? 0;
        final mediaList = data['media'] as List?;
        final mediaTotal = mediaList?.fold<int>(0, (a, b) => a + ((b is Map ? b['duration_min'] : 0) as num? ?? 0).toInt()) ?? 0;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            StatCard(label: '기상 / 취침', value: wake, sub: '취침 $sleep', icon: Icons.wb_sunny_outlined, accent: DailyPalette.gold),
            StatCard(label: '식사', value: '$mealsCount회', sub: '오늘 등재', icon: Icons.restaurant_outlined, accent: DailyPalette.success),
            StatCard(label: '외출', value: '$outingCount회', sub: 'outing 토글', icon: Icons.directions_walk_outlined, accent: DailyPalette.info),
            StatCard(label: '미디어', value: '${mediaTotal}분', sub: '쇼츠 누적', icon: Icons.smart_display_outlined, accent: DailyPalette.craving),
          ],
        );
      },
    );
  }
}
