// 공통 UI 위젯 — DAILY 상품급 디자인 시스템.
// 사용자 지시 (2026-04-28 23:18): 전면개편 + dark mode + 상품급.
import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Hero Card — 페이지 상단 강조 카드 (그라데이션 + 큰 제목 + 부제 + 액션).
class HeroCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? trailing;
  final List<Color>? gradient;
  final EdgeInsets padding;

  const HeroCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.trailing,
    this.gradient,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = gradient ??
        (theme.brightness == Brightness.dark
            ? [DailyPalette.cardDark, DailyPalette.paperDark]
            : [DailyPalette.cream, DailyPalette.goldSurface]);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DailySpace.radiusXL),
        border: Border.all(color: theme.dividerTheme.color ?? DailyPalette.line, width: 0.6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: DailyPalette.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: DailyPalette.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 섹션 헤더 — 페이지 안 sub-section 구분.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? badge;
  final Color? accent;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.badge, this.accent, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? DailyPalette.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Text(title, style: theme.textTheme.titleMedium),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(badge!, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800)),
            ),
          ],
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Empty state — 데이터 없을 때 시각.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Skeleton 로딩.
class Skeleton extends StatelessWidget {
  final double width, height;
  final BorderRadius? borderRadius;
  const Skeleton({super.key, this.width = double.infinity, this.height = 16, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.brightness == Brightness.dark
        ? DailyPalette.lineDark
        : DailyPalette.line;
    return Container(
      width: width, height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius ?? BorderRadius.circular(6),
      ),
    );
  }
}

/// 통계 카드 (가로 layout · 큰 숫자 + 라벨 + 변화).
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final IconData icon;
  final Color? accent;
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    required this.icon,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? DailyPalette.primary;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? DailyPalette.cardDark : DailyPalette.card,
        borderRadius: BorderRadius.circular(DailySpace.radiusL),
        border: Border.all(color: isDark ? DailyPalette.lineDark : DailyPalette.line, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: theme.textTheme.labelMedium),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
