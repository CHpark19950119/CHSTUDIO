// 오늘 일정 timeline — 시간순 정리, 중복 제거, tag 한글 매핑.
// 사용자 지시 (2026-04-28 16:58 + 17:22): 그날 일정 + "지저분하지 않게".
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/app.dart';
import '../../theme/theme.dart';
import '_card.dart';

class TodayTimeline extends StatelessWidget {
  const TodayTimeline({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final ref = FirebaseFirestore.instance.doc('users/$kUid/life_logs/$today');
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (_, snap) {
        final data = snap.data?.data() ?? {};
        final entries = _collect(data);
        return DailyCard(
          title: '오늘 일정',
          icon: Icons.timeline_outlined,
          child: entries.isEmpty
              ? const Text('기록 없음', style: TextStyle(fontSize: 12, color: DailyPalette.ash))
              : Column(children: entries.map(_row).toList()),
        );
      },
    );
  }

  List<_Entry> _collect(Map<String, dynamic> data) {
    final list = <_Entry>[];

    if (data['wake'] is Map) {
      final w = data['wake'] as Map;
      final t = w['time']?.toString();
      if (t != null) list.add(_Entry(t, '🌅', '기상', null));
    }

    // 식사 — start~end 한 줄로 합침
    if (data['meals'] is List) {
      for (final m in (data['meals'] as List).whereType<Map>()) {
        final s = (m['start'] ?? m['time'])?.toString();
        final e = m['end']?.toString();
        if (s != null) {
          final timeRange = e != null ? '$s~$e' : '$s~';
          list.add(_Entry(s, '🍽️', '식사', e == null ? '진행 중' : null, displayTime: timeRange));
        }
      }
    }

    // 외출 — time~returnHome 한 줄
    if (data['outing'] is List) {
      for (final o in (data['outing'] as List).whereType<Map>()) {
        final t = o['time']?.toString();
        final r = o['returnHome']?.toString();
        if (t != null) {
          final dest = (o['destination']?.toString() ?? '').trim();
          final timeRange = r != null ? '$t~$r' : '$t~';
          list.add(_Entry(t, '🚶', '외출', dest.isEmpty ? (r == null ? '진행 중' : null) : dest, displayTime: timeRange));
        }
      }
    }

    // events — 한글 tag + dedup (같은 시각·같은 tag = 1건만)
    final seen = <String>{};
    if (data['events'] is List) {
      for (final e in (data['events'] as List).whereType<Map>()) {
        final t = e['time']?.toString();
        if (t == null) continue;
        final tag = e['tag']?.toString() ?? '';
        final key = '$t|$tag';
        if (seen.contains(key)) continue;
        seen.add(key);
        final mapping = _tagMap(tag);
        if (mapping == null) continue; // 무시 가능 tag
        final note = _cleanNote(e['note']?.toString() ?? '', tag);
        list.add(_Entry(t, mapping.$1, mapping.$2, note));
      }
    }

    if (data['payments'] is List) {
      for (final p in (data['payments'] as List).whereType<Map>()) {
        final t = p['time']?.toString();
        if (t != null) {
          final place = p['place']?.toString() ?? '';
          final amount = p['amount'];
          list.add(_Entry(t, '💳', '결제', '$place${amount != null ? ' $amount원' : ''}'));
        }
      }
    }

    if (data['sleep'] is Map) {
      final s = data['sleep'] as Map;
      final t = s['time']?.toString();
      if (t != null) list.add(_Entry(t, '🛏️', '취침', null));
    }

    list.sort((a, b) => _normalize(a.time).compareTo(_normalize(b.time)));
    return list;
  }

  String _normalize(String t) {
    if (t.contains('+')) return '24:${t.split(':').last.split('+').first}';
    return t;
  }

  /// tag → (emoji, label). null = 표시 X.
  (String, String)? _tagMap(String tag) {
    final t = tag.toLowerCase();
    if (t == 'meal_start' || t == 'meal_end') return null; // meals 배열에서 이미 표시
    if (t == 'focus' || t == 'study_start') return ('📖', '공부');
    if (t.contains('break')) return ('☕', '휴식');
    if (t.contains('hygiene') || t.contains('샤워')) return ('🚿', '샤워');
    if (t.contains('plan')) return ('📋', '계획');
    if (t.contains('date')) return ('💞', '데이트');
    return ('📌', tag);
  }

  /// note 정리 — raw "subject=...mode=..." 같은 영문 키밸류 한글화.
  String? _cleanNote(String note, String tag) {
    if (note.isEmpty) return null;
    String s = note;
    // subject=X mode=Y → "X (Y)"
    final m = RegExp(r'subject=(\S+)\s+mode=(\S+)').firstMatch(s);
    if (m != null) {
      final subject = m.group(1) ?? '';
      final mode = m.group(2) ?? '';
      s = subject.isEmpty ? mode : '$subject${mode.isNotEmpty ? ' ($mode)' : ''}';
    }
    return s.isEmpty ? null : s;
  }

  Widget _row(_Entry e) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 70,
              child: Text(e.displayTime ?? e.time,
                  style: const TextStyle(fontSize: 11, color: DailyPalette.slate, fontWeight: FontWeight.w700)),
            ),
            Text(e.emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.label, style: const TextStyle(fontSize: 13, color: DailyPalette.ink, fontWeight: FontWeight.w600)),
                  if (e.note != null && e.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(e.note!, style: const TextStyle(fontSize: 11, color: DailyPalette.ash, height: 1.3)),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Entry {
  final String time;
  final String? displayTime;
  final String emoji;
  final String label;
  final String? note;
  _Entry(this.time, this.emoji, this.label, this.note, {this.displayTime});
}
