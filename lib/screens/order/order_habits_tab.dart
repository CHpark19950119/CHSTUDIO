import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/order_models.dart';
import 'order_theme.dart';

/// ═══════════════════════════════════════════════════════════
/// TAB 3 — 습관 큐 (Habit Queue System) v4.0
/// Focus Blob · Queue · Settlement · Heatmap · CRUD
/// ⚠️ 네비바 충돌 금지: bottom padding 100 확보
/// ═══════════════════════════════════════════════════════════

class OrderHabitsTab extends StatelessWidget {
  final OrderData data;
  final void Function(VoidCallback fn) onUpdate;
  final AnimationController blobCtrl;

  const OrderHabitsTab({
    super.key, required this.data,
    required this.onUpdate, required this.blobCtrl,
  });

  String get _today => todayStr();

  @override
  Widget build(BuildContext context) {
    // ★ 자동 승격 체크 (빌드 시 매번)
    _checkAutoPromote();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      children: [
        _focusHabitBlob(context),
        const SizedBox(height: 16),
        _queueSection(context),
        const SizedBox(height: 16),
        _growthStageOverview(),
        const SizedBox(height: 16),
        _weekHeatmap(),
        const SizedBox(height: 16),
        _settledSection(context),
        const SizedBox(height: 16),
        _unrankedSection(context),
      ],
    );
  }

  /// 자동 승격 체크
  void _checkAutoPromote() {
    final focus = data.focusHabit;
    if (focus != null && focus.canSettle) {
      // 다음 빌드에서 처리 (setState 안전)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onUpdate(() { data.promoteNextHabit(); });
      });
    }
  }

  // ═══════════════════════════════════════════════════
  // ██ 1. FOCUS HABIT — 대형 Blob 카드
  // ═══════════════════════════════════════════════════
  Widget _focusHabitBlob(BuildContext context) {
    final focus = data.focusHabit;

    if (focus == null) {
      return _emptyFocusCard(context);
    }

    final done = focus.isDoneOn(_today);
    final progress = focus.settlementProgress;

    return AnimatedBuilder(
      animation: blobCtrl,
      builder: (_, __) {
        final t = blobCtrl.value;
        final gradColors = done
            ? [const Color(0xFFa8edea), const Color(0xFFfed6e3)]
            : [const Color(0xFFfbc2eb), const Color(0xFFa6c1ee)];

        return GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            onUpdate(() { focus.toggleDate(_today); });
          },
          onLongPress: () => _openHabitSheet(context, editing: focus),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: OC.card,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: done
                  ? OC.success.withOpacity(0.3)
                  : OC.border.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: done
                      ? OC.success.withOpacity(0.1)
                      : OC.accent.withOpacity(0.06),
                  blurRadius: 24, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(children: [
              // 상단 라벨
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: OC.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: OC.amber.withOpacity(0.25))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('🔥', style: TextStyle(fontSize: 11)),
                    const SizedBox(width: 4),
                    const Text('현재 집중', style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800,
                      color: OC.amber, letterSpacing: 0.5)),
                  ]),
                ),
                const Spacer(),
                if (focus.canSettle)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      onUpdate(() { data.promoteNextHabit(); });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: OC.success.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10)),
                      child: const Text('🎉 정착 완료!', style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: OC.success)),
                    ),
                  ),
              ]),
              const SizedBox(height: 20),

              // Blob + 숫자
              SizedBox(
                width: 180, height: 180,
                child: Stack(alignment: Alignment.center, children: [
                  // Blob shape
                  Container(
                    width: 160, height: 160,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradColors),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(
                            60 + sin(t * 2 * pi) * 20),
                        topRight: Radius.circular(
                            40 + cos(t * 2 * pi) * 15),
                        bottomLeft: Radius.circular(
                            30 + cos(t * 2 * pi + 1) * 20),
                        bottomRight: Radius.circular(
                            70 + sin(t * 2 * pi + 2) * 15)),
                      boxShadow: [BoxShadow(
                        color: gradColors[0].withOpacity(0.35),
                        blurRadius: 30, offset: const Offset(0, 10))]),
                  ),
                  // 컨텐츠
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(focus.emoji,
                        style: const TextStyle(fontSize: 26)),
                    const SizedBox(height: 4),
                    Text('${focus.currentStreak}',
                      style: const TextStyle(
                        fontSize: 42, fontWeight: FontWeight.w900,
                        color: Color(0xFF1a5f7a))),
                    Text('연속 일', style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: const Color(0xFF1a5f7a).withOpacity(0.6))),
                  ]),
                  // 체크 오버레이
                  if (done)
                    Positioned(bottom: 10, right: 10,
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: OC.success,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                            color: OC.success.withOpacity(0.4),
                            blurRadius: 8)]),
                        child: const Icon(Icons.check_rounded,
                            color: Colors.white, size: 18)),
                    ),
                ]),
              ),
              const SizedBox(height: 18),

              // 습관 이름
              Text(focus.title, style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800,
                color: OC.text1)),
              const SizedBox(height: 4),
              Text('${focus.growthEmoji} ${focus.growthLabel} · '
                  '목표 ${focus.targetDays}일 중 ${focus.currentStreak}일',
                style: const TextStyle(fontSize: 12, color: OC.text3)),
              const SizedBox(height: 14),

              // 프로그레스 바
              Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                  Text('정착 진행률', style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: OC.text2)),
                  Text('${(progress * 100).toInt()}%', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w900,
                    color: done ? OC.success : OC.accent)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: OC.bgSub,
                    valueColor: AlwaysStoppedAnimation(
                        done ? OC.success : OC.accent),
                    minHeight: 8)),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                  Text('최고 ${focus.maxStreak}일',
                    style: const TextStyle(fontSize: 10, color: OC.text4)),
                  Text(focus.daysToSettle > 0
                      ? '${focus.daysToSettle}일 남음'
                      : '🎉 정착 가능!',
                    style: TextStyle(fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: focus.daysToSettle > 0
                          ? OC.text3 : OC.success)),
                ]),
              ]),

              // 오늘 체크 안내
              if (!done) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    color: OC.accentBg,
                    borderRadius: BorderRadius.circular(14)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    const Icon(Icons.touch_app_rounded,
                        size: 16, color: OC.accent),
                    const SizedBox(width: 6),
                    const Text('탭하여 오늘 완료', style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: OC.accent)),
                  ]),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }

  Widget _emptyFocusCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _openHabitSheet(context),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: OC.card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: OC.border.withOpacity(0.5),
              style: BorderStyle.solid),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16, offset: const Offset(0, 6))]),
        child: Column(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: OC.accentBg,
              borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.add_rounded,
                size: 28, color: OC.accent)),
          const SizedBox(height: 14),
          const Text('집중 습관 없음', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w800, color: OC.text1)),
          const SizedBox(height: 4),
          const Text('새 습관을 추가하고 1순위로 지정하세요',
            style: TextStyle(fontSize: 12, color: OC.text3)),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // ██ 2. QUEUE — 대기열 (2순위~N순위)
  // ═══════════════════════════════════════════════════
  Widget _queueSection(BuildContext context) {
    final queue = data.rankedHabits.where((h) => h.rank > 1).toList();
    if (queue.isEmpty && data.focusHabit != null) {
      return const SizedBox.shrink();
    }

    return orderSectionCard(
      title: '대기열', icon: Icons.queue_rounded,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        // ★ 대기 중 배지
        if (queue.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF64748B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF94A3B8).withOpacity(0.2))),
            child: Text('${queue.length}개 대기 중', style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8))),
          ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _openHabitSheet(context),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: OC.accentBg,
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.add_rounded,
                size: 18, color: OC.accent)),
        ),
      ]),
      children: [
        if (queue.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('대기 중인 습관이 없습니다',
              style: const TextStyle(fontSize: 12, color: OC.text4))),
        ...queue.map((h) => _queueItem(h, context)),
      ],
    );
  }

  Widget _queueItem(OrderHabit h, BuildContext context) {
    final done = h.isDoneOn(_today);
    return GestureDetector(
      onTap: () => _openHabitSheet(context, editing: h),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 400 + (h.rank * 80)),
        curve: Curves.easeOutCubic,
        builder: (_, val, child) => Transform.translate(
          offset: Offset(20 * (1 - val), 0),
          child: Opacity(opacity: val, child: child),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: OC.cardHi,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF94A3B8).withOpacity(0.15))),
          child: Row(children: [
            // 순위 배지 (회색 톤 — 집중과 차별)
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF94A3B8).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF94A3B8).withOpacity(0.2))),
              child: Center(child: Text('${h.rank}',
                style: const TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w800, color: Color(0xFF94A3B8)))),
            ),
            const SizedBox(width: 12),
            Text(h.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(h.title, style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: OC.text1), maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 6),
                  // ★ 대기 중 라벨
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF94A3B8).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5)),
                    child: const Text('대기', style: TextStyle(
                      fontSize: 8, fontWeight: FontWeight.w800,
                      color: Color(0xFF94A3B8))),
                  ),
                ]),
                Text('🔥 ${h.currentStreak}일 · ${h.growthEmoji} ${h.growthLabel}',
                  style: const TextStyle(fontSize: 11, color: OC.text3)),
              ],
            )),
            // 순위 변경 버튼
            Column(mainAxisSize: MainAxisSize.min, children: [
              if (h.rank > 2)
                GestureDetector(
                  onTap: () => _moveRank(h, -1),
                  child: const Icon(Icons.keyboard_arrow_up_rounded,
                      size: 20, color: OC.text3)),
              GestureDetector(
                onTap: () => _moveRank(h, 1),
                child: const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 20, color: OC.text3)),
            ]),
          ]),
        ),
      ),
    );
  }

  void _moveRank(OrderHabit habit, int delta) {
    final newRank = habit.rank + delta;
    if (newRank < 2) return; // 1순위는 포커스 전용

    onUpdate(() {
      // 기존 해당 순위 습관과 스왑
      final target = data.habits.where(
          (h) => h.rank == newRank && !h.archived && !h.isSettled).toList();
      for (final t in target) {
        t.rank = habit.rank;
      }
      habit.rank = newRank;
    });
    HapticFeedback.selectionClick();
  }

  // ═══════════════════════════════════════════════════
  // ██ 3. GROWTH STAGE OVERVIEW
  // ═══════════════════════════════════════════════════
  Widget _growthStageOverview() {
    final active = data.habits.where((h) => !h.archived).toList();
    final stages = {
      GrowthStage.seed: active
          .where((h) => h.growthStage == GrowthStage.seed).length,
      GrowthStage.sprout: active
          .where((h) => h.growthStage == GrowthStage.sprout).length,
      GrowthStage.tree: active
          .where((h) => h.growthStage == GrowthStage.tree).length,
      GrowthStage.pillar: active
          .where((h) => h.growthStage == GrowthStage.pillar).length,
    };
    final stageInfo = [
      ('🌱', '씨앗', '1~7일', stages[GrowthStage.seed]!),
      ('🌿', '새싹', '8~21일', stages[GrowthStage.sprout]!),
      ('🌳', '나무', '22~66일', stages[GrowthStage.tree]!),
      ('🏛️', '기둥', '67일+', stages[GrowthStage.pillar]!),
    ];

    return orderSectionCard(
      title: '습관 성장 단계', icon: Icons.eco_rounded,
      children: [
        Row(children: stageInfo.map((s) => Expanded(
          child: _GrowthStageCell(
            emoji: s.$1, label: s.$2, range: s.$3, count: s.$4),
        )).toList()),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  // ██ 4. WEEK HEATMAP
  // ═══════════════════════════════════════════════════
  Widget _weekHeatmap() {
    final days = ['월', '화', '수', '목', '금', '토', '일'];
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final active = data.habits.where((h) => !h.archived).toList();

    return orderSectionCard(
      title: '주간 히트맵', icon: Icons.grid_on_rounded,
      children: [
        Row(children: [
          const SizedBox(width: 50),
          ...days.map((d) => Expanded(child: Center(
            child: Text(d, style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600,
              color: OC.text3))))),
        ]),
        const SizedBox(height: 6),
        ...active.map((h) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            SizedBox(width: 50, child: Text('${h.emoji}${h.title}',
              style: const TextStyle(fontSize: 9, color: OC.text2),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
            ...List.generate(7, (i) {
              final d = weekStart.add(Duration(days: i));
              final ds = '${d.year}-${d.month.toString().padLeft(2, '0')}'
                  '-${d.day.toString().padLeft(2, '0')}';
              final done = h.isDoneOn(ds);
              return Expanded(child: Center(child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: done
                      ? OC.success.withOpacity(.7) : OC.bgSub,
                  borderRadius: BorderRadius.circular(6)),
                child: done
                    ? const Icon(Icons.check_rounded,
                        size: 12, color: Colors.white)
                    : null,
              )));
            }),
          ]),
        )),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  // ██ 5. SETTLED — 정착 완료 습관 (유지 모니터링)
  // ═══════════════════════════════════════════════════
  Widget _settledSection(BuildContext context) {
    final settled = data.settledHabits;
    if (settled.isEmpty) return const SizedBox.shrink();

    return orderSectionCard(
      title: '정착 완료', icon: Icons.verified_rounded,
      children: settled.map((h) => _settledCard(h, context)).toList(),
    );
  }

  Widget _settledCard(OrderHabit h, BuildContext context) {
    final done = h.isDoneOn(_today);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onUpdate(() { h.toggleDate(_today); });
      },
      onLongPress: () => _openHabitSheet(context, editing: h),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: done ? OC.successBg : OC.cardHi,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: done
              ? OC.success.withOpacity(.2) : OC.border)),
        child: Row(children: [
          Text(h.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(h.title, style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w700, color: OC.text1)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: OC.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6)),
                  child: const Text('정착', style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: OC.success)),
                ),
              ]),
              Text('🔥 ${h.currentStreak}일 유지 중',
                style: const TextStyle(fontSize: 11, color: OC.text3)),
            ],
          )),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: done ? OC.success : OC.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: done ? OC.success : OC.border)),
            child: done
                ? const Icon(Icons.check_rounded,
                    color: Colors.white, size: 18)
                : null),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // ██ 6. UNRANKED — 순위 미지정 습관
  // ═══════════════════════════════════════════════════
  Widget _unrankedSection(BuildContext context) {
    final unranked = data.unrankedHabits;
    final archived = data.habits.where((h) => h.archived).toList();

    if (unranked.isEmpty && archived.isEmpty) return const SizedBox.shrink();

    return Column(children: [
      if (unranked.isNotEmpty)
        orderSectionCard(
          title: '미지정 습관', icon: Icons.checklist_rounded,
          trailing: GestureDetector(
            onTap: () => _openHabitSheet(context),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: OC.accentBg,
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.add_rounded,
                  size: 18, color: OC.accent)),
          ),
          children: unranked.map((h) =>
              _unrankedCard(h, context)).toList()),
      if (archived.isNotEmpty) ...[
        const SizedBox(height: 16),
        orderSectionCard(
          title: '보관함', icon: Icons.archive_rounded,
          children: archived.map((h) =>
              _archivedCard(h, context)).toList()),
      ],
    ]);
  }

  Widget _unrankedCard(OrderHabit h, BuildContext context) {
    final done = h.isDoneOn(_today);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onUpdate(() { h.toggleDate(_today); });
      },
      onLongPress: () => _showRankAssignSheet(context, h),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: done ? OC.successBg : OC.cardHi,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: done
              ? OC.success.withOpacity(.2) : OC.border)),
        child: Row(children: [
          Text(h.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h.title, style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: OC.text1)),
              Row(children: [
                Text('${h.growthEmoji} ${h.growthLabel}',
                  style: const TextStyle(fontSize: 11, color: OC.text3)),
                const SizedBox(width: 8),
                Text('🔥 ${h.currentStreak}일',
                  style: const TextStyle(fontSize: 11, color: OC.amber)),
              ]),
            ],
          )),
          // 순위 배정 버튼
          GestureDetector(
            onTap: () => _showRankAssignSheet(context, h),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: OC.accentBg,
                borderRadius: BorderRadius.circular(8)),
              child: const Text('순위↗', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: OC.accent)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _archivedCard(OrderHabit h, BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        onUpdate(() { h.archived = false; });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: OC.bgSub,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: OC.border)),
        child: Row(children: [
          Text(h.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(h.title, style: const TextStyle(
            fontSize: 12, color: OC.text3,
            decoration: TextDecoration.lineThrough))),
          const Text('길게 눌러 복원', style: TextStyle(
            fontSize: 9, color: OC.text4)),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // ██ SHEETS
  // ═══════════════════════════════════════════════════

  /// 순위 배정 시트
  void _showRankAssignSheet(BuildContext context, OrderHabit h) {
    final ranked = data.rankedHabits;
    final nextRank = ranked.isEmpty ? 1 : ranked.last.rank + 1;
    // 포커스가 비어있으면 1순위로 직접 배정
    final suggestedRank = data.focusHabit == null ? 1 : nextRank;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.45),
        decoration: const BoxDecoration(color: OC.card,
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(28))),
        padding: EdgeInsets.fromLTRB(
          20, 8, 20, sheetBottomPad(ctx)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          sheetHandle(),
          Text('${h.emoji} ${h.title}', style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w800, color: OC.text1)),
          const SizedBox(height: 4),
          const Text('순위를 배정하세요', style: TextStyle(
            fontSize: 12, color: OC.text3)),
          const SizedBox(height: 16),

          // 순위 선택 버튼들
          if (data.focusHabit == null)
            _rankBtn(ctx, h, 1, '🔥 1순위 (집중)', OC.amber, true),
          _rankBtn(ctx, h, suggestedRank > 1 ? suggestedRank : 2,
            '⏳ ${suggestedRank > 1 ? suggestedRank : 2}순위 (대기)',
            OC.accent, data.focusHabit != null),
          if (ranked.length > 1)
            _rankBtn(ctx, h, ranked.last.rank + 1,
              '📋 ${ranked.last.rank + 1}순위 (마지막)',
              OC.text2, false),

          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: sheetBtn('보관', OC.bgSub, OC.text2, () {
              onUpdate(() { h.archived = true; h.rank = 0; });
              Navigator.pop(ctx);
            })),
            const SizedBox(width: 10),
            Expanded(child: sheetBtn('삭제', OC.errorBg, OC.error, () {
              onUpdate(() {
                data.habits.removeWhere((x) => x.id == h.id);
              });
              Navigator.pop(ctx);
            })),
          ]),
        ]),
      ),
    );
  }

  Widget _rankBtn(BuildContext ctx, OrderHabit h, int rank,
      String label, Color c, bool primary) {
    return GestureDetector(
      onTap: () {
        onUpdate(() {
          // 기존 동일 순위 밀어내기
          for (final x in data.habits) {
            if (x.id != h.id && x.rank >= rank
                && !x.archived && !x.isSettled) {
              x.rank = x.rank + 1;
            }
          }
          h.rank = rank;
        });
        HapticFeedback.mediumImpact();
        Navigator.pop(ctx);
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: primary ? c.withOpacity(0.12) : OC.cardHi,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: primary
              ? c.withOpacity(0.3) : OC.border)),
        child: Center(child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: primary ? c : OC.text2))),
      ),
    );
  }

  /// 습관 추가/수정 시트
  void _openHabitSheet(BuildContext context, {OrderHabit? editing}) {
    final isEdit = editing != null;
    final titleC = TextEditingController(text: editing?.title ?? '');
    final emojiC = TextEditingController(text: editing?.emoji ?? '✅');
    var freq = editing?.freq ?? HabitFreq.daily;
    var targetDays = editing?.targetDays ?? 21;
    // ★ Fix: 포커스 습관이 없으면 기본 rank=1 (집중)으로 자동 배정
    var rank = editing?.rank ?? (data.focusHabit == null ? 1 : 0);

    final targetOptions = [7, 14, 21, 30, 66];

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          decoration: const BoxDecoration(color: OC.card,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28))),
          padding: EdgeInsets.fromLTRB(
            20, 8, 20, sheetBottomPad(ctx)),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              sheetHandle(),
              Text(isEdit ? '습관 수정' : '새 습관', style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: OC.text1)),
              const SizedBox(height: 16),
              Row(children: [
                SizedBox(width: 60,
                  child: sheetField('이모지', emojiC, '✅')),
                const SizedBox(width: 10),
                Expanded(child: sheetField('이름', titleC, '습관명')),
              ]),
              const SizedBox(height: 8),

              // 목표 일수
              const Align(alignment: Alignment.centerLeft,
                child: Text('정착 목표', style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w600, color: OC.text2))),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: targetOptions.map((d) =>
                GestureDetector(
                  onTap: () => setS(() => targetDays = d),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: targetDays == d ? OC.accent : OC.cardHi,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: targetDays == d
                          ? OC.accent : OC.border)),
                    child: Text('${d}일', style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: targetDays == d
                          ? Colors.white : OC.text2)),
                  ),
                ),
              ).toList()),
              const SizedBox(height: 14),

              // 순위
              const Align(alignment: Alignment.centerLeft,
                child: Text('순위', style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w600, color: OC.text2))),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => setS(() => rank = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: rank == 0 ? OC.bgSub : OC.cardHi,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: rank == 0
                          ? OC.text3 : OC.border)),
                    child: Center(child: Text('미지정',
                      style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: rank == 0 ? OC.text1 : OC.text3))),
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(child: GestureDetector(
                  onTap: () => setS(() => rank = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: rank == 1
                          ? OC.amber.withOpacity(0.12) : OC.cardHi,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: rank == 1
                          ? OC.amber : OC.border)),
                    child: Center(child: Text('🔥 집중',
                      style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: rank == 1 ? OC.amber : OC.text3))),
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(child: GestureDetector(
                  onTap: () {
                    final next = data.rankedHabits.isEmpty
                        ? 2 : data.rankedHabits.last.rank + 1;
                    setS(() => rank = next);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: rank > 1
                          ? OC.accentBg : OC.cardHi,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: rank > 1
                          ? OC.accent : OC.border)),
                    child: Center(child: Text('⏳ 대기',
                      style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: rank > 1 ? OC.accent : OC.text3))),
                  ),
                )),
              ]),

              const SizedBox(height: 16),
              Row(children: [
                if (isEdit) ...[
                  Expanded(child: sheetBtn(
                    '삭제', OC.errorBg, OC.error, () {
                      onUpdate(() {
                        data.habits.removeWhere(
                          (h) => h.id == editing.id);
                      });
                      Navigator.pop(ctx);
                    },
                  )),
                  const SizedBox(width: 10),
                ],
                Expanded(child: sheetBtn(
                  isEdit ? '저장' : '추가', OC.accent, Colors.white, () {
                    if (titleC.text.isEmpty) return;
                    onUpdate(() {
                      if (isEdit) {
                        editing.title = titleC.text;
                        editing.emoji = emojiC.text;
                        editing.freq = freq;
                        editing.targetDays = targetDays;
                        // 순위 변경 시 중복 방지
                        if (rank == 1 && editing.rank != 1) {
                          final oldFocus = data.focusHabit;
                          if (oldFocus != null) {
                            oldFocus.rank = editing.rank > 0
                                ? editing.rank : 2;
                          }
                        }
                        editing.rank = rank;
                      } else {
                        if (rank == 1) {
                          final oldFocus = data.focusHabit;
                          if (oldFocus != null) oldFocus.rank = 2;
                        }
                        data.habits.add(OrderHabit(
                          id: 'h_${DateTime.now().millisecondsSinceEpoch}',
                          title: titleC.text,
                          emoji: emojiC.text,
                          freq: freq,
                          targetDays: targetDays,
                          rank: rank,
                        ));
                      }
                    });
                    Navigator.pop(ctx);
                  },
                )),
              ]),
            ]),
          ),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════
// ██ GROWTH STAGE BOUNCE CELL (Extracted StatefulWidget)
// ═══════════════════════════════════════════════════

/// 성장 단계 카드: 탭 시 scale bounce 애니메이션
class _GrowthStageCell extends StatefulWidget {
  final String emoji, label, range;
  final int count;
  const _GrowthStageCell({
    required this.emoji, required this.label,
    required this.range, required this.count,
  });
  @override State<_GrowthStageCell> createState() => _GrowthStageCellState();
}

class _GrowthStageCellState extends State<_GrowthStageCell>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15)
          .chain(CurveTween(curve: Curves.easeOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.95)
          .chain(CurveTween(curve: Curves.easeInOut)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOut)), weight: 30),
    ]).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { _ctrl.forward(from: 0); HapticFeedback.lightImpact(); },
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: widget.count > 0 ? OC.successBg : OC.cardHi,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.count > 0
                ? OC.success.withOpacity(.2) : OC.border)),
          child: Column(children: [
            Text(widget.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(widget.label, style: const TextStyle(fontSize: 11,
              fontWeight: FontWeight.w700, color: OC.text1)),
            Text(widget.range, style: const TextStyle(
              fontSize: 9, color: OC.text3)),
            const SizedBox(height: 4),
            Text('${widget.count}', style: TextStyle(fontSize: 16,
              fontWeight: FontWeight.w900,
              color: widget.count > 0 ? OC.success : OC.text4)),
          ]),
        ),
      ),
    );
  }
}