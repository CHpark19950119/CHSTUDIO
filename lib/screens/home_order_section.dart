part of 'home_screen.dart';

/// ═══════════════════════════════════════════════════
/// HOME — COMPASS 포탈 + 습관 큐 집중 카드 + 수험표 OCR
/// ⚠️ 네비바 충돌 금지
/// ═══════════════════════════════════════════════════
extension _HomeOrderSection on _HomeScreenState {

   // ── ORDER PORTAL — 컴팩트 칩 (앱 최상단) ──
  Widget _orderPortalChip() {
    final p1 = _orderData?.primaryGoal;
    final p2 = _orderData?.secondaryGoal;
    final nextExam = _examTickets.isNotEmpty ? _examTickets.first : null;
    final focusHabit = _orderData?.focusHabit;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const OrderScreen(),
            transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 300),
          )).then((_) => _load(playAnim: false));
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF334155).withOpacity(0.6)),
          boxShadow: [BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.08),
            blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Stack(children: [
          // 메쉬 그라디언트 장식
          Positioned(top: -30, right: -20,
            child: Container(width: 100, height: 100,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF6366F1).withOpacity(0.12),
                  Colors.transparent])))),
          Positioned(bottom: -20, left: -10,
            child: Container(width: 80, height: 80,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF22C55E).withOpacity(0.08),
                  Colors.transparent])))),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 헤더 ──
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF818CF8).withOpacity(0.2))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('🎯', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 5),
                      const Text('COMPASS', style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800,
                        color: Color(0xFF818CF8), letterSpacing: 1.5)),
                    ]),
                  ),
                  const Spacer(),
                  // 수험표 업로드 버튼
                  GestureDetector(
                    onTap: () => _uploadExamTicket(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF22C55E).withOpacity(0.2))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.document_scanner_rounded,
                          size: 13, color: const Color(0xFF4ADE80)),
                        const SizedBox(width: 4),
                        const Text('수험표', style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: Color(0xFF4ADE80))),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_ios_rounded,
                    size: 11, color: Colors.white.withOpacity(0.2)),
                ]),

                if (focusHabit != null || p1 != null || p2 != null || nextExam != null) ...[
                  const SizedBox(height: 14),

                  // ── ★ 집중 습관 (v4) — 탭하여 체크 ──
                  if (focusHabit != null) ...[
                    GestureDetector(
                      onTap: () => _toggleHabit(focusHabit),
                      child: _focusHabitRow(focusHabit),
                    ),
                    // ★ 대기 습관 제거 — 홈에는 집중만 표시
                    if (p1 != null || p2 != null || nextExam != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Container(height: 1,
                          color: Colors.white.withOpacity(0.05))),
                  ],

                  // ── ★ 오늘의 계획 진행 ──
                  if (_todayPlan != null && _todayPlan!.tasks.isNotEmpty) ...[
                    _planProgressRow(_todayPlan!),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Container(height: 1,
                        color: Colors.white.withOpacity(0.05))),
                  ],

                  // ── 1순위 목표 ──
                  if (p1 != null) _priorityGoalRow(p1, 1),
                  if (p1 != null && p2 != null) const SizedBox(height: 10),

                  // ── 2순위 목표 ──
                  if (p2 != null) _priorityGoalRow(p2, 2),

                  // ── 다가오는 시험 ──
                  if (nextExam != null) ...[
                    if (p1 != null || p2 != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Container(height: 1,
                          color: Colors.white.withOpacity(0.05))),
                    ],
                    _examTicketRow(nextExam),
                  ],
                ] else ...[
                  const SizedBox(height: 10),
                  Text('목표 · 습관 · 질서 관리', style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.35))),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ═══ ★ 집중 습관 행 (v4) ═══
  Widget _focusHabitRow(OrderHabit h) {
    final todayStr = () {
      var n = DateTime.now();
      if (n.hour < 4) n = n.subtract(const Duration(days: 1));
      return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    }();
    final done = h.isDoneOn(todayStr);
    final progress = h.settlementProgress;
    final streak = h.currentStreak;

    return Row(children: [
      // 상태 아이콘
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: done
              ? const Color(0xFF22C55E).withOpacity(0.2)
              : const Color(0xFFFBBF24).withOpacity(0.15),
          borderRadius: BorderRadius.circular(8)),
        child: Center(child: Text(
          done ? '✅' : '🔥',
          style: const TextStyle(fontSize: 13))),
      ),
      const SizedBox(width: 10),
      // 습관 정보
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('${h.emoji} ${h.title}', style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: Color(0xFFE2E8F0)),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24).withOpacity(0.12),
                borderRadius: BorderRadius.circular(5)),
              child: const Text('집중', style: TextStyle(
                fontSize: 8, fontWeight: FontWeight.w800,
                color: Color(0xFFFBBF24))),
            ),
          ]),
          const SizedBox(height: 4),
          // 미니 프로그레스 바
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation(done
                  ? const Color(0xFF22C55E).withOpacity(0.7)
                  : const Color(0xFFFBBF24).withOpacity(0.7)),
              minHeight: 3)),
        ],
      )),
      const SizedBox(width: 10),
      // 스트릭 + 진행률
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('🔥$streak일', style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w800,
          color: Color(0xFFFBBF24))),
        Text('${(progress * 100).toInt()}%', style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.35))),
      ]),
    ]);
  }

  /// 습관 완료 처리 (홈에서 직접 체크 — 원터치 완료만)
  void _toggleHabit(OrderHabit h) {
    var n = DateTime.now();
    if (n.hour < 4) n = n.subtract(const Duration(days: 1));
    final todayStr = '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';

    // ★ 이미 완료 시 무시 (실수 방지 — ORDER 탭에서 수정 가능)
    if (h.isDoneOn(todayStr)) return;

    HapticFeedback.mediumImpact();
    h.completedDates.add(todayStr);
    _saveOrderData();
    setState(() {});
  }

  /// 비집중 활성 습관 미니 행 (최대 3개)
  List<Widget> _buildMiniHabitRows() {
    final habits = _orderData?.habits ?? [];
    final active = habits.where((h) =>
      h.rank != 1 && h.settledAt == null && h.rank > 0
    ).take(3).toList();
    if (active.isEmpty) return [];

    var n = DateTime.now();
    if (n.hour < 4) n = n.subtract(const Duration(days: 1));
    final todayStr = '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';

    return active.map((h) {
      final done = h.isDoneOn(todayStr);
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: GestureDetector(
          onTap: () => _toggleHabit(h),
          child: Row(children: [
            Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: done
                  ? const Color(0xFF22C55E).withOpacity(0.7)
                  : Colors.white.withOpacity(0.2)),
            const SizedBox(width: 10),
            Expanded(child: Text(
              '${h.emoji} ${h.title}',
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: done
                    ? Colors.white.withOpacity(0.35)
                    : const Color(0xFFCBD5E1),
                decoration: done ? TextDecoration.lineThrough : null),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text('🔥${h.currentStreak}', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.3))),
          ]),
        ),
      );
    }).toList();
  }

  /// ORDER 데이터 Firebase 저장
  Future<void> _saveOrderData() async {
    if (_orderData == null) return;
    try {
      await FirebaseFirestore.instance
          .doc('users/sJ8Pxusw9gR0tNR44RhkIge7OiG2')
          .set({'orderData': _orderData!.toMap()}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[HomeOrder] ⚠️ orderData 저장 실패: $e');
    }
  }

  /// ★ 일일 계획 진행 미니 로우
  Widget _planProgressRow(DailyPlan plan) {
    final rate = plan.completionRate;
    final rateColor = rate >= 0.8
        ? const Color(0xFF22C55E)
        : rate >= 0.5
            ? const Color(0xFFFBBF24)
            : const Color(0xFFEF4444);

    return GestureDetector(
      onTap: () {
        var n = DateTime.now();
        if (n.hour < 4) n = n.subtract(const Duration(days: 1));
        final ds = '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
        DailyPlanSheet.show(context,
            date: ds,
            plan: plan,
            onSaved: () => _load(playAnim: false));
      },
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8)),
          child: const Center(child: Text('📋',
            style: TextStyle(fontSize: 13))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('오늘의 계획', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: Color(0xFFE2E8F0))),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: rate,
                backgroundColor: Colors.white.withOpacity(0.06),
                valueColor: AlwaysStoppedAnimation(rateColor.withOpacity(0.7)),
                minHeight: 3)),
          ],
        )),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${plan.completedCount}/${plan.totalCount}', style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w800, color: rateColor)),
          Text('${(rate * 100).round()}%', style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.35))),
        ]),
      ]),
    );
  }

  /// 순위 목표 행
  Widget _priorityGoalRow(OrderGoal g, int rank) {
    final rankColors = {
      1: const Color(0xFFFBBF24),  // 금색
      2: const Color(0xFF94A3B8),  // 은색
    };
    final c = rankColors[rank] ?? const Color(0xFF64748B);

    return Row(children: [
      // 순위 배지
      Container(
        width: 22, height: 22,
        decoration: BoxDecoration(
          color: c.withOpacity(0.15),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: c.withOpacity(0.3))),
        child: Center(child: Text('$rank',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: c))),
      ),
      const SizedBox(width: 10),
      // 목표명 + D-Day
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(g.title, style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: Color(0xFFE2E8F0)),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          // 프로그레스 바
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: g.progress / 100,
              backgroundColor: Colors.white.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation(c.withOpacity(0.7)),
              minHeight: 4)),
        ],
      )),
      const SizedBox(width: 10),
      // 퍼센트 + D-Day
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${g.progress}%', style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w800, color: c)),
        if (g.dDayLabel.isNotEmpty)
          Text(g.dDayLabel, style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.35))),
      ]),
    ]);
  }

  /// 시험 D-Day 행
  Widget _examTicketRow(ExamTicketInfo exam) {
    final dl = exam.daysLeft;
    final isUrgent = dl != null && dl <= 7;
    final urgentColor = isUrgent
        ? const Color(0xFFEF4444) : const Color(0xFF38BDF8);

    return Row(children: [
      Container(
        width: 22, height: 22,
        decoration: BoxDecoration(
          color: urgentColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(7)),
        child: Center(child: Text('📋',
          style: const TextStyle(fontSize: 11))),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exam.examName, style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: Color(0xFFE2E8F0)),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          if (exam.location != null)
            Text(exam.location!, style: TextStyle(
              fontSize: 10, color: Colors.white.withOpacity(0.3)),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      )),
      if (exam.dDayLabel.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: urgentColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: urgentColor.withOpacity(0.2))),
          child: Text(exam.dDayLabel, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w800, color: urgentColor)),
        ),
    ]);
  }

  /// 수험표 업로드 플로우
  Future<void> _uploadExamTicket() async {
    final svc = ExamTicketService();

    // 이미지 소스 선택
    final source = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('수험표 업로드', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _sourceBtn('📷', '카메라', () => Navigator.pop(c, true))),
            const SizedBox(width: 12),
            Expanded(child: _sourceBtn('🖼️', '갤러리', () => Navigator.pop(c, false))),
          ]),
          const SizedBox(height: 16),
        ]),
      ),
    );
    if (source == null) return;

    // 처리 중 표시
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('🔍 수험표 분석 중...'),
      duration: Duration(seconds: 10)));

    final ticket = await svc.processExamTicket(fromCamera: source);

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (ticket == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('❌ 수험표 분석 실패'),
        backgroundColor: Color(0xFFEF4444)));
      return;
    }

    // 결과 확인/수정 다이얼로그
    await _showTicketConfirmDialog(ticket);
    _load(playAnim: false);
  }

  Widget _sourceBtn(String emoji, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.7))),
        ]),
      ),
    );
  }

  /// 수험표 분석 결과 확인/수정 다이얼로그
  Future<void> _showTicketConfirmDialog(ExamTicketInfo ticket) async {
    final nameC = TextEditingController(text: ticket.examName);
    final dateC = TextEditingController(text: ticket.examDate ?? '');
    final timeC = TextEditingController(text: ticket.examTime ?? '');
    final locC = TextEditingController(text: ticket.location ?? '');
    final numC = TextEditingController(text: ticket.examNumber ?? '');
    final seatC = TextEditingController(text: ticket.seatNumber ?? '');

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Text('📋 수험표 정보', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700)),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              await ExamTicketService().deleteTicket(ticket.id);
              Navigator.pop(c);
            },
            child: const Icon(Icons.delete_outline, size: 20,
              color: Color(0xFFEF4444))),
        ]),
        content: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ticketField('시험명', nameC),
            _ticketField('시험일 (YYYY-MM-DD)', dateC),
            _ticketField('시험시간 (HH:mm)', timeC),
            _ticketField('장소', locC),
            _ticketField('수험번호', numC),
            _ticketField('좌석번호', seatC),
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c),
            child: const Text('취소')),
          TextButton(onPressed: () async {
            ticket.examName = nameC.text;
            ticket.examDate = dateC.text.isNotEmpty ? dateC.text : null;
            ticket.examTime = timeC.text.isNotEmpty ? timeC.text : null;
            ticket.location = locC.text.isNotEmpty ? locC.text : null;
            ticket.examNumber = numC.text.isNotEmpty ? numC.text : null;
            ticket.seatNumber = seatC.text.isNotEmpty ? seatC.text : null;
            await ExamTicketService().saveTicket(ticket);
            Navigator.pop(c);
          }, child: const Text('저장')),
        ],
      ),
    );
  }

  Widget _ticketField(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12),
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
        style: const TextStyle(fontSize: 13)),
    );
  }

  // ══════════════════════════════════════════
  //  도구 바로가기 (하단 배치)
  // ══════════════════════════════════════════
  Widget _quickToolsRow() {
    return Row(children: [
      _quickTool('📡', 'NFC', () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => NfcScreen()))
        .then((_) => _load(playAnim: false))),
      const SizedBox(width: 8),
      _quickTool('⏰', '알람', () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => const AlarmSettingsScreen()))
        .then((_) => _load(playAnim: false))),
      const SizedBox(width: 8),
      _quickTool('📍', '위치', () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => const LocationScreen()))
        .then((_) => _load(playAnim: false))),
      const SizedBox(width: 8),
    ]);
  }

  Widget _quickTool(String emoji, String label, VoidCallback onTap) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _dk ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border.withOpacity(0.15))),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: _textMuted)),
        ]),
      ),
    ));
  }

  Future<void> _showAddMemoDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('메모 추가', style: BotanicalTypo.heading(size: 18)),
        content: TextField(controller: controller, autofocus: true,
          decoration: const InputDecoration(hintText: '오늘의 메모...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c),
            child: Text('취소', style: TextStyle(color: _textMuted))),
          TextButton(onPressed: () => Navigator.pop(c, controller.text),
            child: const Text('저장')),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await AiCalendarService().addMemo(result);
      _load(); // ★ 메모 목록 갱신
    }
  }
}

/// 하루 타임라인 세그먼트 모델
class _DaySegment {
  final String start;
  final String end;
  final String label;
  final String emoji;
  final Color color;
  const _DaySegment({
    required this.start, required this.end,
    required this.label, required this.emoji, required this.color});
}

/// 시간축 마커
class _TimeMarker {
  final int min;
  final String label;
  const _TimeMarker({required this.min, required this.label});
}