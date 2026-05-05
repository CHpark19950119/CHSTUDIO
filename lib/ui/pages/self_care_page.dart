// DAILY · self_care 페이지 v13.1 — 사용자 5/5 14:35 명시 (간단히 = 횟수·날짜·방법)
// 3 필드만: 횟수 (오늘 누적) + 날짜 (자동) + 방법 (M / MV / V / partner)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/app.dart';
import '../../theme/theme.dart';

class SelfCarePage extends StatefulWidget {
  const SelfCarePage({super.key});

  @override
  State<SelfCarePage> createState() => _SelfCarePageState();
}

class _SelfCarePageState extends State<SelfCarePage> {
  String _method = 'M';
  bool _saving = false;

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> _add() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users/$kUid/self_care_log').add({
        'date': _today,
        'ts': FieldValue.serverTimestamp(),
        'method': _method,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('기록 추가 ($_method)'), duration: const Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: DailyPalette.paper,
        elevation: 0,
        title: const Text('self_care'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 오늘 카운트
              _TodayCountCard(),
              const SizedBox(height: 24),

              // 방법 선택
              Text('방법', style: theme.textTheme.titleSmall?.copyWith(color: DailyPalette.ash, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _methodChip('M', 'M (자위)'),
                  _methodChip('MV', 'MV (영상)'),
                  _methodChip('V', 'V (영상만)'),
                  _methodChip('partner', 'partner'),
                ],
              ),
              const SizedBox(height: 24),

              // 추가 버튼
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _add,
                  icon: const Icon(Icons.add),
                  label: Text(_saving ? '저장 중...' : '+ 기록 추가'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: DailyPalette.gold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 최근 기록
              Text('최근 기록', style: theme.textTheme.titleSmall?.copyWith(color: DailyPalette.ash, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Expanded(child: _RecentSimpleList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodChip(String value, String label) {
    final selected = _method == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _method = value),
      selectedColor: DailyPalette.goldSurface,
      side: BorderSide(color: selected ? DailyPalette.gold : DailyPalette.line, width: selected ? 2 : 1),
      labelStyle: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
    );
  }
}

class _TodayCountCard extends StatelessWidget {
  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users/$kUid/self_care_log')
          .where('date', isEqualTo: _today)
          .snapshots(),
      builder: (ctx, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: DailyPalette.goldSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DailyPalette.gold.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Text(_today.substring(5), style: theme.textTheme.titleMedium?.copyWith(color: DailyPalette.ash)),
              const Spacer(),
              Text('$count회', style: theme.textTheme.headlineMedium?.copyWith(
                color: DailyPalette.gold, fontWeight: FontWeight.w800,
              )),
            ],
          ),
        );
      },
    );
  }
}

class _RecentSimpleList extends StatelessWidget {
  const _RecentSimpleList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users/$kUid/self_care_log')
          .orderBy('ts', descending: true)
          .limit(20)
          .snapshots(),
      builder: (ctx, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text('기록 없음', style: theme.textTheme.bodyMedium?.copyWith(color: DailyPalette.ash)),
          );
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final ts = d['ts'] as Timestamp?;
            final timeStr = ts != null ? DateFormat('MM/dd HH:mm').format(ts.toDate()) : '?';
            final method = d['method']?.toString() ?? '?';
            return ListTile(
              dense: true,
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: DailyPalette.goldSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(method,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: DailyPalette.gold, fontWeight: FontWeight.w800,
                    fontSize: method.length > 2 ? 11 : 14,
                  ),
                ),
              ),
              title: Text(timeStr, style: theme.textTheme.bodyMedium),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline, color: DailyPalette.ash, size: 20),
                onPressed: () => docs[i].reference.delete(),
              ),
            );
          },
        );
      },
    );
  }
}
