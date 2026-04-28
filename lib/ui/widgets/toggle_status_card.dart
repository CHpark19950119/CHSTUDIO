// 홈 — 진행 중 토글 상태 카드 (외출·식사 + study session).
// 사용자 직접 토글 + HB CF q=toggle 둘 다 같은 Firestore state 보임.
// 사용자 지시 (2026-04-28 13:58): "토글을 너가 수정할 수 있게 UI 개편".
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/app.dart';
import '../../theme/theme.dart';
import '../../data/auto_record_service.dart';
import '_card.dart';

class ToggleStatusCard extends StatelessWidget {
  const ToggleStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final ref = FirebaseFirestore.instance.doc('users/$kUid/life_logs/$today');
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (_, snap) {
        final data = snap.data?.data() ?? {};
        return DailyCard(
          title: '진행 토글',
          icon: Icons.toggle_on_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ToggleRow(
                label: '외출',
                isActive: _isLastOpen(data['outing'], 'returnHome'),
                lastTime: _lastStart(data['outing'], 'time'),
                onToggle: () => AutoRecordService.toggleOuting(),
              ),
              const SizedBox(height: 6),
              _ToggleRow(
                label: '식사',
                isActive: _isLastOpen(data['meals'], 'end'),
                lastTime: _lastStart(data['meals'], 'start'),
                onToggle: () => AutoRecordService.toggleMeal(),
              ),
            ],
          ),
        );
      },
    );
  }

  static bool _isLastOpen(dynamic list, String endKey) {
    if (list is! List || list.isEmpty) return false;
    final last = list.last;
    if (last is! Map) return false;
    return last[endKey] == null;
  }

  static String? _lastStart(dynamic list, String startKey) {
    if (list is! List || list.isEmpty) return null;
    final last = list.last;
    if (last is! Map) return null;
    return last[startKey]?.toString();
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool isActive;
  final String? lastTime;
  final VoidCallback onToggle;

  const _ToggleRow({
    required this.label,
    required this.isActive,
    required this.lastTime,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? DailyPalette.goldSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? DailyPalette.gold : DailyPalette.line,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 20,
              color: isActive ? DailyPalette.gold : DailyPalette.ash,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: DailyPalette.ink)),
                  if (isActive && lastTime != null)
                    Text('진행 중 · $lastTime~', style: const TextStyle(fontSize: 11, color: DailyPalette.ash))
                  else if (lastTime != null)
                    Text('마지막 종료', style: const TextStyle(fontSize: 11, color: DailyPalette.ash))
                  else
                    const Text('미시작', style: TextStyle(fontSize: 11, color: DailyPalette.ash)),
                ],
              ),
            ),
            FilledButton(
              onPressed: onToggle,
              style: FilledButton.styleFrom(
                backgroundColor: isActive ? DailyPalette.error : DailyPalette.primary,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                minimumSize: const Size(0, 32),
              ),
              child: Text(isActive ? '종료' : '시작', style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
