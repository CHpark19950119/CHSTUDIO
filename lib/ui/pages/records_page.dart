import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/app.dart';
import '../../theme/theme.dart';
import '../widgets/common.dart';

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
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            HeroCard(
              title: '기록',
              subtitle: DateFormat('yyyy년 M월', 'ko').format(_anchor),
              icon: Icons.calendar_month_outlined,
            ),
            const SizedBox(height: DailySpace.lg),
            SectionHeader(title: '월간 달력', accent: theme.colorScheme.primary),
            const SizedBox(height: DailySpace.sm),
            _monthNav(theme),
            const SizedBox(height: DailySpace.sm),
            _calendarGrid(theme),
            const SizedBox(height: DailySpace.lg),
            if (_selected != null) ...[
              SectionHeader(
                title: DateFormat('M월 d일 EEEE', 'ko').format(_selected!),
                accent: DailyPalette.gold,
              ),
              const SizedBox(height: DailySpace.sm),
              _DayDetail(date: _selected!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _monthNav(ThemeData theme) {
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
            style: theme.textTheme.titleMedium,
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

  Widget _calendarGrid(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
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
            color: isDark ? DailyPalette.cardDark : DailyPalette.card,
            borderRadius: BorderRadius.circular(DailySpace.radiusL),
            border: Border.all(color: isDark ? DailyPalette.lineDark : DailyPalette.line),
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
                          fontSize: 13,
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
                      return const Expanded(child: SizedBox(height: 46));
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
                          height: 46,
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
                                fontSize: 16,
                                fontWeight: (has || isToday) ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : has
                                        ? (isDark ? DailyPalette.inkDark : DailyPalette.ink)
                                        : (isDark ? DailyPalette.ashDark : DailyPalette.fog),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final key = DateFormat('yyyy-MM-dd').format(date);
    final ref = FirebaseFirestore.instance.doc('users/$kUid/life_logs/$key');
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (ctx, snap) {
        final data = snap.data?.data() ?? {};
        return Container(
          padding: const EdgeInsets.all(DailySpace.lg),
          decoration: BoxDecoration(
            color: isDark ? DailyPalette.cardDark : DailyPalette.card,
            borderRadius: BorderRadius.circular(DailySpace.radiusL),
            border: Border.all(color: isDark ? DailyPalette.lineDark : DailyPalette.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data.isEmpty)
                Text('기록 없음', style: theme.textTheme.bodyMedium)
              else
                ..._sections(data, theme),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _sections(Map<String, dynamic> data, ThemeData theme) {
    final out = <Widget>[];

    // ── 수면 카테고리 ──
    final sleepRows = <Widget>[];
    if (data['wake'] is Map) {
      final w = data['wake'] as Map;
      sleepRows.add(_row('기상', '${w['time'] ?? '—'}${w['note'] != null ? ' · ${w['note']}' : ''}'));
    }
    if (data['sleep'] is Map) {
      final s = data['sleep'] as Map;
      sleepRows.add(_row('취침', '${s['time'] ?? '—'}${s['note'] != null ? ' · ${s['note']}' : ''}'));
    }
    if (data['oversleep'] is Map) {
      final o = data['oversleep'] as Map;
      sleepRows.add(_row('늦잠', '${o['actual_wake'] ?? ''} (계획 ${o['planned_wake'] ?? ''}, +${o['deviation_min'] ?? ''}분)'));
    }
    if (data['nap'] is List) {
      for (final n in (data['nap'] as List).whereType<Map>()) {
        sleepRows.add(_row('낮잠 ${n['time'] ?? ''}',
            '~${n['wake_time'] ?? ''} (${n['duration_min'] ?? ''}분)${n['note'] != null ? ' · ${n['note']}' : ''}'));
      }
    }
    if (sleepRows.isNotEmpty) out.add(_section('🛏️ 수면', sleepRows, theme));

    // ── 식사 ──
    final mealRows = <Widget>[];
    if (data['meals'] is List) {
      for (final m in (data['meals'] as List).whereType<Map>()) {
        final start = m['start'] ?? m['time'] ?? '';
        final end = m['end'];
        final menu = m['menu']?.toString() ?? '';
        mealRows.add(_row('${start}${end != null ? '~$end' : ''}',
            '$menu${m['note'] != null ? ' · ${m['note']}' : ''}'));
      }
    }
    if (mealRows.isNotEmpty) out.add(_section('🍽️ 식사', mealRows, theme));

    // ── 외출·이동 ──
    final outRows = <Widget>[];
    if (data['outing'] is List) {
      for (final o in (data['outing'] as List).whereType<Map>()) {
        final t = o['time'] ?? '';
        final ret = o['returnHome'];
        final dest = o['destination'] ?? '';
        outRows.add(_row('${t}${ret != null ? '~$ret' : ''}',
            '$dest${o['mode'] != null ? ' · ${o['mode']}' : ''}${o['note'] != null ? ' · ${o['note']}' : ''}'));
      }
    }
    if (outRows.isNotEmpty) out.add(_section('🚶 외출', outRows, theme));

    // ── 일상 plan ── (도메인 분리: 공부·시험 = STUDY 만, 여기선 plan/일상 메모 만)
    final planRows = <Widget>[];
    if (data['events'] is List) {
      for (final e in (data['events'] as List).whereType<Map>()) {
        final tag = e['tag']?.toString() ?? '';
        if (tag == 'plan') {
          planRows.add(_row(e['time']?.toString() ?? '', e['note']?.toString() ?? ''));
        }
      }
    }
    if (planRows.isNotEmpty) out.add(_section('📋 계획·메모', planRows, theme));

    // ── 미디어 ──
    final mediaRows = <Widget>[];
    if (data['media'] is List) {
      for (final m in (data['media'] as List).whereType<Map>()) {
        mediaRows.add(_row('${m['type'] ?? ''}',
            '${m['duration_min'] ?? ''}분 (${m['start'] ?? ''}~${m['end'] ?? ''})${m['note'] != null ? ' · ${m['note']}' : ''}'));
      }
    }
    if (mediaRows.isNotEmpty) out.add(_section('📺 미디어', mediaRows, theme));

    // ── 결제 ──
    final payRows = <Widget>[];
    if (data['payments'] is List) {
      for (final p in (data['payments'] as List).whereType<Map>()) {
        payRows.add(_row('${p['time'] ?? ''}',
            '${p['place'] ?? ''} ${p['amount'] ?? ''}원 · ${p['service'] ?? ''}${p['note'] != null ? ' · ${p['note']}' : ''}'));
      }
    }
    if (payRows.isNotEmpty) out.add(_section('💳 결제', payRows, theme));

    // ── 할일 ──
    final todoRows = <Widget>[];
    if (data['todos'] is List) {
      for (final t in (data['todos'] as List).whereType<Map>()) {
        todoRows.add(_row('${t['priority'] ?? '—'}',
            '${t['task'] ?? ''}${t['from'] != null ? ' (${t['from']})' : ''}'));
      }
    }
    if (todoRows.isNotEmpty) out.add(_section('📋 할일', todoRows, theme));

    // ── 배변 ──
    final bowelRows = <Widget>[];
    if (data['bowel'] is List) {
      for (final b in (data['bowel'] as List).whereType<Map>()) {
        bowelRows.add(_row('${b['time'] ?? ''}', b['status']?.toString() ?? ''));
      }
    }
    if (bowelRows.isNotEmpty) out.add(_section('🚽 배변', bowelRows, theme));

    // ── HB 작업 events ──
    final hbRows = <Widget>[];
    if (data['events_hb'] is List) {
      for (final e in (data['events_hb'] as List).whereType<Map>()) {
        hbRows.add(_row('${e['time'] ?? ''} [${e['tag'] ?? ''}]', e['note']?.toString() ?? ''));
      }
    }
    if (hbRows.isNotEmpty) out.add(_section('🤖 HB 작업', hbRows, theme));

    // ── 심리 ──
    if (data['psych'] is Map) {
      final p = data['psych'] as Map;
      out.add(_section('🧠 심리', [_row('—', p.entries.map((e) => '${e.key}=${e.value}').join(' · '))], theme));
    }

    // ── 일반 events (위 섹션 미매칭) ──
    final etcRows = <Widget>[];
    if (data['events'] is List) {
      for (final e in (data['events'] as List).whereType<Map>()) {
        final tag = e['tag']?.toString() ?? '';
        if (!(tag.contains('study') || tag == 'focus' || tag == 'break_start' || tag == 'plan' || tag.startsWith('meal') || tag.startsWith('hygiene'))) {
          etcRows.add(_row('${e['time'] ?? ''} [$tag]', e['note']?.toString() ?? ''));
        }
      }
    }
    if (etcRows.isNotEmpty) out.add(_section('📌 기타', etcRows, theme));

    return out;
  }

  Widget _section(String title, List<Widget> rows, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? DailyPalette.paperDark : DailyPalette.paper,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? DailyPalette.lineDark : DailyPalette.line, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? DailyPalette.gold.withValues(alpha: 0.18) : DailyPalette.goldSurface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String l, String v) => Builder(
        builder: (ctx) {
          final t = Theme.of(ctx);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 92, child: Text(l, style: t.textTheme.labelMedium)),
                Expanded(child: Text(v, style: t.textTheme.bodyMedium?.copyWith(height: 1.4))),
              ],
            ),
          );
        },
      );
}
