package com.cheonhong.cheonhong_studio

import android.app.*
import android.content.*
import android.media.*
import android.os.*
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*
import org.json.JSONObject

/**
 * CHEONHONG STUDIO — 기상 알람 Foreground Service
 *
 * Samsung A15 공격적 배터리 최적화 우회:
 * - AlarmReceiver → 즉시 startForegroundService → Samsung이 프로세스 킬 불가
 * - Wake Lock + 화면 켜짐 + 볼륨 MAX
 * - 알람벨 3초 → 배경음 페이드인 → TTS 브리핑 → 30초 간격 반복
 * - NFC 스캔으로만 종료
 */
class AlarmForegroundService : Service(), TextToSpeech.OnInitListener {

    companion object {
        const val TAG = "AlarmFgService"
        const val CHANNEL_ID = "cheonhong_alarm_fg"
        const val CHANNEL_NAME = "기상 알람 서비스"
        const val NOTIF_ID = 2001
        const val ACTION_STOP = "com.cheonhong.cheonhong_studio.STOP_ALARM"
        const val ACTION_MUTE_SOUND = "com.cheonhong.cheonhong_studio.MUTE_SOUND"

        // 외부에서 서비스 중지 (NFC 스캔 시)
        fun stop(context: Context) {
            context.stopService(Intent(context, AlarmForegroundService::class.java))
            // Broadcast로도 전달 (서비스가 다른 프로세스일 수 있음)
            context.sendBroadcast(Intent(ACTION_STOP).setPackage(context.packageName))
        }
    }

    // ─── 상태 ───
    private var wakeLock: PowerManager.WakeLock? = null
    private var alarmPlayer: MediaPlayer? = null
    private var bgmPlayer: MediaPlayer? = null
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var vibrator: Vibrator? = null
    private var loopHandler: Handler? = null
    private var loopRunnable: Runnable? = null
    private var isMuted = false
    private var briefingText = ""
    private var ttsAttempted = false
    private var openAiKey: String? = null
    private var bgmType = "piano" // piano, nature, rain, none

    // 볼륨 백업
    private var prevAlarmVol = -1
    private var prevMusicVol = -1
    private var prevRingVol = -1
    private var prevRingerMode = -1

    private val stopReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ACTION_STOP) {
                Log.d(TAG, "🛑 NFC 스캔으로 알람 종료 브로드캐스트 수신")
                cleanup()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
    }

    private val muteReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ACTION_MUTE_SOUND) {
                Log.d(TAG, "🔇 소리 끄기 (진동 유지)")
                muteSoundOnly()
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(stopReceiver, IntentFilter(ACTION_STOP), RECEIVER_NOT_EXPORTED)
            registerReceiver(muteReceiver, IntentFilter(ACTION_MUTE_SOUND), RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(stopReceiver, IntentFilter(ACTION_STOP))
            registerReceiver(muteReceiver, IntentFilter(ACTION_MUTE_SOUND))
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "🔔 AlarmForegroundService 시작")

        // 즉시 Foreground 전환 (5초 이내 필수)
        startForeground(NOTIF_ID, buildNotification("⏰ 기상 시간!", "NFC 태그를 스캔하여 기상하세요"))

        // OpenAI API 키 로드
        val prefs = getSharedPreferences("alarm_prefs", MODE_PRIVATE)
        openAiKey = prefs.getString("openai_api_key", null)
        bgmType = prefs.getString("bgm_type", "piano") ?: "piano"

        // Wake Lock 획득 (화면 켜짐)
        acquireWakeLock()

        // 볼륨 MAX
        setVolumeMax()

        // 진동 시작
        startVibration()

        // 브리핑 텍스트 생성
        briefingText = buildBriefingText()

        // TTS 초기화
        tts = TextToSpeech(this, this)

        // 알람 시퀀스 시작: 벨 3초 → BGM → TTS
        startAlarmSequence()

        return START_STICKY // 시스템이 죽여도 재시작
    }

    // ══════════════════════════════════════════
    //  알람 시퀀스
    // ══════════════════════════════════════════

    private fun startAlarmSequence() {
        // 1단계: 알람벨 3초
        playAlarmBell {
            // 2단계: 배경음 페이드인
            startBgm()
            // 3단계: TTS 브리핑 (TTS 준비 후)
            Handler(Looper.getMainLooper()).postDelayed({
                speakBriefing()
                // 4단계: 30초 간격 반복 루프
                startLoop()
            }, 1500) // BGM 시작 후 1.5초 대기
        }
    }

    private fun playAlarmBell(onComplete: () -> Unit) {
        try {
            alarmPlayer = MediaPlayer().apply {
                val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                setDataSource(this@AlarmForegroundService, uri)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                prepare()
                start()
            }
            // 3초 후 알람벨 중지 + 다음 단계
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    alarmPlayer?.stop()
                    alarmPlayer?.release()
                    alarmPlayer = null
                } catch (_: Exception) {}
                onComplete()
            }, 3000)
        } catch (e: Exception) {
            Log.e(TAG, "알람벨 재생 실패: $e")
            onComplete()
        }
    }

    private fun startBgm() {
        if (isMuted) return
        if (bgmType == "none") {
            Log.d(TAG, "BGM 타입: none → 배경음 스킵")
            return
        }
        try {
            val rawId = when (bgmType) {
                "nature" -> R.raw.bgm_nature
                "rain" -> R.raw.bgm_rain
                else -> R.raw.bgm_piano  // 기본값: 피아노
            }
            Log.d(TAG, "🎵 BGM 시작: $bgmType")
            bgmPlayer = MediaPlayer.create(this, rawId)?.apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                isLooping = true
                setVolume(0.0f, 0.0f)
                start()
            }
            fadeInBgm()
        } catch (e: Exception) {
            Log.e(TAG, "BGM 시작 실패: $e")
        }
    }

    private fun fadeInBgm() {
        val handler = Handler(Looper.getMainLooper())
        val targetVol = 0.3f
        val steps = 20
        val stepDelay = 100L // 20 * 100ms = 2초
        var currentStep = 0

        val fadeRunnable = object : Runnable {
            override fun run() {
                if (currentStep >= steps || bgmPlayer == null) return
                currentStep++
                val vol = targetVol * (currentStep.toFloat() / steps)
                try {
                    bgmPlayer?.setVolume(vol, vol)
                } catch (_: Exception) {}
                handler.postDelayed(this, stepDelay)
            }
        }
        handler.post(fadeRunnable)
    }

    // ═══ TTS 브리핑 ═══

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            tts?.language = Locale.KOREAN
            tts?.setSpeechRate(0.9f)
            tts?.setPitch(1.05f)
            ttsReady = true
            Log.d(TAG, "✅ TTS 엔진 준비 완료")

            // TTS 엔진 중 Google 우선 사용
            try {
                val engines = tts?.engines
                val googleEngine = engines?.firstOrNull {
                    it.name.contains("google", ignoreCase = true)
                }
                if (googleEngine != null) {
                    tts?.setEngineByPackageName(googleEngine.name)
                    Log.d(TAG, "✅ Google TTS 엔진 설정")
                }
            } catch (_: Exception) {}
        } else {
            Log.e(TAG, "❌ TTS 초기화 실패: $status")
        }
    }

    private fun speakBriefing() {
        if (isMuted) return
        if (!ttsReady || briefingText.isEmpty()) {
            Log.w(TAG, "TTS 미준비 또는 텍스트 없음")
            return
        }

        // BGM 볼륨 일시 감소 (ducking)
        try { bgmPlayer?.setVolume(0.1f, 0.1f) } catch (_: Exception) {}

        // OpenAI TTS 먼저 시도 (별도 스레드)
        if (!ttsAttempted && openAiKey != null) {
            ttsAttempted = true
            Thread {
                val audioFile = callOpenAiTts(briefingText)
                if (audioFile != null) {
                    playTtsAudio(audioFile)
                } else {
                    // OpenAI 실패 → 로컬 TTS 폴백
                    Handler(Looper.getMainLooper()).post { speakWithLocalTts() }
                }
            }.start()
        } else {
            speakWithLocalTts()
        }
    }

    private fun speakWithLocalTts() {
        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {}
            override fun onDone(utteranceId: String?) {
                // TTS 완료 후 BGM 볼륨 복원
                try { bgmPlayer?.setVolume(0.3f, 0.3f) } catch (_: Exception) {}
            }
            override fun onError(utteranceId: String?) {
                try { bgmPlayer?.setVolume(0.3f, 0.3f) } catch (_: Exception) {}
            }
        })

        val params = Bundle().apply {
            putInt(TextToSpeech.Engine.KEY_PARAM_STREAM, AudioManager.STREAM_ALARM)
        }
        tts?.speak(briefingText, TextToSpeech.QUEUE_FLUSH, params, "alarm_briefing")
    }

    private fun callOpenAiTts(text: String): File? {
        try {
            val key = openAiKey ?: return null
            val url = URL("https://api.openai.com/v1/audio/speech")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.setRequestProperty("Authorization", "Bearer $key")
            conn.setRequestProperty("Content-Type", "application/json")
            conn.connectTimeout = 10000
            conn.readTimeout = 15000
            conn.doOutput = true

            val body = JSONObject().apply {
                put("model", "tts-1")
                put("input", text)
                put("voice", "nova") // 자연스러운 여성 음성
                put("speed", 0.95)
            }

            conn.outputStream.use { it.write(body.toString().toByteArray()) }

            if (conn.responseCode == 200) {
                val file = File(cacheDir, "alarm_tts.mp3")
                conn.inputStream.use { input ->
                    file.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
                return file
            }
            Log.w(TAG, "OpenAI TTS HTTP ${conn.responseCode}")
        } catch (e: Exception) {
            Log.e(TAG, "OpenAI TTS 실패: $e")
        }
        return null
    }

    private fun playTtsAudio(file: File) {
        try {
            val player = MediaPlayer().apply {
                setDataSource(file.absolutePath)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                prepare()
                setOnCompletionListener {
                    it.release()
                    try { bgmPlayer?.setVolume(0.3f, 0.3f) } catch (_: Exception) {}
                }
                start()
            }
        } catch (e: Exception) {
            Log.e(TAG, "TTS 오디오 재생 실패: $e")
            Handler(Looper.getMainLooper()).post { speakWithLocalTts() }
        }
    }

    // ═══ 3분 반복 루프 ═══

    private fun startLoop() {
        loopHandler = Handler(Looper.getMainLooper())
        loopRunnable = object : Runnable {
            override fun run() {
                ttsAttempted = true // 2회차부터는 로컬 TTS만 사용 (비용 절약)
                // 3분 간격으로 진동 다시 시작 + TTS 반복
                startVibrationBurst()
                speakBriefing()
                updateNotification("⏰ NFC를 스캔하세요!", "3분 후 다시 알림됩니다")
                loopHandler?.postDelayed(this, 180_000) // ★ 3분 간격
            }
        }
        loopHandler?.postDelayed(loopRunnable!!, 180_000) // ★ 3분 후 첫 반복
    }

    // ══════════════════════════════════════════
    //  브리핑 텍스트 생성
    // ══════════════════════════════════════════

    private fun buildBriefingText(): String {
        val prefs = getSharedPreferences("alarm_prefs", MODE_PRIVATE)
        val briefPrefs = getSharedPreferences("briefing_cache", MODE_PRIVATE)

        val now = Calendar.getInstance()
        val hour = now.get(Calendar.HOUR_OF_DAY)
        val minute = now.get(Calendar.MINUTE)
        val timeStr = String.format("%d시 %02d분", hour, minute)

        // D-day
        val examDate = briefPrefs.getString("exam_date", null)
        val dDayStr = if (examDate != null) {
            try {
                val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.KOREA)
                val exam = sdf.parse(examDate)
                val diff = ((exam!!.time - System.currentTimeMillis()) / 86400000).toInt()
                if (diff > 0) "시험까지 D-${diff}." else if (diff == 0) "시험 당일입니다!" else ""
            } catch (_: Exception) { "" }
        } else ""

        // 어제 성적
        val yesterdayGrade = briefPrefs.getString("yesterday_grade", null)
        val yesterdayStudy = briefPrefs.getString("yesterday_study_time", null)
        val gradeStr = if (yesterdayGrade != null && yesterdayStudy != null) {
            "어제 등급 ${yesterdayGrade}, 순공 ${yesterdayStudy}."
        } else ""

        // 날씨
        val weatherDesc = briefPrefs.getString("weather_desc", null)
        val weatherTemp = briefPrefs.getString("weather_temp", null)
        val weatherCity = briefPrefs.getString("weather_city", "서울")
        val weatherStr = if (weatherDesc != null && weatherTemp != null) {
            "오늘 ${weatherCity} ${weatherDesc}, ${weatherTemp}도."
        } else ""

        val greeting = if (hour < 12) "좋은 아침입니다." else "일어날 시간입니다."

        return buildString {
            append("$greeting ")
            append("현재 ${timeStr}. ")
            if (dDayStr.isNotEmpty()) append("$dDayStr ")
            if (gradeStr.isNotEmpty()) append("$gradeStr ")
            if (weatherStr.isNotEmpty()) append("$weatherStr ")
            append("일어나서 욕실 NFC를 찍어주세요.")
        }.trim()
    }

    // ══════════════════════════════════════════
    //  볼륨 / 진동 / Wake Lock
    // ══════════════════════════════════════════

    private fun setVolumeMax() {
        try {
            val am = getSystemService(AUDIO_SERVICE) as AudioManager
            // 백업
            prevAlarmVol = am.getStreamVolume(AudioManager.STREAM_ALARM)
            prevMusicVol = am.getStreamVolume(AudioManager.STREAM_MUSIC)
            prevRingVol = am.getStreamVolume(AudioManager.STREAM_RING)
            prevRingerMode = am.ringerMode
            // MAX
            am.ringerMode = AudioManager.RINGER_MODE_NORMAL
            am.setStreamVolume(AudioManager.STREAM_ALARM, am.getStreamMaxVolume(AudioManager.STREAM_ALARM), 0)
            am.setStreamVolume(AudioManager.STREAM_MUSIC, am.getStreamMaxVolume(AudioManager.STREAM_MUSIC), 0)
            am.setStreamVolume(AudioManager.STREAM_RING, am.getStreamMaxVolume(AudioManager.STREAM_RING), 0)
            Log.d(TAG, "🔊 볼륨 MAX")
        } catch (e: Exception) {
            Log.e(TAG, "볼륨 설정 실패: $e")
        }
    }

    private fun restoreVolume() {
        try {
            val am = getSystemService(AUDIO_SERVICE) as AudioManager
            if (prevAlarmVol >= 0) am.setStreamVolume(AudioManager.STREAM_ALARM, prevAlarmVol, 0)
            if (prevMusicVol >= 0) am.setStreamVolume(AudioManager.STREAM_MUSIC, prevMusicVol, 0)
            if (prevRingVol >= 0) am.setStreamVolume(AudioManager.STREAM_RING, prevRingVol, 0)
            if (prevRingerMode >= 0) am.ringerMode = prevRingerMode
            Log.d(TAG, "🔊 볼륨 복원")
        } catch (_: Exception) {}
    }

    private fun startVibration() {
        try {
            vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vm.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(VIBRATOR_SERVICE) as Vibrator
            }
            // ★ 초기 알람: 강한 진동 패턴 (반복)
            val pattern = longArrayOf(0, 1000, 500, 1000, 500, 1500, 800)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }
            // ★ 15초 후 진동 중지 (3분 간격 루프에서 burst로 재실행)
            Handler(Looper.getMainLooper()).postDelayed({
                try { vibrator?.cancel() } catch (_: Exception) {}
                Log.d(TAG, "📳 초기 진동 종료 → 3분 간격 burst 모드")
            }, 15_000)
        } catch (e: Exception) {
            Log.e(TAG, "진동 시작 실패: $e")
        }
    }

    /** 3분 간격 진동 burst: 10초간 진동 후 자동 중지 */
    private fun startVibrationBurst() {
        try {
            val pattern = longArrayOf(0, 800, 400, 800, 400, 1200, 600, 1200)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, -1)) // -1 = 반복 안 함
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, -1)
            }
            Log.d(TAG, "📳 3분 주기 진동 burst")
        } catch (e: Exception) {
            Log.e(TAG, "진동 burst 실패: $e")
        }
    }

    private fun acquireWakeLock() {
        try {
            val pm = getSystemService(POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "cheonhong:alarm_wake"
            ).apply {
                acquire(10 * 60 * 1000L) // 최대 10분
            }
            Log.d(TAG, "🔒 Wake Lock 획득")
        } catch (e: Exception) {
            Log.e(TAG, "Wake Lock 실패: $e")
        }
    }

    // ═══ 소리만 끄기 (진동 유지) ═══

    private fun muteSoundOnly() {
        isMuted = true
        try {
            tts?.stop()
            alarmPlayer?.stop()
            alarmPlayer?.release()
            alarmPlayer = null
            bgmPlayer?.stop()
            bgmPlayer?.release()
            bgmPlayer = null
        } catch (_: Exception) {}
        updateNotification("📳 NFC를 스캔하세요!", "진동은 NFC로만 해제됩니다")
    }

    // ══════════════════════════════════════════
    //  알림 + 채널
    // ══════════════════════════════════════════

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "기상 알람 Foreground Service"
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setShowBadge(true)
            }
            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(title: String, text: String): Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingOpen = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 소리 끄기 액션
        val muteIntent = Intent(ACTION_MUTE_SOUND).setPackage(packageName)
        val pendingMute = PendingIntent.getBroadcast(
            this, 1, muteIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(text)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setFullScreenIntent(pendingOpen, true)
            .setContentIntent(pendingOpen)
            .addAction(android.R.drawable.ic_media_pause, "🔇 소리 끄기", pendingMute)
            .build()
    }

    private fun updateNotification(title: String, text: String) {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_ID, buildNotification(title, text))
    }

    // ══════════════════════════════════════════
    //  정리
    // ══════════════════════════════════════════

    private fun cleanup() {
        Log.d(TAG, "🧹 알람 서비스 정리")

        // 루프 중지
        loopRunnable?.let { loopHandler?.removeCallbacks(it) }
        loopHandler = null
        loopRunnable = null

        // 미디어 중지
        try { tts?.stop(); tts?.shutdown() } catch (_: Exception) {}
        try { alarmPlayer?.stop(); alarmPlayer?.release() } catch (_: Exception) {}
        try { bgmPlayer?.stop(); bgmPlayer?.release() } catch (_: Exception) {}
        alarmPlayer = null
        bgmPlayer = null
        tts = null

        // 진동 중지
        try { vibrator?.cancel() } catch (_: Exception) {}
        vibrator = null

        // 볼륨 복원
        restoreVolume()

        // Wake Lock 해제
        try { wakeLock?.release() } catch (_: Exception) {}
        wakeLock = null

        // 기상 시간 기록
        recordWakeTime()

        // 알림 제거
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(NOTIF_ID)
        nm.cancel(MainActivity.ALARM_REQUEST_CODE)
    }

    private fun recordWakeTime() {
        try {
            val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.KOREA)
            val timeFmt = SimpleDateFormat("HH:mm", Locale.KOREA)
            val now = Date()
            val dateStr = sdf.format(now)
            val timeStr = timeFmt.format(now)

            getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE).edit().apply {
                putString("flutter.wake_$dateStr", timeStr)
                putString("flutter.pending_wake_sync", dateStr)
                apply()
            }
            Log.d(TAG, "✅ 기상 기록: $dateStr $timeStr")
        } catch (e: Exception) {
            Log.e(TAG, "기상 기록 실패: $e")
        }
    }

    override fun onDestroy() {
        cleanup()
        try { unregisterReceiver(stopReceiver) } catch (_: Exception) {}
        try { unregisterReceiver(muteReceiver) } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun onBind(intent: Intent?) = null
}