// DAILY 기록 탭 — v13 재구성 (사용자 5/5 02:33 + 05:01 명시)
// 월별 캘린더 + 선택일 통합 카드. ST·HQ 자동 이관 데이터 + self_care + 학업 진도 일괄 표시.
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
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  void _shiftMonth(int delta) {
    setState(() {
      _focused = DateTime(_focused.year, _focused.month + delta, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            _MonthHeader(focused: _focused, onPrev: () => _shiftMonth(-1), onNext: () => _shiftMonth(1)),
            const SizedBox(height: DailySpace.md),
            _CalendarGrid(
              focused: _focused,
              selected: _selected,
              onSelect: (d) => setState(() => _selected = d),
            ),
            const SizedBox(height: DailySpace.lg),
            SectionHeader(
              title: DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(_selected),
              accent: DailyPalette.gold,
            ),
            const SizedBox(height: DailySpace.sm),
            _DayDetailCard(date: _selected),
          ],
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final DateTime focused;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _MonthHeader({required this.focused, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
        Expanded(
          child: Center(
            child: Text(
              DateFormat('yyyy년 M월', 'ko_KR').format(focused),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime focused;
  final DateTime selected;
  final void Function(DateTime) onSelect;

  const _CalendarGrid({required this.focused, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(focused.year, focused.month, 1);
    final firstWeekday = firstOfMonth.weekday % 7; // 일요일=0
    final daysInMonth = DateTime(focused.year, focused.month + 1, 0).day;
    final today = DateTime.now();
    final monthKey = DateFormat('yyyy-MM').format(focused);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users/$kUid/daily_log')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: '$monthKey-01')
          .where(FieldPath.documentId, isLessThan: '$monthKey-32')
          .snapshots(),
      builder: (context, snap) {
        final summary = <int, _DaySummary>{};
        for (final doc in snap.data?.docs ?? []) {
          final id = doc.id; // yyyy-MM-dd
          final day = int.tryParse(id.split('-').last);
          if (day == null) continue;
          summary[day] = _DaySummary.fromMap(doc.data() as Map<String, dynamic>);
        }

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const ['일', '월', '화', '수', '목', '금', '토']
                  .map((w) => Expanded(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(w, style: TextStyle(fontWeight: FontWeight.w600, color: DailyPalette.ash, fontSize: 12)),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            ..._buildWeeks(firstWeekday, daysInMonth, today, summary),
          ],
        );
      },
    );
  }

  List<Widget> _buildWeeks(int firstWeekday, int daysInMonth, DateTime today, Map<int, _DaySummary> summary) {
    final weeks = <Widget>[];
    var day = 1;
    final totalCells = ((firstWeekday + daysInMonth) / 7).ceil() * 7;

    for (var w = 0; w < totalCells / 7; w++) {
      final cells = <Widget>[];
      for (var d = 0; d < 7; d++) {
        final cellIndex = w * 7 + d;
        if (cellIndex < firstWeekday || day > daysInMonth) {
          cells.add(const Expanded(child: SizedBox(height: 56)));
        } else {
          final cellDate = DateTime(focused.year, focused.month, day);
          final isToday = today.year == cellDate.year && today.month == cellDate.month && today.day == cellDate.day;
          final isSelected = selected.year == cellDate.year && selected.month == cellDate.month && selected.day == cellDate.day;
          final s = summary[day];
          cells.add(Expanded(child: _DayCell(date: cellDate, isToday: isToday, isSelected: isSelected, summary: s, onTap: () => onSelect(cellDate))));
          day++;
        }
      }
      weeks.add(Row(children: cells));
    }
    return weeks;
  }
}

class _DaySummary {
  final double studyHours;
  final bool hasSelfCare;
  final bool hasDiary;
  final bool hasImported;

  _DaySummary({required this.studyHours, required this.hasSelfCare, required this.hasDiary, required this.hasImported});

  factory _DaySummary.fromMap(Map<String, dynamic> m) {
    final progress = m['study_progress'] as Map<String, dynamic>? ?? {};
    final t1 = (progress['t1'] as Map?)?['actual_min'] as int? ?? 0;
    final t2 = (progress['t2'] as Map?)?['actual_min'] as int? ?? 0;
    final t3 = (progress['t3'] as Map?)?['actual_min'] as int? ?? 0;
    final selfCare = m['self_care'] as Map?;
    final diary = m['diary'] as Map?;
    return _DaySummary(
      studyHours: (t1 + t2 + t3) / 60.0,
      hasSelfCare: selfCare != null && (selfCare['records'] as List?)?.isNotEmpty == true,
      hasDiary: diary != null && (diary['text']?.toString().isNotEmpty ?? false),
      hasImported: m['imported_st'] != null || m['imported_hq'] != null,
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final _DaySummary? summary;
  final VoidCallback onTap;

  const _DayCell({required this.date, required this.isToday, required this.isSelected, required this.summary, required this.onTap});

  Color _dotColor(double hours) {
    if (hours >= 8) return Colors.green;
    if (hours >= 4) return DailyPalette.gold;
    if (hours > 0) return DailyPalette.warn;
    return DailyPalette.line;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = summary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? DailyPalette.goldSurface : null,
          borderRadius: BorderRadius.circular(10),
          border: isToday ? Border.all(color: DailyPalette.gold, width: 1.5) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isToday || isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? DailyPalette.gold : DailyPalette.ink,
              ),
            ),
            const SizedBox(height: 3),
            if (s != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (s.studyHours > 0)
                    Container(width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(color: _dotColor(s.studyHours), shape: BoxShape.circle)),
                  if (s.hasDiary)
                    Container(width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
                  if (s.hasSelfCare)
                    Container(width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: const BoxDecoration(color: Colors.pinkAccent, shape: BoxShape.circle)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DayDetailCard extends StatelessWidget {
  final DateTime date;
  const _DayDetailCard({required this.date});

  String _key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users/$kUid/daily_log').doc(_key(date)).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        if (data == null || data.isEmpty) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: DailyPalette.line),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text('기록 없음', style: theme.textTheme.bodyMedium?.copyWith(color: DailyPalette.ash)),
              ),
            ),
          );
        }
        final habits = data['habits'] as Map<String, dynamic>? ?? {};
        final progress = data['study_progress'] as Map<String, dynamic>? ?? {};
        final selfCare = data['self_care'] as Map<String, dynamic>? ?? {};
        final diary = data['diary'] as Map<String, dynamic>? ?? {};
        final st = data['imported_st'] as Map<String, dynamic>?;
        final hq = data['imported_hq'] as Map<String, dynamic>?;

        final t1 = (progress['t1'] as Map?)?['actual_min'] as int? ?? 0;
        final t2 = (progress['t2'] as Map?)?['actual_min'] as int? ?? 0;
        final t3 = (progress['t3'] as Map?)?['actual_min'] as int? ?? 0;
        final totalH = ((t1 + t2 + t3) / 60.0).toStringAsFixed(1);

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
                _row(theme, '📚', '학업', '$totalH h (T1 ${t1}m · T2 ${t2}m · T3 ${t3}m)'),
                if (habits.isNotEmpty) _row(theme, '🌅', '기상·수면',
                    '${habits['wake_time'] ?? '-'} 기상 / ${habits['sleep_time'] ?? '-'} 취침'),
                if ((selfCare['records'] as List?)?.isNotEmpty == true)
                  _row(theme, '💗', 'self_care',
                      '${(selfCare['records'] as List).length}회 (주간 ${selfCare['weekly_count'] ?? 0})'),
                if (st != null) _row(theme, '🎓', 'ST 학습', _summarize(st)),
                if (hq != null) _row(theme, '📍', 'HQ 일상', _summarize(hq)),
                if (diary.isNotEmpty && (diary['text']?.toString().isNotEmpty ?? false))
                  _row(theme, '📝', '일기', diary['text'].toString()),
              ],
            ),
          ),
        );
      },
    );
  }

  String _summarize(Map<String, dynamic> m) {
    final summary = m['summary'];
    if (summary != null) return summary.toString();
    final keys = m.keys.where((k) => !k.startsWith('_') && k != 'pulled_at').take(3);
    return keys.join(' · ');
  }

  Widget _row(ThemeData theme, String emoji, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: DailyPalette.ash, fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
