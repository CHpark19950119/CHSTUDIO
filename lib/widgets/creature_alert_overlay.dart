import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// SafetyNet 알림 시 크리쳐가 나타나는 풀스크린 오버레이
class CreatureAlertOverlay extends StatefulWidget {
  final String title;
  final String body;
  final String? confirmLabel;
  final String? dismissLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onDismiss;

  const CreatureAlertOverlay({
    super.key,
    required this.title,
    required this.body,
    this.confirmLabel = '맞아',
    this.dismissLabel = '아니야',
    this.onConfirm,
    this.onDismiss,
  });

  /// 글로벌 네비게이터로 오버레이 표시
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String body,
    String? confirmLabel,
    String? dismissLabel,
    VoidCallback? onConfirm,
    VoidCallback? onDismiss,
  }) {
    HapticFeedback.heavyImpact();
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => CreatureAlertOverlay(
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        dismissLabel: dismissLabel,
        onConfirm: onConfirm,
        onDismiss: onDismiss,
      ),
    );
  }

  @override
  State<CreatureAlertOverlay> createState() => _CreatureAlertOverlayState();
}

class _CreatureAlertOverlayState extends State<CreatureAlertOverlay>
    with TickerProviderStateMixin {
  late AnimationController _bounceCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _bounceAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _bounceCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800));
    _bounceAnim = CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut);

    _fadeCtrl.forward();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _bounceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _handleConfirm() {
    widget.onConfirm?.call();
    Navigator.of(context).pop();
  }

  void _handleDismiss() {
    widget.onDismiss?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Center(
        child: ScaleTransition(
          scale: _bounceAnim,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFF6366F1).withOpacity(0.4), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                  blurRadius: 40, spreadRadius: 4),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // 크리쳐 이미지
              _CreatureAvatar(),
              const SizedBox(height: 16),
              // 말풍선
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  Text(widget.title,
                    style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900,
                      color: Colors.white),
                    textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(widget.body,
                    style: TextStyle(
                      fontSize: 13, color: Colors.white.withOpacity(0.7),
                      height: 1.4),
                    textAlign: TextAlign.center),
                ]),
              ),
              const SizedBox(height: 20),
              // 버튼
              Row(children: [
                if (widget.dismissLabel != null) Expanded(
                  child: _AlertBtn(
                    label: widget.dismissLabel!,
                    color: Colors.white.withOpacity(0.1),
                    textColor: Colors.white70,
                    onTap: _handleDismiss)),
                if (widget.dismissLabel != null && widget.confirmLabel != null)
                  const SizedBox(width: 12),
                if (widget.confirmLabel != null) Expanded(
                  child: _AlertBtn(
                    label: widget.confirmLabel!,
                    color: const Color(0xFF6366F1),
                    textColor: Colors.white,
                    onTap: _handleConfirm)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _AlertBtn extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _AlertBtn({
    required this.label, required this.color,
    required this.textColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(14)),
        child: Center(child: Text(label,
          style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w800, color: textColor))),
      ),
    );
  }
}

/// 크리쳐 아바타 — sprite sheet 첫 프레임 + 호흡 애니메이션
class _CreatureAvatar extends StatefulWidget {
  @override
  State<_CreatureAvatar> createState() => _CreatureAvatarState();
}

class _CreatureAvatarState extends State<_CreatureAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathCtrl;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breathCtrl,
      builder: (context, child) {
        final offset = math.sin(_breathCtrl.value * math.pi) * 4;
        return Transform.translate(
          offset: Offset(0, -offset),
          child: child);
      },
      child: Container(
        width: 100, height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              const Color(0xFF6366F1).withOpacity(0.2),
              Colors.transparent]),
        ),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: SizedBox(
              width: 80, height: 80,
              child: FittedBox(
                fit: BoxFit.cover,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 128, height: 128,
                  child: Image.asset(
                    'assets/image/creature_3d_sheet_128.png',
                    width: 768, height: 768,
                    alignment: Alignment.topLeft,
                    fit: BoxFit.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
