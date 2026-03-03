import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/botanical_theme.dart';
import '../services/alarm_service.dart';
import '../services/focus_timer_service.dart';
import '../services/focus_mode_service.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../services/nfc_service.dart';
import '../services/weather_service.dart';
import '../services/briefing_service.dart';
import '../services/sleep_service.dart';
import '../services/ai_calendar_service.dart';
import '../models/models.dart';
import 'alarm_settings_screen.dart';
import 'focus_session_screen.dart';
import 'location_screen.dart';
import 'nfc_screen.dart' hide StatisticsScreen;
import 'qr_wake_screen.dart';
import 'settings_screen.dart';
import 'calendar_screen.dart';
import 'statistics_screen.dart';
import 'progress_screen.dart';
import 'painters.dart';
import 'package:flutter/services.dart';
import 'status_editor_sheet.dart';
import 'focus_records_widget.dart';
import 'insight_screen.dart';
import 'order/order_screen.dart';
import 'daily_plan_sheet.dart';
import '../models/order_models.dart';
import '../models/plan_models.dart';
import '../services/plan_service.dart';
import '../services/exam_ticket_service.dart';

part 'home_focus_section.dart';
part 'home_daily_log.dart';
part 'home_routine_card.dart';
part 'home_order_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _ft = FocusTimerService();
  final _ls = LocationService();
  final _nfc = NfcService();
  final _weather = WeatherService();
  final _sleepSvc = SleepService();
  Timer? _ui;
  bool _playedEntryAnim = false;
  String? _wake, _studyStart, _studyEnd;
  String? _outing, _returnHome;
  String? _bedTime;
  String? _mealStart, _mealEnd;
  int? _outingMinutes;
  int _effMin = 0;
  DailyGrade? _grade;
  AlarmSettings _alarm = AlarmSettings();
  String? _currentPlace;
  bool _locationTracking = false;
  WeatherData? _weatherData;
  SleepGrade? _lastSleepGrade;
  bool _noOuting = false; // ★ v10: 외출 안하는 날
  int _tab = 0;
  List<BehaviorTimelineEntry> _todayTimeline = [];
  List<MealEntry> _todayMeals = []; // ★ v9: 다회 식사
  List<String> _dailyMemos = [];   // ★ 데일리 메모

  // ★ R2: COMPASS 대시보드 데이터
  OrderData? _orderData;
  List<ExamTicketInfo> _examTickets = [];

  // ★ 오늘의 일일 계획
  DailyPlan? _todayPlan;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _fbSub;

  late AnimationController _staggerController;
  final List<Animation<double>> _fadeAnims = [];
  final List<Animation<Offset>> _slideAnims = [];
  static const _cardCount = 6;

  // ★ 작업4: 모션 이펙트 컨트롤러
  late AnimationController _breathCtrl;   // A) Breathing Glow (3초)
  late AnimationController _particleCtrl; // B) Floating Particles (10초)
  late AnimationController _blobCtrl;     // C) Morphing Blob (8초)
  late AnimationController _shimmerCtrl;  // D) Shimmer Scan (2.5초)
  late AnimationController _pulseCtrl;    // F) Pulse Ring (2초)

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
    for (int i = 0; i < _cardCount; i++) {
      final start = i * 0.12;
      final end = (start + 0.35).clamp(0.0, 1.0);
      _fadeAnims.add(CurvedAnimation(
        parent: _staggerController,
        curve: Interval(start, end, curve: Curves.easeOut)));
      _slideAnims.add(Tween<Offset>(
        begin: const Offset(0, 0.12), end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _staggerController,
        curve: Interval(start, end, curve: Curves.easeOutCubic))));
    }
    _load(playAnim: true);
    _checkPendingWake();
    _startFirebaseListener();
    _runMigration0223(); // 1회성 22일 기록 이관

    // ★ 작업4: 모션 이펙트 초기화
    _breathCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _particleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _blobCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

    _nfc.onStateChanged = () {
      if (mounted) _load(playAnim: false);
    };
    _ui = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final isOut = _outing != null && _returnHome == null;
      if (_ft.isRunning || isOut) setState(() {});
    });
  }

  @override
  void dispose() {
    _ui?.cancel();
    _fbSub?.cancel();
    _nfc.onStateChanged = null;
    _staggerController.dispose();
    // ★ 모션 이펙트 dispose
    _breathCtrl.dispose();
    _particleCtrl.dispose();
    _blobCtrl.dispose();
    _shimmerCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startFirebaseListener() {
    _fbSub = FirebaseService().watchStudyData().listen((snap) {
      if (!snap.exists || !mounted) return;
      final data = snap.data();
      if (data == null) return;
      final d = _studyDate();
      String? wake, study, studyEnd, outing, returnHome, bedTime, mealStart, mealEnd;
      List<MealEntry> meals = [];
      bool noOuting = false;
      int effMin = 0;
      final trRaw = data['timeRecords'] as Map<String, dynamic>?;
      if (trRaw != null && trRaw[d] != null) {
        final tr = TimeRecord.fromMap(d, trRaw[d] as Map<String, dynamic>);
        wake = tr.wake; study = tr.study; studyEnd = tr.studyEnd;
        outing = tr.outing; returnHome = tr.returnHome;
        bedTime = tr.bedTime;
        mealStart = tr.mealStart; mealEnd = tr.mealEnd;
        meals = tr.meals;
        noOuting = tr.noOuting;
      }
      final strRaw = data['studyTimeRecords'] as Map<String, dynamic>?;
      if (strRaw != null && strRaw[d] != null) {
        final str = StudyTimeRecord.fromMap(d, strRaw[d] as Map<String, dynamic>);
        effMin = str.effectiveMinutes;
      }
      if (mounted) {
        setState(() {
          _wake = wake; _studyStart = study; _studyEnd = studyEnd; _effMin = effMin;
          _outing = outing; _returnHome = returnHome; _bedTime = bedTime;
          _mealStart = mealStart; _mealEnd = mealEnd;
          _todayMeals = meals;
          _noOuting = noOuting;
          _outingMinutes = (outing != null && returnHome != null)
              ? TimeRecord(date: d, outing: outing, returnHome: returnHome).outingMinutes
              : null;
          _grade = DailyGrade.calculate(
            date: d, wakeTime: wake,
            studyStartTime: study, effectiveMinutes: effMin);
        });
      }
    });
  }

  Future<void> _load({bool playAnim = false}) async {
    final d = _studyDate();
    final yesterday = DateFormat('yyyy-MM-dd').format(
        DateFormat('yyyy-MM-dd').parse(d).subtract(const Duration(days: 1)));
    try {
      final fb = FirebaseService();
      final tr = await fb.getTimeRecords();
      final sr = await fb.getStudyTimeRecords();
      _alarm = await fb.getAlarmSettings();
      _currentPlace = _ls.currentPlaceName;
      _locationTracking = _ls.isTracking;
      _weatherData = await _weather.getCurrentWeather();
      _lastSleepGrade = await _sleepSvc.getSleepGrade(yesterday);
      List<BehaviorTimelineEntry> tl = [];
      try { tl = await fb.getBehaviorTimeline(d); } catch (_) {}
      setState(() {
        _todayTimeline = tl;
        _wake = tr[d]?.wake;
        _studyStart = tr[d]?.study;
        _studyEnd = tr[d]?.studyEnd;
        _outing = tr[d]?.outing;
        _returnHome = tr[d]?.returnHome;
        _bedTime = tr[d]?.bedTime;
        _mealStart = tr[d]?.mealStart;
        _mealEnd = tr[d]?.mealEnd;
        _todayMeals = tr[d]?.meals ?? [];
        _noOuting = tr[d]?.noOuting ?? false;
        _outingMinutes = tr[d]?.outingMinutes;
        _effMin = sr[d]?.effectiveMinutes ?? 0;
        _grade = DailyGrade.calculate(
          date: d, wakeTime: _wake,
          studyStartTime: _studyStart, effectiveMinutes: _effMin);
      });
      // ★ 데일리 메모 로딩
      try {
        final memos = await AiCalendarService().getMemosForDate(d);
        if (mounted) setState(() => _dailyMemos = memos);
      } catch (_) {}
      // ★ R2: ORDER 데이터 + 수험표 로딩
      try {
        final raw = await fb.getData();
        if (raw != null && raw['orderData'] != null) {
          final od = OrderData.fromMap(
              Map<String, dynamic>.from(raw['orderData'] as Map));
          if (mounted) setState(() => _orderData = od);
        }
      } catch (_) {}
      try {
        final tickets = await ExamTicketService().loadAllTickets();
        if (mounted) setState(() => _examTickets = tickets);
      } catch (_) {}
      // ★ 오늘의 계획 로드
      try {
        final plan = await PlanService().getTodayPlan();
        if (mounted) setState(() => _todayPlan = plan);
      } catch (_) {}
    } catch (_) {}
    if (playAnim && mounted && !_playedEntryAnim) {
      _playedEntryAnim = true;
      _staggerController.reset();
      _staggerController.forward();
    }
  }

  Future<void> _checkPendingWake() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (_alarm.nfcWakeEnabled) return;
    final pending = await AlarmService.hasPendingQrWake();
    if (pending && mounted) {
      final result = await Navigator.push(context,
          MaterialPageRoute(builder: (_) => QrWakeScreen(settings: _alarm)));
      if (result == true) {
        await AlarmService.completeQrWake();
        final time = DateFormat('HH:mm').format(DateTime.now());
        await _sleepSvc.completeWakeRecord(time);
        _load(playAnim: true);
      }
    }
  }

  /// 학습일 계산: 새벽 0~4시는 전날로 취급
  String _studyDate() {
    final now = DateTime.now();
    final effective = now.hour < 4
        ? now.subtract(const Duration(days: 1))
        : now;
    return DateFormat('yyyy-MM-dd').format(effective);
  }

  /// 1회성 마이그레이션: 2026-02-23 기록 → 2026-02-22로 이관, 귀가 23:30 설정
  Future<void> _runMigration0223() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('migration_0223_done') == true) return;
    try {
      await FirebaseService().migrateDateRecords(
        fromDate: '2026-02-23',
        toDate: '2026-02-22',
        timeRecordOverrides: {'returnHome': '23:30'},
      );
      await prefs.setBool('migration_0223_done', true);
      if (mounted) _load(playAnim: false);
    } catch (e) {
      debugPrint('Migration 0223 error: $e');
    }
  }

  bool get _dk => Theme.of(context).brightness == Brightness.dark;
  Color get _textMain => _dk ? BotanicalColors.textMainDark : BotanicalColors.textMain;
  Color get _textSub => _dk ? BotanicalColors.textSubDark : BotanicalColors.textSub;
  Color get _textMuted => _dk ? BotanicalColors.textMutedDark : BotanicalColors.textMuted;
  Color get _border => _dk ? BotanicalColors.borderDark : BotanicalColors.borderLight;
  Color get _accent => _dk ? BotanicalColors.lanternGold : BotanicalColors.gold;

  Widget _staggered(int index, Widget child) {
    final i = index.clamp(0, _cardCount - 1);
    return FadeTransition(
      opacity: _fadeAnims[i],
      child: SlideTransition(position: _slideAnims[i], child: child));
  }

  // ══════════════════════════════════════════
  //  빌드: BottomNav (대시보드 / 도구)
  // ══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        _paperBackground(),
        IndexedStack(
          index: _tab,
          children: [
            SafeArea(child: _dashboardPage()),
            SafeArea(child: _focusPage()),
            SafeArea(child: _recordsPage()),
            const SafeArea(child: ProgressScreen()),
            SafeArea(child: CalendarScreen(embedded: true)),
          ],
        ),
      ]),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _paperBackground() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            stops: const [0.0, 0.3, 0.7, 1.0],
            colors: _dk
              ? [const Color(0xFF1C1410), const Color(0xFF1A1210),
                 const Color(0xFF1D1512), const Color(0xFF181010)]
              : [const Color(0xFFFDF9F2), const Color(0xFFFAF5EC),
                 const Color(0xFFF6F0E5), const Color(0xFFF2ECDF)],
          ),
        ),
        child: CustomPaint(painter: PaperGrainPainter(_dk)),
      ),
    );
  }

  Widget _bottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _dk ? BotanicalColors.cardDark : Colors.white,
        border: Border(top: BorderSide(color: _border.withOpacity(0.3), width: 0.5)),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(_dk ? 0.3 : 0.04),
          blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _navItem(0, Icons.dashboard_rounded, '홈'),
            _navItem(1, Icons.local_fire_department_rounded, '포커스'),
            _navItem(2, Icons.bar_chart_rounded, '기록'),
            _navItem(3, Icons.trending_up_rounded, '진행도'),
            _navItem(4, Icons.calendar_month_rounded, '캘린더'),
          ]),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final sel = _tab == index;
    final c = sel
      ? (_dk ? BotanicalColors.lanternGold : BotanicalColors.primary)
      : _textMuted;
    final showLive = index == 1 && _ft.isRunning && !sel;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            Icon(icon, size: 22, color: c),
            if (showLive) Positioned(right: -3, top: -2,
              child: Container(width: 7, height: 7,
                decoration: BoxDecoration(
                  color: BotanicalColors.primary, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: BotanicalColors.primary.withOpacity(0.5),
                    blurRadius: 4, spreadRadius: 1)]))),
          ]),
          const SizedBox(height: 3),
          Text(label, style: BotanicalTypo.label(
            size: 10, weight: sel ? FontWeight.w800 : FontWeight.w600, color: c)),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════
  //  TAB 0: 대시보드
  // ══════════════════════════════════════════

  Widget _dashboardPage() {
    return RefreshIndicator(
      color: BotanicalColors.primary,
      onRefresh: () => _load(playAnim: false),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ★ #10: 날씨 + 헤더 통합 상단바
          _staggered(0, _weatherHeaderBar()),
          const SizedBox(height: 14),
          _staggered(0, _orderPortalChip()),   // ★ 최상단 배치
          const SizedBox(height: 14),
          _staggered(1, _nfcStatusCard()),
          const SizedBox(height: 16),
          _staggered(2, _heroStatsRow()),
          const SizedBox(height: 16),
          if (_todayTimeline.isNotEmpty || _wake != null) ...[
            _staggered(3, _locationSummaryCard()),
            const SizedBox(height: 16),
          ],
          if (_ft.isRunning) ...[
            _staggered(4, _activeFocusBanner()),
            const SizedBox(height: 12),
          ],
          // ★ #9: 데일리 메모 컴팩트 위젯
          if (_dailyMemos.isNotEmpty || true) ...[
            _staggered(4, _dashboardMemoWidget()),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
          // ★ 기존 _orderPortalCard() 제거됨
          _staggered(4, _quickToolsRow()),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  //  TAB 2: 도구 (자동화 + 시스템)
  // ══════════════════════════════════════════

  Widget _toolsPage() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        Text('도구', style: BotanicalTypo.heading(
          size: 26, weight: FontWeight.w800, color: _textMain)),
        const SizedBox(height: 4),
        Text('자동화와 시스템 관리', style: BotanicalTypo.label(
          size: 13, color: _textMuted)),
        const SizedBox(height: 24),

        _sectionHeader('⚡', '자동화'),
        const SizedBox(height: 10),
        _toolCard(
          icon: '📡', label: 'NFC 관리',
          subtitle: _nfc.tags.isNotEmpty ? '${_nfc.tags.length}개 태그 등록됨' : '태그 등록 및 설정',
          color: const Color(0xFFB05C8A),
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => NfcScreen()))
            .then((_) => _load(playAnim: false)),
        ),
        _toolCard(
          icon: '⏰', label: '기상 알람',
          subtitle: _alarm.enabled ? '목표 ${_alarm.targetWakeTime}' : '알람 설정',
          color: const Color(0xFFD4953B),
          trailing: _wake != null ? Text('✓', style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w800, color: _accent)) : null,
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AlarmSettingsScreen()))
            .then((_) => _load(playAnim: false)),
        ),
        _toolCard(
          icon: '📍', label: '위치 추적',
          subtitle: _locationTracking
            ? (_currentPlace ?? 'GPS 추적 중')
            : 'GPS 동선 기록',
          color: const Color(0xFF3B8A6B),
          isLive: _locationTracking,
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const LocationScreen()))
            .then((_) => _load(playAnim: false)),
        ),
        const SizedBox(height: 20),

        _sectionHeader('⚙️', '시스템'),
        const SizedBox(height: 10),
        // ★ #5: 데일리 인사이트
        _toolCard(
          icon: '💡', label: '데일리 인사이트',
          subtitle: '학습 회고 & 인사이트 기록',
          color: const Color(0xFFF59E0B),
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const InsightScreen())),
        ),
        const SizedBox(height: 20),

        _sectionHeader('🔧', '앱 설정'),
        const SizedBox(height: 10),
        _toolCard(
          icon: '⚙️', label: '설정',
          subtitle: '앱 설정 및 데이터 관리',
          color: _textSub,
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ══════════════════════════════════════════
  //  TAB 2: 기록
  // ══════════════════════════════════════════

  Widget _recordsPage() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        Text('기록', style: BotanicalTypo.heading(
          size: 26, weight: FontWeight.w800, color: _textMain)),
        const SizedBox(height: 4),
        Text('학습 통계와 생활 기록', style: BotanicalTypo.label(
          size: 13, color: _textMuted)),
        const SizedBox(height: 16),

        // ── 통계 화면 (세그먼트 컨트롤 포함) ──
        const StatisticsScreen(embedded: true),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _sectionHeader(String emoji, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Text(title, style: BotanicalTypo.label(
          size: 13, weight: FontWeight.w800, letterSpacing: 0.5, color: _textMain)),
      ]),
    );
  }

  Widget _toolCard({
    required String icon, required String label, required String subtitle,
    required Color color, required VoidCallback onTap,
    bool isLive = false, Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _dk ? color.withOpacity(0.06) : Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _dk
            ? color.withOpacity(0.12) : color.withOpacity(0.08)),
          boxShadow: _dk ? null : [
            BoxShadow(color: color.withOpacity(0.04),
              blurRadius: 12, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(_dk ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(12)),
            child: Center(
              child: Stack(clipBehavior: Clip.none, children: [
                Text(icon, style: const TextStyle(fontSize: 20)),
                if (isLive)
                  Positioned(right: -3, top: -3,
                    child: Container(width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: BotanicalColors.success, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                          color: BotanicalColors.success.withOpacity(0.5),
                          blurRadius: 6, spreadRadius: 1)]))),
              ]),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: BotanicalTypo.body(
              size: 14, weight: FontWeight.w700, color: _textMain)),
            const SizedBox(height: 2),
            Text(subtitle, style: BotanicalTypo.label(
              size: 11, color: _textMuted),
              overflow: TextOverflow.ellipsis, maxLines: 1),
          ])),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 18, color: _textMuted.withOpacity(0.5)),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════
  //  ① 헤더 + 날씨 통합 상단바
  // ══════════════════════════════════════════

  Widget _weatherHeaderBar() {
    final now = DateTime.now();
    final wd = ['월','화','수','목','금','토','일'][now.weekday - 1];
    final w = _weatherData;

    return Column(children: [
      // ── 날씨 상단바 (컴팩트) ──
      if (w != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: BotanicalColors.weatherGradient(w.main),
              begin: Alignment.centerLeft, end: Alignment.centerRight),
            borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Text(w.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text('${w.temp.round()}°', style: BotanicalTypo.number(
              size: 17, weight: FontWeight.w600, color: Colors.white)),
            const SizedBox(width: 6),
            Text(w.description, style: BotanicalTypo.label(
              size: 11, color: Colors.white.withOpacity(0.85))),
            const Spacer(),
            Text('체감 ${w.feelsLike.round()}°', style: BotanicalTypo.label(
              size: 10, color: Colors.white.withOpacity(0.7))),
            const SizedBox(width: 6),
            Text('${w.tempMax.round()}°/${w.tempMin.round()}°',
              style: BotanicalTypo.label(size: 10, weight: FontWeight.w600,
                color: Colors.white.withOpacity(0.8))),
            if (_weather.needsUmbrella(w)) ...[
              const SizedBox(width: 6),
              const Text('☂️', style: TextStyle(fontSize: 12)),
            ],
          ]),
        ),
      if (w != null) const SizedBox(height: 10),

      // ── 기존 헤더 (날짜 + 메모/설정 아이콘) ──
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('CHEONHONG', style: BotanicalTypo.brand(
              color: _dk ? BotanicalColors.lanternGold : BotanicalColors.primary)),
            const SizedBox(height: 4),
            Text('${now.month}월 ${now.day}일 ($wd)',
              style: BotanicalTypo.heading(size: 22, weight: FontWeight.w800, color: _textMain)),
          ]),
          Row(children: [
            // ★ 메모 아이콘
            GestureDetector(
              onTap: _showAddMemoDialog,
              child: Container(
                width: 36, height: 36,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _dk ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.edit_note_rounded, size: 20, color: _textMuted)),
            ),
            // 설정 아이콘
            GestureDetector(
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _dk ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.settings_outlined, size: 18, color: _textMuted)),
            ),
          ]),
        ],
      ),
    ]);
  }

  // ══════════════════════════════════════════
  //  ★ #9: 데일리 메모 대시보드 위젯
  // ══════════════════════════════════════════

  Widget _dashboardMemoWidget() {
    return GestureDetector(
      onTap: _showAddMemoDialog,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _dk ? const Color(0xFF2A2218).withOpacity(0.6) : const Color(0xFFFFFBF5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFB07D3A).withOpacity(_dk ? 0.15 : 0.1)),
          boxShadow: _dk ? null : [
            BoxShadow(color: const Color(0xFFB07D3A).withOpacity(0.04),
              blurRadius: 12, offset: const Offset(0, 3))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFB07D3A).withOpacity(_dk ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(8)),
              child: const Text('📝', style: TextStyle(fontSize: 12))),
            const SizedBox(width: 8),
            Text('오늘의 메모', style: BotanicalTypo.label(
              size: 12, weight: FontWeight.w700,
              color: _dk ? const Color(0xFFD4A66A) : const Color(0xFFB07D3A))),
            const Spacer(),
            if (_dailyMemos.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFB07D3A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
                child: Text('${_dailyMemos.length}', style: BotanicalTypo.label(
                  size: 10, weight: FontWeight.w800,
                  color: const Color(0xFFB07D3A)))),
            const SizedBox(width: 6),
            Icon(Icons.add_circle_outline_rounded, size: 16,
              color: _textMuted.withOpacity(0.5)),
          ]),
          if (_dailyMemos.isNotEmpty) ...[
            const SizedBox(height: 10),
            ..._dailyMemos.take(3).map((memo) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 4, height: 4,
                    decoration: BoxDecoration(
                      color: _textMuted.withOpacity(0.3),
                      shape: BoxShape.circle))),
                const SizedBox(width: 8),
                Expanded(child: Text(memo, style: BotanicalTypo.label(
                  size: 11, color: _textSub),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            )),
            if (_dailyMemos.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('+${_dailyMemos.length - 3}개 더보기',
                  style: BotanicalTypo.label(size: 10, weight: FontWeight.w600,
                    color: _textMuted.withOpacity(0.5)))),
          ] else ...[
            const SizedBox(height: 8),
            Text('탭하여 메모를 추가하세요', style: BotanicalTypo.label(
              size: 11, color: _textMuted.withOpacity(0.5))),
          ],
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════
  //  ② 히어로 카드
  // ══════════════════════════════════════════

  Widget _heroStatsRow() {
    final g = _grade ?? DailyGrade.calculate(
      date: _studyDate());
    final gc = BotanicalColors.gradeColor(g.grade);
    final flower = GrowthMetaphor.gradeFlower(g.grade);
    final h = _effMin ~/ 60;
    final m = _effMin % 60;

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: _dk
                ? [const Color(0xFF1E3A2F), const Color(0xFF1A2E26)]
                : [const Color(0xFFE8F5E9), const Color(0xFFF1F8E9)]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BotanicalColors.primary.withOpacity(_dk ? 0.3 : 0.15)),
            boxShadow: [BoxShadow(
              color: BotanicalColors.primary.withOpacity(_dk ? 0.15 : 0.08),
              blurRadius: 20, offset: const Offset(0, 6))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: BotanicalColors.primary.withOpacity(_dk ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.timer_outlined, size: 14,
                  color: _dk ? BotanicalColors.primaryLight : BotanicalColors.primary)),
              const SizedBox(width: 8),
              Text('순공시간', style: BotanicalTypo.label(
                size: 11, weight: FontWeight.w700,
                color: _dk ? BotanicalColors.primaryLight : BotanicalColors.primary)),
            ]),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic, children: [
              Text('$h', style: BotanicalTypo.number(size: 38, weight: FontWeight.w300,
                color: _dk ? Colors.white : BotanicalColors.textMain)),
              Text('h ', style: BotanicalTypo.label(size: 15, weight: FontWeight.w300,
                color: _dk ? Colors.white54 : BotanicalColors.textSub)),
              Text('${m.toString().padLeft(2, '0')}', style: BotanicalTypo.number(
                size: 26, weight: FontWeight.w300,
                color: _dk ? Colors.white70 : BotanicalColors.textSub)),
              Text('m', style: BotanicalTypo.label(size: 13, weight: FontWeight.w300,
                color: _dk ? Colors.white38 : BotanicalColors.textMuted)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_effMin / 480).clamp(0.0, 1.0),
                backgroundColor: _dk
                  ? Colors.white.withOpacity(0.08)
                  : BotanicalColors.primary.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(
                  _dk ? BotanicalColors.primaryLight : BotanicalColors.primary),
                minHeight: 4)),
            const SizedBox(height: 3),
            Text('목표 8h · ${(_effMin / 480 * 100).toInt()}%',
              style: BotanicalTypo.label(size: 10,
                color: _dk ? Colors.white38 : BotanicalColors.textMuted)),
          ]),
        )),
        const SizedBox(width: 10),
        Expanded(child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: _dk
                ? [gc.withOpacity(0.15), gc.withOpacity(0.08)]
                : [gc.withOpacity(0.06), gc.withOpacity(0.03)]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: gc.withOpacity(_dk ? 0.3 : 0.15)),
            boxShadow: [BoxShadow(
              color: gc.withOpacity(_dk ? 0.12 : 0.08),
              blurRadius: 20, offset: const Offset(0, 6))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: gc.withOpacity(_dk ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(8)),
                child: Text(flower, style: const TextStyle(fontSize: 12))),
              const SizedBox(width: 8),
              Text('TODAY', style: BotanicalTypo.label(
                size: 11, weight: FontWeight.w700, letterSpacing: 1.5, color: gc)),
            ]),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic, children: [
              Text(g.grade, style: BotanicalTypo.heading(size: 34, weight: FontWeight.w900,
                color: gc)),
              const SizedBox(width: 8),
              Text(g.totalScore.toStringAsFixed(1),
                style: BotanicalTypo.number(size: 22, weight: FontWeight.w300,
                  color: _dk ? Colors.white54 : BotanicalColors.textMuted)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (g.totalScore / 100).clamp(0.0, 1.0),
                backgroundColor: _dk ? Colors.white.withOpacity(0.08) : gc.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(gc),
                minHeight: 4)),
            const SizedBox(height: 3),
            Text('${g.totalScore.toStringAsFixed(0)} / 100',
              style: BotanicalTypo.label(size: 10,
                color: _dk ? Colors.white38 : BotanicalColors.textMuted)),
          ]),
        )),
      ]),
    );
  }

  // ══════════════════════════════════════════
  //  ③ 스코어 브레이크다운
  // ══════════════════════════════════════════

  Widget _scoreBreakdown() {
    final g = _grade ?? DailyGrade.calculate(
      date: _studyDate());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BotanicalDeco.card(_dk),
      child: Row(children: [
        _scoreCell('기상', _fmt12h(_wake), g.wakeScore, 25,
          BotanicalColors.gold, Icons.wb_sunny_outlined),
        _scoreDivider(),
        _scoreCell('공부시작', _fmt12h(_studyStart), g.studyStartScore, 25,
          BotanicalColors.subjectData, Icons.menu_book_outlined),
        _scoreDivider(),
        _scoreCell('순공', '${_effMin ~/ 60}h${_effMin % 60}m', g.studyTimeScore, 50,
          BotanicalColors.primary, Icons.schedule_outlined),
      ]),
    );
  }

  Widget _scoreCell(String label, String value, double score, double max,
      Color color, IconData icon) {
    final pct = (score / max).clamp(0.0, 1.0);
    return Expanded(child: Column(children: [
      Icon(icon, size: 16, color: color.withOpacity(0.7)),
      const SizedBox(height: 6),
      Text(value, style: BotanicalTypo.label(
        size: 13, weight: FontWeight.w700, color: _textMain)),
      const SizedBox(height: 2),
      Text(label, style: BotanicalTypo.label(size: 10, color: _textMuted)),
      const SizedBox(height: 8),
      SizedBox(width: 34, height: 34,
        child: Stack(alignment: Alignment.center, children: [
          CircularProgressIndicator(
            value: pct, strokeWidth: 2.5,
            backgroundColor: _dk ? Colors.white.withOpacity(0.06) : color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation(color)),
          Text(score.toStringAsFixed(0), style: BotanicalTypo.label(
            size: 10, weight: FontWeight.w800, color: color)),
        ])),
    ]));
  }

  Widget _scoreDivider() => Container(
    width: 1, height: 65, color: _border.withOpacity(0.4));

  // ══════════════════════════════════════════
  //  포커스 활성 배너
  // ══════════════════════════════════════════

  Widget _activeFocusBanner() {
    final st = _ft.getCurrentState();
    final mc = BotanicalColors.subjectColor(st.subject);
    return GestureDetector(
      onTap: () => setState(() => _tab = 1), // 포커스 탭으로 이동
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [mc.withOpacity(_dk ? 0.15 : 0.06), mc.withOpacity(_dk ? 0.05 : 0.02)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: mc.withOpacity(0.2))),
        child: Row(children: [
          Container(width: 10, height: 10,
            decoration: BoxDecoration(color: mc, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: mc.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)])),
          const SizedBox(width: 12),
          Text('${st.mode == 'study' ? '📖' : st.mode == 'lecture' ? '🎧' : '☕'} ${st.subject}',
            style: BotanicalTypo.label(size: 13, weight: FontWeight.w600, color: _textMain)),
          const Spacer(),
          Text(st.mainTimerFormatted, style: BotanicalTypo.number(
            size: 20, weight: FontWeight.w600, color: mc)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: mc.withOpacity(_dk ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(8)),
            child: Text('순공 ${st.effectiveTimeFormatted}',
              style: BotanicalTypo.label(size: 10, weight: FontWeight.w700, color: mc))),
          const SizedBox(width: 6),
          Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _textMuted),
        ]),
      ),
    );
  }

}