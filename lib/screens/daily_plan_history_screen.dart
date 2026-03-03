import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/plan_models.dart';
import '../services/plan_service.dart';
import '../data/plan_data.dart';
import 'order/order_theme.dart';
import 'daily_plan_sheet.dart';

/// ═══════════════════════════════════════════════════════════
/// DAILY PLAN HISTORY — 일일 계획 기록 열람
/// 히트맵 + 통계 + 날짜별 상세 리스트
/// ═══════════════════════════════════════════════════════════

class DailyPlanHistoryScreen extends StatefulWidget {
  const DailyPlanHistoryScreen({super.key});
  @override
  State<DailyPlanHistoryScreen> createState() =>
      _DailyPlanHistoryScreenState();
}

class _DailyPlanHistoryScreenState extends State<DailyPlanHistoryScreen> {
  final _ps = PlanService();
  Map<String, DailyPlan> _plans = {};
  bool _loading = true;
  int _filterDays = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _plans = await _ps.getRecentPlans(days: _filterDays == 0 ? 365 : _filterDays);
    if (mounted) setState(() => _loading = false);
  }

  // ── 통계 계산 ──
  double get _avgRate {
    if (_plans.isEmpty) return 0;
    final rates = _plans.values.map((p) => p.completionRate);
    return rates.reduce((a, b) => a + b) / rates.length;
  }

  int get _totalCompleted =>
      _plans.values.fold(0, (s, p) => s + p.completedCount);

  int get _totalTasks =>
      _plans.values.fold(0, (s, p) => s + p.totalCount);

  int get _streak {
    final sorted = _plans.keys.toList()..sort((a, b) => b.compareTo(a));
    if (sorted.isEmpty) return 0;
    int streak = 0;
    var cur = DateTime.now();
    if (cur.hour < 4) cur = cur.subtract(const Duration(days: 1));
    cur = DateTime(cur.year, cur.month, cur.day);

    for (int i = 0; i < 365; i++) {
      final ds = DateFormat('yyyy-MM-dd').format(cur);
      if (_plans.containsKey(ds)) {
        streak++;
        cur = cur.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OC.bg,
      appBar: AppBar(
        backgroundColor: OC.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              size: 20, color: OC.text1),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('계획 기록',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: OC.text1)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: OC.accent))
          : RefreshIndicator(
              onRefresh: _load,
              color: OC.accent,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  _summaryStats(),
                  const SizedBox(height: 16),
                  _heatmapSection(),
                  const SizedBox(height: 16),
                  _filterChips(),
                  const SizedBox(height: 16),
                  ..._dayDetailList(),
                ],
              ),
            ),
    );
  }

  // ═══ SUMMARY STATS ═══
  Widget _summaryStats() {
    final avgPct = (_avgRate * 100).round();
    final avgColor = avgPct >= 80
        ? OC.success
        : avgPct >= 50
            ? OC.amber
            : OC.error;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: OC.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: OC.border.withOpacity(.5)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Row(children: [
        // 평균 완료율 원형
        SizedBox(
          width: 64,
          height: 64,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: _avgRate,
                strokeWidth: 5,
                backgroundColor: OC.border,
                valueColor: AlwaysStoppedAnimation(avgColor),
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$avgPct',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: avgColor)),
              const Text('%',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: OC.text4)),
            ]),
          ]),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(children: [
            _statRow('완료 과제', '$_totalCompleted / $_totalTasks'),
            const SizedBox(height: 8),
            _statRow('기록 일수', '${_plans.length}일'),
            const SizedBox(height: 8),
            _statRow('연속 기록', '$_streak일'),
          ]),
        ),
      ]),
    );
  }

  Widget _statRow(String label, String value) {
    return Row(children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: OC.text3)),
      const Spacer(),
      Text(value,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: OC.text1)),
    ]);
  }

  // ═══ HEATMAP ═══
  Widget _heatmapSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: OC.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: OC.border.withOpacity(.5)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Row(children: [
          const Icon(Icons.calendar_month_rounded,
              size: 18, color: OC.accent),
          const SizedBox(width: 8),
          const Text('달성률 히트맵',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: OC.text1)),
        ]),
        const SizedBox(height: 14),
        _buildHeatmap(),
        const SizedBox(height: 10),
        // 범례
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _legendDot(OC.border, '없음'),
          const SizedBox(width: 12),
          _legendDot(const Color(0xFFEF4444).withOpacity(.4), '<50%'),
          const SizedBox(width: 12),
          _legendDot(const Color(0xFFF5A623).withOpacity(.6), '50-80%'),
          const SizedBox(width: 12),
          _legendDot(const Color(0xFF34C759).withOpacity(.7), '80%+'),
        ]),
      ]),
    );
  }

  Widget _buildHeatmap() {
    // 지난 N일을 7열(월~일) 그리드로 표시
    final days = _filterDays == 0 ? 90 : _filterDays;
    final today = DateTime.now();
    final cells = <Widget>[];

    // 요일 헤더
    for (final d in ['월', '화', '수', '목', '금', '토', '일']) {
      cells.add(Center(
          child: Text(d,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: OC.text4))));
    }

    // 시작일을 월요일로 맞추기
    var start = today.subtract(Duration(days: days));
    while (start.weekday != DateTime.monday) {
      start = start.subtract(const Duration(days: 1));
    }

    for (var d = start;
        !d.isAfter(today);
        d = d.add(const Duration(days: 1))) {
      final ds = DateFormat('yyyy-MM-dd').format(d);
      final plan = _plans[ds];
      final isToday = d.year == today.year &&
          d.month == today.month &&
          d.day == today.day;

      Color cellColor;
      if (plan == null) {
        cellColor = OC.border.withOpacity(0.3);
      } else {
        final rate = plan.completionRate;
        if (rate >= 0.8) {
          cellColor = const Color(0xFF34C759).withOpacity(.7);
        } else if (rate >= 0.5) {
          cellColor = const Color(0xFFF5A623).withOpacity(.6);
        } else {
          cellColor = const Color(0xFFEF4444).withOpacity(.4);
        }
      }

      cells.add(GestureDetector(
        onTap: plan != null
            ? () => DailyPlanSheet.show(context,
                date: ds,
                plan: plan,
                onSaved: _load)
            : null,
        child: Container(
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: cellColor,
            borderRadius: BorderRadius.circular(4),
            border: isToday
                ? Border.all(color: OC.accent, width: 1.5)
                : null,
          ),
        ),
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1,
      children: cells,
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: OC.text4)),
    ]);
  }

  // ═══ FILTER CHIPS ═══
  Widget _filterChips() {
    final options = [
      (7, '7일'),
      (30, '30일'),
      (90, '90일'),
      (0, '전체'),
    ];
    return Row(
        children: options.map((o) {
      final sel = _filterDays == o.$1;
      return Expanded(
          child: GestureDetector(
        onTap: () {
          setState(() => _filterDays = o.$1);
          _load();
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sel ? OC.accentBg : OC.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color:
                    sel ? OC.accent.withOpacity(.3) : OC.border),
          ),
          child: Center(
              child: Text(o.$2,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: sel ? OC.accent : OC.text3))),
        ),
      ));
    }).toList());
  }

  // ═══ DAY DETAIL LIST ═══
  List<Widget> _dayDetailList() {
    if (_plans.isEmpty) {
      return [
        const SizedBox(height: 40),
        Center(
          child: Column(children: [
            const Text('📭', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            const Text('기록된 계획이 없습니다',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: OC.text3)),
            const SizedBox(height: 4),
            const Text('오늘의 계획을 세워보세요!',
                style: TextStyle(
                    fontSize: 12, color: OC.text4)),
          ]),
        ),
      ];
    }

    final sorted = _plans.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return sorted.map((entry) {
      final date = entry.key;
      final plan = entry.value;
      return _dayCard(date, plan);
    }).toList();
  }

  Widget _dayCard(String date, DailyPlan plan) {
    final dateObj = DateTime.tryParse(date) ?? DateTime.now();
    String dateLabel;
    try {
      dateLabel = DateFormat('M/d (E)', 'ko').format(dateObj);
    } catch (_) {
      dateLabel = '${dateObj.month}/${dateObj.day}';
    }
    final rate = plan.completionRate;
    final rateColor = rate >= 0.8
        ? OC.success
        : rate >= 0.5
            ? OC.amber
            : OC.error;

    return GestureDetector(
      onTap: () => DailyPlanSheet.show(context,
          date: date,
          plan: plan,
          onSaved: _load),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: OC.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: OC.border.withOpacity(.5)),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // 헤더: 날짜 + 진행률
          Row(children: [
            Text(dateLabel,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: OC.text1)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: rateColor.withOpacity(.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${(rate * 100).round()}%',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: rateColor)),
            ),
          ]),
          const SizedBox(height: 8),
          // 진행바
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: rate,
              backgroundColor: OC.border,
              valueColor: AlwaysStoppedAnimation(rateColor),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          // 과제 요약
          Row(children: [
            Text('${plan.completedCount}/${plan.totalCount} 완료',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: OC.text2)),
            const SizedBox(width: 12),
            if (plan.totalEstimatedMin > 0)
              Text('예상 ${_fmtMin(plan.totalEstimatedMin)}',
                  style: const TextStyle(
                      fontSize: 10, color: OC.text3)),
            if (plan.totalActualMin > 0) ...[
              const SizedBox(width: 8),
              Text('실제 ${_fmtMin(plan.totalActualMin)}',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: OC.success)),
            ],
          ]),
          // 과제 목록 (최대 5개)
          const SizedBox(height: 8),
          ...plan.tasks.take(5).map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(children: [
                  Icon(
                    t.completed
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 14,
                    color: t.completed ? OC.success : OC.text4,
                  ),
                  const SizedBox(width: 6),
                  // 카테고리
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: StudyPlanData.tagColor(t.category)
                          .withOpacity(.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                        _catLabel(t.category),
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: StudyPlanData.tagColor(
                                t.category))),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(t.title,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: t.completed
                                  ? OC.text3
                                  : OC.text1,
                              decoration: t.completed
                                  ? TextDecoration.lineThrough
                                  : null),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                ]),
              )),
          if (plan.tasks.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('+${plan.tasks.length - 5}개 더보기',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: OC.accent)),
            ),
          // 메모 스니펫
          if (plan.memo != null && plan.memo!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('📝 ${plan.memo}',
                style: const TextStyle(
                    fontSize: 10,
                    color: OC.text3,
                    fontStyle: FontStyle.italic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ]),
      ),
    );
  }

  String _fmtMin(int min) {
    if (min >= 60) return '${min ~/ 60}h ${min % 60}m';
    return '${min}분';
  }

  String _catLabel(String cat) {
    const labels = {
      'data': '자료',
      'lang': '언어',
      'sit': '상판',
      'econ': '경제',
      'life': '생활',
      'general': '일반',
    };
    return labels[cat] ?? cat;
  }
}
