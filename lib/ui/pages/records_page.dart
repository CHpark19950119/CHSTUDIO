import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/app.dart';
import '../../theme/theme.dart';

/// 기록 탭 = 월간 캘린더 + 선택 날짜 상세
class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  DateTime _anchor = DateTime.now();
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    _selected = DateTime(_anchor.year, _anchor.month, _anchor.day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DailyPalette.paper,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          children: [
            const Text('기록', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: DailyPalette.ink)),
            const SizedBox(height: 4),
            Text(DateFormat('yyyy년 M월', 'ko').format(_anchor),
                style: const TextStyle(fontSize: 12, color: DailyPalette.ash)),
            const SizedBox(height: DailySpace.lg),
            _monthNav(),
            const SizedBox(height: DailySpace.md),
            _calendarGrid(),
            const SizedBox(height: DailySpace.lg),
            if (_selected != null) _DayDetail(date: _selected!),
          ],
        ),
      ),
    );
  }

  Widget _monthNav() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(() {
            _anchor = DateTime(_anchor.year, _anchor.month - 1, 1);
          }),
        ),
        Expanded(
          child: Text(
            DateFormat('yyyy년 M월', 'ko').format(_anchor),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DailyPalette.ink),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => setState(() {
            _anchor = DateTime(_anchor.year, _anchor.month + 1, 1);
          }),
        ),
      ],
    );
  }

  Widget _calendarGrid() {
    final firstDay = DateTime(_anchor.year, _anchor.month, 1);
    final daysInMonth = DateTime(_anchor.year, _anchor.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7;  // 일=0, 월=1, ..., 토=6

    // 기간 범위 쿼리
    final startDate = DateFormat('yyyy-MM-dd').format(DateTime(_anchor.year, _anchor.month, 1));
    final endDate = DateFormat('yyyy-MM-dd').format(DateTime(_anchor.year, _anchor.month + 1, 0));

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(kUid).collection('life_logs')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDate)
          .where(FieldPath.documentId, isLessThanOrEqualTo: endDate)
          .snapshots(),
      builder: (ctx, snap) {
        final hasData = <String, bool>{};
        for (final d in snap.data?.docs ?? []) {
          final data = d.data();
          hasData[d.id] = data.isNotEmpty;
        }

        return Container(
          padding: const EdgeInsets.all(DailySpace.md),
          decoration: BoxDecoration(
            color: DailyPalette.card,
            borderRadius: BorderRadius.circular(DailySpace.radiusL),
            border: Border.all(color: DailyPalette.line),
          ),
          child: Column(
            children: [
              Row(
                children: const ['일', '월', '화', '수', '목', '금', '토'].asMap().entries.map((e) {
                  return Expanded(
                    child: Center(
                      child: Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: e.key == 0 ? DailyPalette.error : (e.key == 6 ? DailyPalette.info : DailyPalette.ash),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              ...List.generate((startWeekday + daysInMonth + 6) ~/ 7, (weekIdx) {
                return Row(
                  children: List.generate(7, (col) {
                    final cellIdx = weekIdx * 7 + col;
                    final dayNum = cellIdx - startWeekday + 1;
                    if (dayNum < 1 || dayNum > daysInMonth) {
                      return const Expanded(child: SizedBox(height: 38));
                    }
                    final date = DateTime(_anchor.year, _anchor.month, dayNum);
                    final key = DateFormat('yyyy-MM-dd').format(date);
                    final has = hasData[key] ?? false;
                    final isToday = _isSameDay(date, DateTime.now());
                    final isSelected = _selected != null && _isSameDay(date, _selected!);
                    return Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selected = date),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 38,
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? DailyPalette.primary
                                : isToday
                                    ? DailyPalette.goldSurface
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: has && !isSelected ? Border.all(color: DailyPalette.gold, width: 1) : null,
                          ),
                          child: Center(
                            child: Text(
                              '$dayNum',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: (has || isToday) ? FontWeight.w700 : FontWeight.w400,
                                color: isSelected
                                    ? Colors.white
                                    : has
                                        ? DailyPalette.ink
                                        : DailyPalette.fog,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayDetail extends StatelessWidget {
  final DateTime date;
  const _DayDetail({required this.date});

  @override
  Widget build(BuildContext context) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    final ref = FirebaseFirestore.instance.doc('users/$kUid/life_logs/$key');
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (ctx, snap) {
        final data = snap.data?.data() ?? {};
        return Container(
          padding: const EdgeInsets.all(DailySpace.lg),
          decoration: BoxDecoration(
            color: DailyPalette.card,
            borderRadius: BorderRadius.circular(DailySpace.radiusL),
            border: Border.all(color: DailyPalette.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat('M월 d일 EEEE', 'ko').format(date),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: DailyPalette.ink)),
              const SizedBox(height: 10),
              if (data.isEmpty)
                const Text('기록 없음', style: TextStyle(fontSize: 12, color: DailyPalette.ash))
              else
                ..._rows(data),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _rows(Map<String, dynamic> data) {
    final widgets = <Widget>[];

    // 기상 / 취침
    if (data['wake'] is Map) {
      final w = data['wake'] as Map;
      widgets.add(_row('기상', '${w['time'] ?? '—'}${w['note'] != null ? ' · ${w['note']}' : ''}'));
    }
    if (data['sleep'] is Map) {
      final s = data['sleep'] as Map;
      widgets.add(_row('취침', '${s['time'] ?? '—'}${s['note'] != null ? ' · ${s['note']}' : ''}'));
    }

    // 늦잠
    if (data['oversleep'] is Map) {
      final o = data['oversleep'] as Map;
      widgets.add(_row('늦잠', '${o['actual_wake'] ?? ''} (계획 ${o['planned_wake'] ?? ''}, +${o['deviation_min'] ?? ''}분)'));
    }

    // 낮잠
    if (data['nap'] is List) {
      for (final n in (data['nap'] as List).whereType<Map>()) {
        widgets.add(_row('낮잠 ${n['time'] ?? ''}',
            '~${n['wake_time'] ?? ''} (${n['duration_min'] ?? ''}분)${n['note'] != null ? ' · ${n['note']}' : ''}'));
      }
    }

    // 식사
    if (data['meals'] is List) {
      for (final m in (data['meals'] as List).whereType<Map>()) {
        final start = m['start'] ?? m['time'] ?? '';
        final end = m['end'];
        final menu = m['menu']?.toString() ?? '';
        widgets.add(_row('식사 $start${end != null ? '~$end' : ''}',
            '$menu${m['note'] != null ? ' · ${m['note']}' : ''}'));
      }
    }

    // 외출
    if (data['outing'] is List) {
      for (final o in (data['outing'] as List).whereType<Map>()) {
        final t = o['time'] ?? '';
        final ret = o['returnHome'];
        final dest = o['destination'] ?? '';
        widgets.add(_row('외출 $t${ret != null ? '~$ret' : ''}',
            '$dest${o['mode'] != null ? ' · ${o['mode']}' : ''}${o['note'] != null ? ' · ${o['note']}' : ''}'));
      }
    }

    // 배변
    if (data['bowel'] is List) {
      for (final b in (data['bowel'] as List).whereType<Map>()) {
        widgets.add(_row('배변 ${b['time'] ?? ''}', b['status']?.toString() ?? ''));
      }
    }

    // 공부 (legacy)
    if (data['study'] is List) {
      for (final s in (data['study'] as List).whereType<Map>()) {
        widgets.add(_row('공부 ${s['time'] ?? ''}',
            '${s['subject'] ?? ''} · ${s['duration_min'] ?? ''}분 ${s['note'] ?? ''}'));
      }
    }

    // 이벤트 (general)
    if (data['events'] is List) {
      for (final e in (data['events'] as List).whereType<Map>()) {
        widgets.add(_row('이벤트 ${e['time'] ?? ''}',
            '[${e['tag'] ?? ''}] ${e['note'] ?? ''}'));
      }
    }

    // HB 작업 events
    if (data['events_hb'] is List) {
      for (final e in (data['events_hb'] as List).whereType<Map>()) {
        widgets.add(_row('HB ${e['time'] ?? ''}',
            '[${e['tag'] ?? ''}] ${e['note'] ?? ''}'));
      }
    }

    // 미디어 (쇼츠 등)
    if (data['media'] is List) {
      for (final m in (data['media'] as List).whereType<Map>()) {
        widgets.add(_row('미디어 ${m['type'] ?? ''}',
            '${m['duration_min'] ?? ''}분 (${m['start'] ?? ''}~${m['end'] ?? ''})${m['note'] != null ? ' · ${m['note']}' : ''}'));
      }
    }

    // 결제
    if (data['payments'] is List) {
      for (final p in (data['payments'] as List).whereType<Map>()) {
        widgets.add(_row('결제 ${p['time'] ?? ''}',
            '${p['place'] ?? ''} ${p['amount'] ?? ''}원 · ${p['service'] ?? ''}${p['note'] != null ? ' · ${p['note']}' : ''}'));
      }
    }

    // 할 일
    if (data['todos'] is List) {
      for (final t in (data['todos'] as List).whereType<Map>()) {
        widgets.add(_row('할일 ${t['priority'] ?? ''}',
            '${t['task'] ?? ''}${t['from'] != null ? ' (${t['from']})' : ''}'));
      }
    }

    // 심리 / 노트
    if (data['psych'] is Map) {
      final p = data['psych'] as Map;
      widgets.add(_row('심리', p.entries.map((e) => '${e.key}=${e.value}').join(' · ')));
    }

    return widgets;
  }

  Widget _row(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 82, child: Text(l, style: const TextStyle(fontSize: 11, color: DailyPalette.ash))),
            Expanded(child: Text(v, style: const TextStyle(fontSize: 13, color: DailyPalette.ink))),
          ],
        ),
      );
}
