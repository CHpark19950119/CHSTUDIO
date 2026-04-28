// Phase·목표 카드 — 현재 Phase + D-day + 일별 목표 표시.
// 사용자 지시 (2026-04-28 15:30): "Phase 와 목표를 잘 알 수 있도록 앱 개선".
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/theme.dart';
import '_card.dart';

/// Phase 1: 위상 전진 14일 (4/25 ~ 5/08, D1-D14)
/// 시험 = 7급 외무영사직 2026-07-18
const _examDate = '2026-07-18';
const _phase1Start = '2026-04-25';

class PhaseGoalCard extends StatelessWidget {
  const PhaseGoalCard({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final exam = DateTime.parse(_examDate);
    final dDay = exam.difference(DateTime(today.year, today.month, today.day)).inDays;
    final phase1Start = DateTime.parse(_phase1Start);
    final phaseDay = today.difference(phase1Start).inDays + 1; // D1 = 1
    final phase1Total = 14;

    final wakeTarget = (phaseDay <= 7) ? '08:30' : '07:30';
    final sleepTarget = (phaseDay <= 7) ? '01:30' : '23:30';

    return DailyCard(
      title: 'Phase · 목표',
      icon: Icons.flag_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8, runSpacing: 6,
            children: [
              _badge('Phase 1', DailyPalette.primary),
              _badge('D$phaseDay/$phase1Total', DailyPalette.gold),
              _badge('시험 D-$dDay', DailyPalette.error),
            ],
          ),
          const SizedBox(height: 14),
          _line('기상 타깃', wakeTarget),
          _line('취침 타깃', sleepTarget),
          _line('순공 목표', '4시간+ (Phase1 진행 중 단계 ↑)'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: DailyPalette.goldSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              phaseDay <= 7
                  ? '🌅 D1-D7 = 위상 진전 (08:30/01:30)'
                  : '🌄 D8-D14 = 위상 안정 (07:30/23:30)',
              style: const TextStyle(fontSize: 13, color: DailyPalette.ink, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color, width: 1),
        ),
        child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
      );

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(width: 96, child: Text(label, style: const TextStyle(fontSize: 13, color: DailyPalette.ash, fontWeight: FontWeight.w500))),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 14, color: DailyPalette.ink, fontWeight: FontWeight.w700))),
          ],
        ),
      );
}
