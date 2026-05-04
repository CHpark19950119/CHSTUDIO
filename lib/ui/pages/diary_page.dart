// DAILY 일기 탭 — D5 결재 (HQ 1931 · 2026-05-05 02:31 KST)
// 매일 23:00 ~ 23:30 디지털 일기 작성. HB 자동 sanitize 후 Firestore 저장.
// 구조: 자유 텍스트 (300자) + 감정 1택 + 내일 할 것 1개.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/app.dart';
import '../../theme/theme.dart';
import '../widgets/common.dart';

class DiaryPage extends StatefulWidget {
  const DiaryPage({super.key});

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  final _textCtrl = TextEditingController();
  final _tomorrowCtrl = TextEditingController();
  String? _mood;
  bool _saving = false;
  String? _savedAt;

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users/$kUid/daily_log')
          .doc(_today)
          .get();
      final diary = doc.data()?['diary'] as Map<String, dynamic>?;
      if (diary != null) {
        setState(() {
          _textCtrl.text = (diary['text'] ?? '').toString();
          _mood = diary['mood'] as String?;
          _tomorrowCtrl.text = (diary['tomorrow'] ?? '').toString();
          _savedAt = diary['saved_at']?.toString();
        });
      }
    } catch (e) {
      debugPrint('[diary load] $e');
    }
  }

  Future<void> _save() async {
    if (_textCtrl.text.trim().isEmpty && _mood == null && _tomorrowCtrl.text.trim().isEmpty) {
      _toast('내용 없음');
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users/$kUid/daily_log')
          .doc(_today)
          .set({
        'diary': {
          'text': _sanitize(_textCtrl.text.trim()),
          'mood': _mood,
          'tomorrow': _tomorrowCtrl.text.trim(),
          'saved_at': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
      setState(() => _savedAt = DateTime.now().toIso8601String());
      _toast('저장됨');
    } catch (e) {
      _toast('저장 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// HB 자동 sanitize (간단 — feedback_sanitize_words.md 정책).
  /// 민감 단어를 토큰화 (예: "자위" → "[M]", "다영" → "[P]").
  String _sanitize(String input) {
    var t = input;
    final map = {'자위': '[M]', '다영': '[P]', '섹스': '[S]'};
    map.forEach((k, v) => t = t.replaceAll(k, v));
    return t;
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(DateTime.now());
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: DailyPalette.line),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(today, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('저녁 23:00 작성 권장 · HB 자동 sanitize',
                        style: theme.textTheme.bodySmall?.copyWith(color: DailyPalette.ash)),
                    if (_savedAt != null) ...[
                      const SizedBox(height: 6),
                      Text('마지막 저장: $_savedAt',
                          style: theme.textTheme.bodySmall?.copyWith(color: DailyPalette.gold)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: DailySpace.lg),
            SectionHeader(title: '오늘 어땠나?', accent: theme.colorScheme.primary),
            const SizedBox(height: DailySpace.sm),
            TextField(
              controller: _textCtrl,
              maxLines: 6,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: '자유롭게 적기 (300자 이내)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: DailyPalette.paper,
              ),
            ),
            const SizedBox(height: DailySpace.lg),
            SectionHeader(title: '감정', accent: DailyPalette.gold),
            const SizedBox(height: DailySpace.sm),
            Row(
              children: [
                _moodChip('good', '😊 좋음'),
                const SizedBox(width: 10),
                _moodChip('normal', '😐 보통'),
                const SizedBox(width: 10),
                _moodChip('hard', '😟 힘듦'),
              ],
            ),
            const SizedBox(height: DailySpace.lg),
            SectionHeader(title: '내일 할 것 1개', accent: theme.colorScheme.primary),
            const SizedBox(height: DailySpace.sm),
            TextField(
              controller: _tomorrowCtrl,
              maxLength: 80,
              decoration: InputDecoration(
                hintText: '예: 헌법 1단원 회독',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: DailyPalette.paper,
              ),
            ),
            const SizedBox(height: DailySpace.lg),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? '저장 중...' : '저장'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moodChip(String value, String label) {
    final selected = _mood == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mood = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? DailyPalette.goldSurface : DailyPalette.paper,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? DailyPalette.gold : DailyPalette.line, width: selected ? 2 : 1),
          ),
          child: Center(
            child: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _tomorrowCtrl.dispose();
    super.dispose();
  }
}
