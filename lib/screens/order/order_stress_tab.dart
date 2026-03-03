import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/order_models.dart';
import '../../services/overwatch_polling_service.dart';
import 'order_theme.dart';

/// ═══════════════════════════════════════════════════════════
/// TAB 5 — 관리 (Management)
/// 좌절 기록 · 탈선 관리 · OW Auto-Detect · 통합 히스토리
/// ═══════════════════════════════════════════════════════════

class OrderStressTab extends StatefulWidget {
  final OrderData data;
  final void Function(VoidCallback fn) onUpdate;

  const OrderStressTab({
    super.key, required this.data, required this.onUpdate,
  });

  @override
  State<OrderStressTab> createState() => _OrderStressTabState();
}

class _OrderStressTabState extends State<OrderStressTab> {
  final _owSvc = OverwatchPollingService();

  OverwatchPollingSettings _owSettings = OverwatchPollingSettings();
  OverwatchSnapshot? _owSnapshot;
  StreamSubscription? _settingsSub;
  StreamSubscription? _snapshotSub;
  bool _owExpanded = false;
  bool _tagSaving = false;

  final _tagController = TextEditingController();

  OrderData get data => widget.data;
  void Function(VoidCallback fn) get onUpdate => widget.onUpdate;
  String get _today => todayStr();

  @override
  void initState() {
    super.initState();
    _settingsSub = _owSvc.watchSettings().listen((s) {
      if (mounted) setState(() => _owSettings = s);
    });
    _snapshotSub = _owSvc.watchSnapshot().listen((s) {
      if (mounted) setState(() => _owSnapshot = s);
    });
    _checkDetection();
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    _snapshotSub?.cancel();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _checkDetection() async {
    try {
      final det = await _owSvc.consumeLastDetection();
      if (det != null && mounted) {
        final games = det['gamesPlayed'] ?? 0;
        final mins = det['estimatedMinutes'] ?? 0;
        if (games > 0 && mins > 0) {
          final autoLog = StressLog(
            id: 'sl_ow_${DateTime.now().millisecondsSinceEpoch}',
            type: StressType.escape,
            duration: mins is int ? mins : (mins as num).toInt(),
            trigger: StressTrigger.stress,
            priorActivity: PriorActivity.study,
            subType: 'overwatch',
            source: 'auto_poll',
            note: '🤖 자동감지: ${games}판 / 약 ${mins}분',
          );
          onUpdate(() => data.stressLogs.add(autoLog));
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('🎮 오버워치 자동감지: ${games}판, 약 ${mins}분 → 자동기록'),
          backgroundColor: OC.stressEsc,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      children: [
        _setbackSection(),
        const SizedBox(height: 16),
        _deviationQuickLog(context),
        const SizedBox(height: 16),
        _overwatchSection(),
        const SizedBox(height: 16),
        _weeklyPatternMini(),
        const SizedBox(height: 16),
        _unifiedTimeline(),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  // 1. 좌절 기록장
  // ═══════════════════════════════════════════════════
  Widget _setbackSection() {
    final setbacks = data.setbacks.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Column(children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              const Color(0xFF6366F1).withOpacity(0.15),
              const Color(0xFF8B5CF6).withOpacity(0.08),
            ]),
            borderRadius: BorderRadius.circular(10)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Text('📖', style: TextStyle(fontSize: 14)),
            SizedBox(width: 6),
            Text('좌절 기록장', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF6366F1))),
          ]),
        ),
        const SizedBox(width: 8),
        Text('${setbacks.length}건', style: const TextStyle(
          fontSize: 11, color: OC.text4, fontWeight: FontWeight.w600)),
        const Spacer(),
        GestureDetector(
          onTap: () => _addSetbackSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1),
              borderRadius: BorderRadius.circular(10)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, size: 14, color: Colors.white),
              SizedBox(width: 4),
              Text('기록', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      if (setbacks.isEmpty)
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: OC.cardHi, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: OC.border.withOpacity(0.3))),
          child: Column(children: [
            const Text('🌱', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            const Text('아직 기록이 없습니다', style: TextStyle(
              fontSize: 12, color: OC.text3, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('좌절도 성장의 일부입니다', style: TextStyle(
              fontSize: 10, color: OC.text4)),
          ]),
        )
      else
        ...setbacks.take(3).map(_setbackCard),
      if (setbacks.length > 3) ...[
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showAllSetbacks(context),
          child: Text('전체 ${setbacks.length}건 보기 →', style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
        ),
      ],
    ]);
  }

  Widget _setbackCard(SetbackLog sb) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => _showSetbackDetail(context, sb),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: OC.card, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.1)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02),
              blurRadius: 8, offset: const Offset(0, 2))]),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(sb.categoryEmoji,
                style: const TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(sb.title, style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: OC.text1),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6)),
                    child: Text(sb.categoryLabel, style: const TextStyle(
                      fontSize: 8, fontWeight: FontWeight.w700,
                      color: Color(0xFF6366F1))),
                  ),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  Text(sb.date, style: const TextStyle(fontSize: 10, color: OC.text4)),
                  if (sb.emotion != null) ...[
                    const SizedBox(width: 6),
                    Text(sb.emotion!, style: const TextStyle(fontSize: 12)),
                  ],
                  if (sb.lesson != null) ...[
                    const Spacer(),
                    const Text('💡 교훈 있음', style: TextStyle(
                      fontSize: 9, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                  ],
                ]),
              ],
            )),
            const Icon(Icons.chevron_right_rounded, size: 18, color: OC.text4),
          ]),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // 2. 탈선 퀵로그
  // ═══════════════════════════════════════════════════
  Widget _deviationQuickLog(BuildContext context) {
    final todayLogs = data.stressLogs.where((s) {
      final d = s.dateTime; final now = DateTime.now();
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).toList();
    final totalMin = todayLogs.fold<int>(0, (s, l) => s + l.duration);

    return orderSectionCard(
      title: '탈선 관리', icon: Icons.track_changes_rounded,
      trailing: todayLogs.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: OC.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8)),
              child: Text('오늘 ${todayLogs.length}회 · ${totalMin}분',
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: OC.error)),
            )
          : const Text('✨ 클린', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: OC.success)),
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          _deviationBtn(context, '🎮', '게임', StressType.escape, 'overwatch'),
          _deviationBtn(context, '📱', 'SNS/유튜브', StressType.escape, 'sns'),
          _deviationBtn(context, '😴', '낮잠/누움', StressType.release, 'nap'),
          _deviationBtn(context, '🍔', '폭식', StressType.release, 'binge'),
          _deviationBtn(context, '🏃', '운동 (대체)', StressType.alternative, 'exercise'),
          _deviationBtn(context, '📝', '직접 입력', StressType.escape, null),
        ]),
      ],
    );
  }

  Widget _deviationBtn(BuildContext context, String emoji, String label,
      StressType type, String? subType) {
    final color = type == StressType.alternative ? OC.success
        : type == StressType.escape ? OC.stressEsc : OC.error;
    return GestureDetector(
      onTap: () {
        if (subType == null) { _customDeviationSheet(context); }
        else { _quickDeviation(type, subType, label); }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }

  void _quickDeviation(StressType type, String subType, String label) {
    HapticFeedback.mediumImpact();
    onUpdate(() {
      data.stressLogs.add(StressLog(
        id: 'sl_${DateTime.now().millisecondsSinceEpoch}',
        type: type, subType: subType, duration: 15, note: label,
      ));
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('⚡ 탈선 기록: $label (15분)'),
      duration: const Duration(seconds: 2),
      action: SnackBarAction(label: '시간수정', onPressed: _editLastLogDuration),
    ));
  }

  void _editLastLogDuration() {
    if (data.stressLogs.isEmpty) return;
    final last = data.stressLogs.last;
    final ctrl = TextEditingController(text: '${last.duration}');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('시간 수정', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      content: TextField(controller: ctrl, keyboardType: TextInputType.number,
        decoration: const InputDecoration(hintText: '분 단위', suffixText: '분')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        TextButton(onPressed: () {
          onUpdate(() => last.duration = int.tryParse(ctrl.text) ?? last.duration);
          Navigator.pop(ctx);
        }, child: const Text('저장')),
      ],
    ));
  }

  void _customDeviationSheet(BuildContext context) {
    final noteCtrl = TextEditingController();
    final durCtrl = TextEditingController(text: '15');
    StressType selType = StressType.escape;
    StressTrigger selTrigger = StressTrigger.stress;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: const BoxDecoration(color: OC.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(
              color: OC.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('탈선 직접 기록', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800, color: OC.text1)),
            const SizedBox(height: 16),
            Row(children: [
              _typeChip('탈선', StressType.escape, selType, (t) => setLocal(() => selType = t)),
              const SizedBox(width: 8),
              _typeChip('해소', StressType.release, selType, (t) => setLocal(() => selType = t)),
              const SizedBox(width: 8),
              _typeChip('대체행동', StressType.alternative, selType, (t) => setLocal(() => selType = t)),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: StressTrigger.values.map((t) {
              final sel = t == selTrigger;
              return GestureDetector(
                onTap: () => setLocal(() => selTrigger = t),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: sel ? OC.accent.withOpacity(0.1) : OC.cardHi,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sel ? OC.accent : OC.border)),
                  child: Text(_triggerLabel(t), style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w600, color: sel ? OC.accent : OC.text3)),
                ),
              );
            }).toList()),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: noteCtrl,
                decoration: InputDecoration(hintText: '무엇을 했나요?',
                  hintStyle: const TextStyle(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                style: const TextStyle(fontSize: 13))),
              const SizedBox(width: 8),
              SizedBox(width: 70, child: TextField(controller: durCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(suffixText: '분', hintText: '분',
                  hintStyle: const TextStyle(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                style: const TextStyle(fontSize: 13))),
            ]),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () {
                onUpdate(() { data.stressLogs.add(StressLog(
                  id: 'sl_${DateTime.now().millisecondsSinceEpoch}',
                  type: selType, duration: int.tryParse(durCtrl.text) ?? 15,
                  trigger: selTrigger,
                  note: noteCtrl.text.isNotEmpty ? noteCtrl.text : null,
                )); });
                HapticFeedback.mediumImpact();
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: OC.accent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('기록', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _typeChip(String label, StressType type, StressType sel, ValueChanged<StressType> onTap) {
    final active = type == sel;
    final color = type == StressType.alternative ? OC.success
        : type == StressType.escape ? OC.stressEsc : OC.error;
    return GestureDetector(onTap: () => onTap(type), child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.12) : OC.cardHi,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? color : OC.border)),
      child: Text(label, style: TextStyle(fontSize: 11,
        fontWeight: FontWeight.w700, color: active ? color : OC.text3)),
    ));
  }

  String _triggerLabel(StressTrigger t) {
    switch (t) {
      case StressTrigger.stress: return '스트레스';
      case StressTrigger.fatigue: return '피로';
      case StressTrigger.boredom: return '무료함';
      case StressTrigger.reward: return '보상심리';
      case StressTrigger.habitual: return '습관적';
    }
  }

  // ═══════════════════════════════════════════════════
  // 3. OVERWATCH 자동감지 (접이식)
  // ═══════════════════════════════════════════════════
  Widget _overwatchSection() {
    final configured = _owSettings.isConfigured;
    final active = _owSettings.isActive;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1a1a2e), Color(0xFF16213e)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active
            ? const Color(0xFFF99E1A).withOpacity(.4)
            : Colors.white.withOpacity(.08))),
      child: Column(children: [
        GestureDetector(
          onTap: () => setState(() => _owExpanded = !_owExpanded),
          child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
            Container(width: 32, height: 32,
              decoration: BoxDecoration(
                color: active ? const Color(0xFFF99E1A).withOpacity(.15)
                    : Colors.white.withOpacity(.06),
                borderRadius: BorderRadius.circular(10)),
              child: const Center(child: Text('🎮', style: TextStyle(fontSize: 16)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('OVERWATCH', style: TextStyle(fontSize: 10,
                fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 1.5)),
              Text(!configured ? '배틀태그를 설정해주세요'
                  : active ? '자동감지 ON · ${_owSettings.intervalMinutes}분' : '비활성',
                style: TextStyle(fontSize: 10,
                  color: active ? const Color(0xFFF99E1A) : Colors.white38)),
            ])),
            if (active) Container(width: 6, height: 6, decoration: BoxDecoration(
              color: const Color(0xFF4ADE80), shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: const Color(0xFF4ADE80).withOpacity(.5), blurRadius: 6)])),
            const SizedBox(width: 8),
            Icon(_owExpanded ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded, color: Colors.white38, size: 20),
          ])),
        ),
        if (_owExpanded) ...[
          const Divider(height: 1, color: Color(0xFF334155)),
          Padding(padding: const EdgeInsets.all(14), child: Column(children: [
            _owBattletagInput(),
            const SizedBox(height: 10),
            _owToggleRow(),
            if (_owSnapshot != null) ...[const SizedBox(height: 14), _owSnapshotDetail()],
            const SizedBox(height: 10),
            _owManualSyncButton(),
          ])),
        ],
      ]),
    );
  }

  Widget _owBattletagInput() {
    _tagController.text = _owSettings.battletag ?? '';
    return Row(children: [
      Expanded(child: TextField(controller: _tagController,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(hintText: 'Name#1234',
          hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
          filled: true, fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)))),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: _tagSaving ? null : () async {
          final tag = _tagController.text.trim();
          if (tag.isEmpty || !tag.contains('#')) return;
          setState(() => _tagSaving = true);
          try {
            await _owSvc.setBattletag(tag);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ 배틀태그 저장'), duration: Duration(seconds: 2)));
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('❌ $e'), backgroundColor: OC.error));
          }
          if (mounted) setState(() => _tagSaving = false);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFFF99E1A), borderRadius: BorderRadius.circular(12)),
          child: _tagSaving
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('저장', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ),
    ]);
  }

  Widget _owToggleRow() => Row(children: [
    const Expanded(child: Text('자동 감지', style: TextStyle(
      color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600))),
    Switch(value: _owSettings.isActive, activeColor: const Color(0xFFF99E1A),
      onChanged: _owSettings.isConfigured ? (v) => _owSvc.setActive(v) : null),
  ]);

  Widget _owSnapshotDetail() {
    final s = _owSnapshot!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        _owRow('플레이어', _owSettings.playerName ?? '(unknown)'),
        _owRow('게임 수', '${s.gamesPlayed}판'),
        _owRow('플레이 시간', s.formattedTime),
        _owRow('마지막 확인', s.lastPolled != null
            ? DateFormat('M/d HH:mm').format(s.lastPolled!) : '-'),
      ]),
    );
  }

  Widget _owRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      const Spacer(),
      Text(value, style: const TextStyle(
        color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _owManualSyncButton() => SizedBox(width: double.infinity, child: OutlinedButton.icon(
    onPressed: () async {
      try {
        await _owSvc.manualCheck();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 수동 확인 요청 완료'), duration: Duration(seconds: 2)));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $e'), backgroundColor: OC.error));
      }
    },
    icon: const Icon(Icons.sync_rounded, size: 14, color: Color(0xFFF99E1A)),
    label: const Text('수동 확인', style: TextStyle(
      fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFF99E1A))),
    style: OutlinedButton.styleFrom(
      side: const BorderSide(color: Color(0xFF334155)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(vertical: 10)),
  ));

  // ═══════════════════════════════════════════════════
  // 4. 주간 패턴 (Compact)
  // ═══════════════════════════════════════════════════
  Widget _weeklyPatternMini() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return orderSectionCard(
      title: '이번 주 패턴', icon: Icons.insights_rounded,
      children: [
        SizedBox(height: 50, child: Row(children: List.generate(7, (i) {
          final day = weekStart.add(Duration(days: i));
          final dayStr = DateFormat('yyyy-MM-dd').format(day);
          final count = data.stressLogs.where((s) =>
            DateFormat('yyyy-MM-dd').format(s.dateTime) == dayStr).length;
          final isToday = i == now.weekday - 1;
          final labels = ['월', '화', '수', '목', '금', '토', '일'];
          return Expanded(child: Column(children: [
            Text(labels[i], style: TextStyle(fontSize: 9,
              fontWeight: FontWeight.w600, color: isToday ? OC.accent : OC.text4)),
            const SizedBox(height: 4),
            Container(width: 28, height: 28,
              decoration: BoxDecoration(
                color: count == 0
                    ? (isToday ? OC.accent.withOpacity(0.08) : OC.cardHi)
                    : Color.lerp(const Color(0xFFFEF3C7),
                        const Color(0xFFFCA5A5), (count / 5).clamp(0, 1)),
                borderRadius: BorderRadius.circular(8),
                border: isToday ? Border.all(color: OC.accent, width: 1.5) : null),
              child: Center(child: Text(count == 0 ? '·' : '$count',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: count == 0 ? OC.text4 : OC.text1)))),
          ]));
        }))),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  // 5. 통합 타임라인
  // ═══════════════════════════════════════════════════
  Widget _unifiedTimeline() {
    final items = <_TimelineItem>[
      ...data.setbacks.map((s) => _TimelineItem(
        timestamp: DateTime.tryParse(s.timestamp) ?? DateTime.now(),
        emoji: s.categoryEmoji, title: s.title,
        subtitle: s.categoryLabel, type: 'setback',
        color: const Color(0xFF6366F1))),
      ...data.stressLogs.map((s) => _TimelineItem(
        timestamp: s.dateTime,
        emoji: s.typeEmoji, title: s.note ?? s.typeLabel,
        subtitle: '${s.duration}분 · ${s.triggerLabel}', type: 'stress',
        color: s.type == StressType.alternative ? OC.success : OC.stressEsc)),
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return orderSectionCard(
      title: '전체 기록', icon: Icons.history_rounded,
      trailing: Text('${items.length}건', style: const TextStyle(
        fontSize: 10, fontWeight: FontWeight.w600, color: OC.text4)),
      children: [
        if (items.isEmpty)
          const Padding(padding: EdgeInsets.all(16),
            child: Text('기록이 없습니다', style: TextStyle(fontSize: 12, color: OC.text4)))
        else
          ...items.take(10).map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Container(width: 28, height: 28,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 13)))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: OC.text1),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(item.subtitle, style: const TextStyle(fontSize: 10, color: OC.text4)),
              ])),
              Text(DateFormat('M/d HH:mm').format(item.timestamp),
                style: const TextStyle(fontSize: 9, color: OC.text4)),
            ]),
          )),
        if (items.length > 10)
          Padding(padding: const EdgeInsets.only(top: 8),
            child: Center(child: Text('외 ${items.length - 10}건',
              style: const TextStyle(fontSize: 10, color: OC.text4)))),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  // SHEETS
  // ═══════════════════════════════════════════════════
  void _addSetbackSheet(BuildContext context) {
    final titleCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final lessonCtrl = TextEditingController();
    SetbackCategory selCat = SetbackCategory.examFail;
    String? selEmotion;
    final emotions = ['😢', '😤', '😔', '😶', '💪', '🤔'];

    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: const BoxDecoration(color: OC.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(
              color: OC.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('📖 좌절 기록', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: OC.text1)),
            const SizedBox(height: 4),
            const Text('실패도 성장의 기록입니다', style: TextStyle(fontSize: 11, color: OC.text3)),
            const SizedBox(height: 16),
            TextField(controller: titleCtrl,
              decoration: InputDecoration(hintText: '무슨 일이 있었나요?',
                hintStyle: const TextStyle(fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6,
              children: SetbackCategory.values.map((cat) {
                final sel = cat == selCat;
                return GestureDetector(
                  onTap: () => setLocal(() => selCat = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFF6366F1).withOpacity(0.1) : OC.cardHi,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sel ? const Color(0xFF6366F1) : OC.border)),
                    child: Text(_catLabel(cat), style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: sel ? const Color(0xFF6366F1) : OC.text3)),
                  ),
                );
              }).toList()),
            const SizedBox(height: 12),
            const Align(alignment: Alignment.centerLeft,
              child: Text('지금 기분은?', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: OC.text3))),
            const SizedBox(height: 6),
            Row(children: emotions.map((e) {
              final sel = e == selEmotion;
              return Expanded(child: GestureDetector(
                onTap: () => setLocal(() => selEmotion = sel ? null : e),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? const Color(0xFF6366F1).withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: sel ? Border.all(color: const Color(0xFF6366F1)) : null),
                  child: Center(child: Text(e, style: TextStyle(fontSize: sel ? 22 : 18))),
                ),
              ));
            }).toList()),
            const SizedBox(height: 12),
            TextField(controller: noteCtrl, maxLines: 2,
              decoration: InputDecoration(hintText: '느낀 점이나 상황 메모 (선택)',
                hintStyle: const TextStyle(fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(12)),
              style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            TextField(controller: lessonCtrl,
              decoration: InputDecoration(hintText: '💡 다음에는 어떻게? 교훈 (선택)',
                hintStyle: const TextStyle(fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                onUpdate(() { data.setbacks.add(SetbackLog(
                  id: 'sb_${DateTime.now().millisecondsSinceEpoch}',
                  title: titleCtrl.text.trim(), category: selCat,
                  emotion: selEmotion,
                  note: noteCtrl.text.isNotEmpty ? noteCtrl.text : null,
                  lesson: lessonCtrl.text.isNotEmpty ? lessonCtrl.text : null,
                )); });
                HapticFeedback.mediumImpact();
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('기록하기', style: TextStyle(
                fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)),
            )),
          ])),
        ),
      ),
    );
  }

  String _catLabel(SetbackCategory cat) {
    switch (cat) {
      case SetbackCategory.examFail: return '📝 시험 실패';
      case SetbackCategory.rejection: return '🚫 탈락/거절';
      case SetbackCategory.burnout: return '🔥 번아웃';
      case SetbackCategory.lostMotivation: return '😶 동기 상실';
      case SetbackCategory.health: return '🏥 건강';
      case SetbackCategory.other: return '📌 기타';
    }
  }

  void _showSetbackDetail(BuildContext context, SetbackLog sb) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: OC.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(
            color: OC.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text(sb.categoryEmoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(sb.title, style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w800, color: OC.text1)),
          const SizedBox(height: 4),
          Text('${sb.categoryLabel} · ${sb.date}',
            style: const TextStyle(fontSize: 12, color: OC.text3)),
          if (sb.emotion != null) ...[
            const SizedBox(height: 8),
            Text(sb.emotion!, style: const TextStyle(fontSize: 28)),
          ],
          if (sb.note != null) ...[
            const SizedBox(height: 16),
            Container(width: double.infinity, padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: OC.cardHi, borderRadius: BorderRadius.circular(12)),
              child: Text(sb.note!, style: const TextStyle(
                fontSize: 13, color: OC.text2, height: 1.5))),
          ],
          if (sb.lesson != null) ...[
            const SizedBox(height: 12),
            Container(width: double.infinity, padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.15))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('💡', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(child: Text(sb.lesson!, style: const TextStyle(
                  fontSize: 12, color: Color(0xFF10B981),
                  fontWeight: FontWeight.w600, height: 1.5))),
              ])),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () { onUpdate(() => data.setbacks.remove(sb)); Navigator.pop(ctx); },
              style: OutlinedButton.styleFrom(side: const BorderSide(color: OC.error),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('삭제', style: TextStyle(color: OC.error, fontWeight: FontWeight.w600)))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('닫기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)))),
          ]),
        ]),
      ),
    );
  }

  void _showAllSetbacks(BuildContext context) {
    final all = data.setbacks.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7, maxChildSize: 0.9, minChildSize: 0.3,
        builder: (ctx, scroll) => Container(
          decoration: const BoxDecoration(color: OC.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            Padding(padding: const EdgeInsets.all(16), child: Row(children: [
              const Text('📖 전체 좌절 기록', style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: OC.text1)),
              const Spacer(),
              Text('${all.length}건', style: const TextStyle(fontSize: 12, color: OC.text3)),
            ])),
            const Divider(height: 1),
            Expanded(child: ListView.builder(controller: scroll,
              padding: const EdgeInsets.all(16), itemCount: all.length,
              itemBuilder: (ctx, i) => _setbackCard(all[i]))),
          ]),
        ),
      ),
    );
  }
}

class _TimelineItem {
  final DateTime timestamp;
  final String emoji, title, subtitle, type;
  final Color color;
  const _TimelineItem({required this.timestamp, required this.emoji,
    required this.title, required this.subtitle,
    required this.type, required this.color});
}