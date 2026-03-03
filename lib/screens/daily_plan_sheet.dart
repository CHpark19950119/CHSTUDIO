import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/plan_models.dart';
import '../services/plan_service.dart';
import '../data/plan_data.dart';
import 'order/order_theme.dart';

/// ═══════════════════════════════════════════════════════════
/// DAILY PLAN SHEET — 일일 계획 생성/편집/추적
/// showModalBottomSheet(isScrollControlled: true) 로 열림
/// ═══════════════════════════════════════════════════════════

class DailyPlanSheet extends StatefulWidget {
  final String date;
  final DailyPlan? existingPlan;
  final VoidCallback? onSaved;

  const DailyPlanSheet({
    super.key,
    required this.date,
    this.existingPlan,
    this.onSaved,
  });

  /// 헬퍼: 시트를 열어주는 함수
  static Future<void> show(BuildContext context,
      {required String date, DailyPlan? plan, VoidCallback? onSaved}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          DailyPlanSheet(date: date, existingPlan: plan, onSaved: onSaved),
    );
  }

  @override
  State<DailyPlanSheet> createState() => _DailyPlanSheetState();
}

class _DailyPlanSheetState extends State<DailyPlanSheet> {
  final _ps = PlanService();
  late List<DailyTask> _tasks;
  final _memoCtrl = TextEditingController();
  final _tomorrowCtrl = TextEditingController();
  final _addTitleCtrl = TextEditingController();
  String? _yesterdayNotes;
  bool _loading = true;
  bool _dirty = false;
  String _addCategory = 'general';
  String _addPriority = 'should';

  // 카테고리 매핑
  static const _categoryLabels = {
    'data': '자료해석',
    'lang': '언어논리',
    'sit': '상황판단',
    'econ': '경제학',
    'life': '생활',
    'general': '일반',
  };

  static const _priorityInfo = {
    'must': ('필수', Color(0xFFEF4444), Color(0xFFFDEDED)),
    'should': ('권장', Color(0xFFF5A623), Color(0xFFFFF4E0)),
    'could': ('선택', Color(0xFF94A3B8), Color(0xFFF1F5F9)),
  };

  @override
  void initState() {
    super.initState();
    _tasks = widget.existingPlan?.tasks
            .map((t) => t.copyWith())
            .toList() ??
        [];
    _memoCtrl.text = widget.existingPlan?.memo ?? '';
    _tomorrowCtrl.text = widget.existingPlan?.tomorrowNotes ?? '';
    _loadYesterdayNotes();
  }

  Future<void> _loadYesterdayNotes() async {
    final notes = await _ps.getYesterdayTomorrowNotes();
    if (mounted) setState(() {
      _yesterdayNotes = notes;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _memoCtrl.dispose();
    _tomorrowCtrl.dispose();
    _addTitleCtrl.dispose();
    super.dispose();
  }

  // ── 저장 ──
  Future<void> _save() async {
    final plan = DailyPlan(
      id: widget.existingPlan?.id ??
          'dp_${DateTime.now().millisecondsSinceEpoch}',
      date: widget.date,
      tasks: _tasks,
      memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
      tomorrowNotes: _tomorrowCtrl.text.trim().isEmpty
          ? null
          : _tomorrowCtrl.text.trim(),
      createdAt: widget.existingPlan?.createdAt,
    );
    await _ps.saveDailyPlan(plan);
    widget.onSaved?.call();
    if (mounted) Navigator.pop(context);
  }

  // ── 과제 추가 ──
  void _addTask() {
    final title = _addTitleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() {
      _tasks.add(DailyTask(
        id: 'dt_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        category: _addCategory,
        priority: _addPriority,
        order: _tasks.length,
      ));
      _addTitleCtrl.clear();
      _dirty = true;
    });
    HapticFeedback.lightImpact();
  }

  // ── 과제 완료 토글 ──
  void _toggleTask(int index) {
    setState(() {
      final t = _tasks[index];
      t.completed = !t.completed;
      t.completedAt =
          t.completed ? DateTime.now().toIso8601String() : null;
      _dirty = true;
    });
    HapticFeedback.mediumImpact();
  }

  // ── 과제 삭제 ──
  void _removeTask(int index) {
    setState(() {
      _tasks.removeAt(index);
      _dirty = true;
    });
  }

  // ── 과제 편집 ──
  void _editTask(int index) {
    final t = _tasks[index];
    final titleCtrl = TextEditingController(text: t.title);
    final estCtrl =
        TextEditingController(text: t.estimatedMin.toString());
    final actCtrl = TextEditingController(text: t.actualMin.toString());
    final reasonCtrl = TextEditingController(text: t.reason ?? '');
    String cat = t.category;
    String pri = t.priority;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          decoration: const BoxDecoration(
              color: OC.card,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(28))),
          padding: EdgeInsets.fromLTRB(
              20, 8, 20, sheetBottomPad(ctx, extra: 20)),
          child: SingleChildScrollView(
            child:
                Column(mainAxisSize: MainAxisSize.min, children: [
              sheetHandle(),
              const SizedBox(height: 8),
              const Text('과제 편집',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: OC.text1)),
              const SizedBox(height: 16),
              sheetField('과제명', titleCtrl, '과제 제목 입력'),
              // 카테고리 선택
              _buildLabel('카테고리'),
              const SizedBox(height: 4),
              Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _categoryLabels.entries.map((e) {
                    final sel = cat == e.key;
                    final c = StudyPlanData.tagColor(e.key);
                    return GestureDetector(
                      onTap: () => setLocal(() => cat = e.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color:
                              sel ? c.withOpacity(.15) : OC.cardHi,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: sel
                                  ? c.withOpacity(.4)
                                  : OC.border),
                        ),
                        child: Text(e.value,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: sel ? c : OC.text3)),
                      ),
                    );
                  }).toList()),
              const SizedBox(height: 12),
              // 우선순위 선택
              _buildLabel('우선순위'),
              const SizedBox(height: 4),
              Row(
                  children: _priorityInfo.entries.map((e) {
                final sel = pri == e.key;
                final (label, color, bg) = e.value;
                return Expanded(
                    child: GestureDetector(
                  onTap: () => setLocal(() => pri = e.key),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? bg : OC.cardHi,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: sel
                              ? color.withOpacity(.4)
                              : OC.border),
                    ),
                    child: Center(
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: sel ? color : OC.text3))),
                  ),
                ));
              }).toList()),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child:
                        sheetField('예상 시간(분)', estCtrl, '30')),
                const SizedBox(width: 12),
                Expanded(
                    child:
                        sheetField('실제 시간(분)', actCtrl, '0')),
              ]),
              if (!t.completed)
                sheetField('미완료 사유', reasonCtrl, '사유 입력 (선택)'),
              const SizedBox(height: 12),
              SizedBox(
                  width: double.infinity,
                  child: sheetBtn('저장', OC.accent, Colors.white, () {
                    setState(() {
                      _tasks[index] = t.copyWith(
                        title: titleCtrl.text.trim(),
                        category: cat,
                        priority: pri,
                        estimatedMin:
                            int.tryParse(estCtrl.text) ?? 30,
                        actualMin:
                            int.tryParse(actCtrl.text) ?? 0,
                        reason: reasonCtrl.text.trim().isEmpty
                            ? null
                            : reasonCtrl.text.trim(),
                      );
                      _dirty = true;
                    });
                    Navigator.pop(ctx);
                  })),
            ]),
          ),
        );
      }),
    );
  }

  Widget _buildLabel(String text) => Align(
      alignment: Alignment.centerLeft,
      child: Text(text,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: OC.text2)));

  // ═══ BUILD ═══
  @override
  Widget build(BuildContext context) {
    final dateObj = DateTime.tryParse(widget.date) ?? DateTime.now();
    final dateLabel =
        DateFormat('M월 d일 EEEE', 'ko').format(dateObj);
    final completed = _tasks.where((t) => t.completed).length;
    final total = _tasks.length;
    final rate = total > 0 ? completed / total : 0.0;

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: const BoxDecoration(
          color: OC.bg,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(children: [
        // ── Handle + Header ──
        Container(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          decoration: BoxDecoration(
            color: OC.card,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(children: [
            sheetHandle(),
            const SizedBox(height: 8),
            Row(children: [
              // 날짜 + 진행률
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(dateLabel,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: OC.text1)),
                    const SizedBox(height: 2),
                    Text(
                        total > 0
                            ? '$completed/$total 완료 · ${(rate * 100).round()}%'
                            : '과제를 추가해보세요',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: OC.text3)),
                  ])),
              // 원형 진행률
              if (total > 0)
                SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(alignment: Alignment.center, children: [
                      SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            value: rate,
                            strokeWidth: 4,
                            backgroundColor: OC.border,
                            valueColor: AlwaysStoppedAnimation(
                                rate >= 0.8
                                    ? OC.success
                                    : rate >= 0.5
                                        ? OC.amber
                                        : OC.error),
                          )),
                      Text('${(rate * 100).round()}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: rate >= 0.8
                                  ? OC.success
                                  : rate >= 0.5
                                      ? OC.amber
                                      : OC.error)),
                    ])),
            ]),
            // 시간 통계
            if (total > 0) ...[
              const SizedBox(height: 8),
              Row(children: [
                _miniStat('예상',
                    _formatMin(_tasks.fold(0, (s, t) => s + t.estimatedMin)),
                    OC.accent),
                const SizedBox(width: 16),
                _miniStat('실제',
                    _formatMin(_tasks.fold(0, (s, t) => s + t.actualMin)),
                    OC.success),
                const SizedBox(width: 16),
                _miniStat('필수 달성',
                    '${(_mustRate() * 100).round()}%',
                    _mustRate() >= 1.0 ? OC.success : OC.error),
              ]),
            ],
          ]),
        ),

        // ── Body ──
        Expanded(
          child: _loading
              ? const Center(
                  child:
                      CircularProgressIndicator(color: OC.accent))
              : ListView(
                  padding:
                      const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  children: [
                    // 어제의 내일 준비 노트
                    if (_yesterdayNotes != null &&
                        _yesterdayNotes!.isNotEmpty)
                      _yesterdayNotesCard(),

                    // 필수 과제
                    _taskSection('must'),
                    // 권장 과제
                    _taskSection('should'),
                    // 선택 과제
                    _taskSection('could'),

                    // 메모
                    const SizedBox(height: 16),
                    _buildLabel('📝 메모'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _memoCtrl,
                      maxLines: 3,
                      onChanged: (_) => _dirty = true,
                      style: const TextStyle(
                          fontSize: 13, color: OC.text1),
                      decoration: InputDecoration(
                        hintText: '오늘의 메모...',
                        hintStyle:
                            const TextStyle(color: OC.text4),
                        filled: true,
                        fillColor: OC.card,
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: OC.border)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: OC.border)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: OC.accent)),
                      ),
                    ),

                    // 내일 준비 노트
                    const SizedBox(height: 16),
                    _buildLabel('📅 내일 준비 노트'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _tomorrowCtrl,
                      maxLines: 3,
                      onChanged: (_) => _dirty = true,
                      style: const TextStyle(
                          fontSize: 13, color: OC.text1),
                      decoration: InputDecoration(
                        hintText: '내일 해야 할 것, 준비할 것...',
                        hintStyle:
                            const TextStyle(color: OC.text4),
                        filled: true,
                        fillColor: OC.card,
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: OC.border)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: OC.border)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: OC.accent)),
                      ),
                    ),

                    const SizedBox(height: 100), // 하단 여유
                  ],
                ),
        ),

        // ── 하단: 과제 추가 + 저장 ──
        Container(
          padding: EdgeInsets.fromLTRB(
              16, 10, 16, sheetBottomPad(context, extra: 12)),
          decoration: BoxDecoration(
            color: OC.card,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(.06),
                  blurRadius: 12,
                  offset: const Offset(0, -3))
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // 과제 추가 입력
            Row(children: [
              // 카테고리 선택 버튼
              GestureDetector(
                onTap: _showCategoryPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: StudyPlanData.tagColor(_addCategory)
                        .withOpacity(.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color:
                            StudyPlanData.tagColor(_addCategory)
                                .withOpacity(.3)),
                  ),
                  child: Text(
                      _categoryLabels[_addCategory] ?? '일반',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: StudyPlanData.tagColor(
                              _addCategory))),
                ),
              ),
              const SizedBox(width: 6),
              // 우선순위 선택 버튼
              GestureDetector(
                onTap: _showPriorityPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: _priorityInfo[_addPriority]!
                        .$3,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _priorityInfo[_addPriority]!
                            .$2
                            .withOpacity(.3)),
                  ),
                  child: Text(
                      _priorityInfo[_addPriority]!.$1,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color:
                              _priorityInfo[_addPriority]!
                                  .$2)),
                ),
              ),
              const SizedBox(width: 8),
              // 제목 입력
              Expanded(
                child: TextField(
                  controller: _addTitleCtrl,
                  style: const TextStyle(
                      fontSize: 13, color: OC.text1),
                  onSubmitted: (_) => _addTask(),
                  decoration: InputDecoration(
                    hintText: '과제 추가...',
                    hintStyle:
                        const TextStyle(color: OC.text4),
                    filled: true,
                    fillColor: OC.cardHi,
                    contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: OC.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: OC.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: OC.accent)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _addTask,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: OC.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_rounded,
                      size: 20, color: Colors.white),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            // 저장 버튼
            SizedBox(
                width: double.infinity,
                child: sheetBtn(
                    '저장', OC.accent, Colors.white, _save)),
          ]),
        ),
      ]),
    );
  }

  // ═══ SUB WIDGETS ═══

  Widget _yesterdayNotesCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          OC.accent.withOpacity(.06),
          OC.accentBg.withOpacity(.5)
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OC.accent.withOpacity(.12)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Row(children: [
          const Text('📋',
              style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          const Text('어제의 내일 준비 노트',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: OC.accent)),
        ]),
        const SizedBox(height: 6),
        Text(_yesterdayNotes!,
            style: const TextStyle(
                fontSize: 12,
                color: OC.text2,
                height: 1.5)),
      ]),
    );
  }

  Widget _taskSection(String priority) {
    final filtered =
        _tasks.where((t) => t.priority == priority).toList();
    if (filtered.isEmpty && priority != 'must') {
      return const SizedBox.shrink();
    }
    final (label, color, bg) = _priorityInfo[priority]!;

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
      const SizedBox(height: 12),
      Row(children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: color.withOpacity(.2)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ),
        const SizedBox(width: 8),
        Text('${filtered.where((t) => t.completed).length}/${filtered.length}',
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: OC.text3)),
      ]),
      const SizedBox(height: 8),
      if (filtered.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OC.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: OC.border.withOpacity(.5)),
          ),
          child: Text('$label 과제가 없습니다',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, color: OC.text4)),
        )
      else
        ...filtered.map(
            (t) => _taskRow(t, _tasks.indexOf(t))),
    ]);
  }

  Widget _taskRow(DailyTask t, int index) {
    final catColor = StudyPlanData.tagColor(t.category);
    final done = t.completed;

    return Dismissible(
      key: ValueKey(t.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _removeTask(index),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: OC.error.withOpacity(.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_rounded,
            color: OC.error, size: 20),
      ),
      child: GestureDetector(
        onTap: () => _editTask(index),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: done
                ? OC.successBg
                : OC.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: done
                    ? OC.success.withOpacity(.2)
                    : OC.border.withOpacity(.5)),
          ),
          child: Row(children: [
            // 체크박스
            GestureDetector(
              onTap: () => _toggleTask(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: done ? OC.success : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      color: done
                          ? OC.success
                          : OC.text4.withOpacity(.5),
                      width: 2),
                ),
                child: done
                    ? const Icon(Icons.check_rounded,
                        size: 16, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            // 카테고리 뱃지
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: catColor.withOpacity(.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                  _categoryLabels[t.category] ?? t.category,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: catColor)),
            ),
            const SizedBox(width: 8),
            // 제목
            Expanded(
                child: Text(t.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: done ? OC.text3 : OC.text1,
                      decoration: done
                          ? TextDecoration.lineThrough
                          : null,
                    ))),
            // 시간 뱃지
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: OC.bgSub,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${t.estimatedMin}분',
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: OC.text3)),
            ),
            if (done && t.actualMin > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: OC.successBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${t.actualMin}분',
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: OC.success)),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Row(children: [
      Text('$label ',
          style: const TextStyle(
              fontSize: 10, color: OC.text4)),
      Text(value,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color)),
    ]);
  }

  String _formatMin(int min) {
    if (min >= 60) return '${min ~/ 60}시간 ${min % 60}분';
    return '${min}분';
  }

  double _mustRate() {
    final musts = _tasks.where((t) => t.priority == 'must');
    if (musts.isEmpty) return 1.0;
    return musts.where((t) => t.completed).length /
        musts.length;
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            color: OC.card,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          sheetHandle(),
          const SizedBox(height: 8),
          const Text('카테고리 선택',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: OC.text1)),
          const SizedBox(height: 16),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categoryLabels.entries.map((e) {
                final c = StudyPlanData.tagColor(e.key);
                return GestureDetector(
                  onTap: () {
                    setState(() => _addCategory = e.key);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: c.withOpacity(.1),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: c.withOpacity(.3)),
                    ),
                    child: Text(e.value,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: c)),
                  ),
                );
              }).toList()),
          SizedBox(height: sheetBottomPad(ctx)),
        ]),
      ),
    );
  }

  void _showPriorityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            color: OC.card,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          sheetHandle(),
          const SizedBox(height: 8),
          const Text('우선순위 선택',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: OC.text1)),
          const SizedBox(height: 16),
          ...['must', 'should', 'could'].map((p) {
            final (label, color, bg) = _priorityInfo[p]!;
            return GestureDetector(
              onTap: () {
                setState(() => _addPriority = p);
                Navigator.pop(ctx);
              },
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: color.withOpacity(.3)),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ),
            );
          }),
          SizedBox(height: sheetBottomPad(ctx)),
        ]),
      ),
    );
  }
}
