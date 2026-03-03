package com.cheonhong.cheonhong_studio

import android.app.AlarmManager
import android.app.AppOpsManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import android.Manifest
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar
import android.nfc.NfcAdapter
import android.util.Log
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.os.Bundle
import android.os.Parcelable

class MainActivity : FlutterActivity() {

    private val FOCUS_CHANNEL = "com.cheonhong.cheonhong_studio/focus_mode"
    private val USAGE_CHANNEL = "com.cheonhong.cheonhong_studio/usage_stats"
    private val WIFI_CHANNEL = "com.cheonhong.cheonhong_studio/wifi"
    private val ALARM_CHANNEL = "com.cheonhong.cheonhong_studio/alarm"
    private val VOLUME_CHANNEL = "com.cheonhong.cheonhong_studio/volume"
    private val NFC_CHANNEL = "com.cheonhong.cheonhong_studio/nfc"
    private val BROWSER_CHANNEL = "com.cheonhong.cheonhong_studio/browser"
    private var nfcChannel: MethodChannel? = null
    private var flutterReadyForNfc: Boolean = false
    private var pendingNfcPayload: HashMap<String, Any>? = null
    private var silentReaderEnabled: Boolean = false
    private var _activeVibrator: android.os.Vibrator? = null
    private var _bgmPlayer: MediaPlayer? = null
    private var _bgmFocusRequest: android.media.AudioFocusRequest? = null


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

// ─── NFC 채널 (NDEF → Flutter 전달) ───
nfcChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NFC_CHANNEL).apply {
    setMethodCallHandler { call, result ->
        when (call.method) {
            "flutterReady" -> {
                flutterReadyForNfc = true
                // 초기 런치 또는 엔진 준비 전 수신된 NFC 인텐트 flush
                pendingNfcPayload?.let { payload ->
                    invokeMethod("onNfcTagFromIntent", payload)
                    pendingNfcPayload = null
                }
                result.success(true)
            }
            "getPendingNfcIntent" -> {
                // ★ NFC 첫 태그 보완: pending payload 명시적 반환
                val payload = pendingNfcPayload
                if (payload != null) {
                    pendingNfcPayload = null
                    result.success(payload)
                } else {
                    result.success(null)
                }
            }
            "enableSilentReader" -> {
                enableSilentReaderMode()
                result.success(true)
            }
            "disableSilentReader" -> {
                disableSilentReaderMode()
                result.success(true)
            }
            "showNotification" -> {
                val title = call.argument<String>("title") ?: "NFC 처리"
                val body = call.argument<String>("body") ?: ""
                showNfcNotification(title, body)
                result.success(true)
            }
            "requestNotificationPermission" -> {
                requestPostNotificationsPermission()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }
}

// Cold start: 앱이 NFC 인텐트로 실행된 경우를 위해 초기 intent도 처리 (엔진 준비 전이면 큐에 저장)
handleNfcIntent(intent)?.let { payload ->
    sendNfcToFlutter(payload)
}

        // ─── Browser 채널 (URL 열기) ───
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BROWSER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_URL_FAILED", e.message, null)
                        }
                    } else {
                        result.error("NO_URL", "URL is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ─── Kotlin 알람 채널 (Bug #3 Fix) ───
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAlarm" -> {
                    val hour = call.argument<Int>("hour") ?: 7
                    val minute = call.argument<Int>("minute") ?: 0
                    val activeDays = call.argument<List<Int>>("activeDays") ?: listOf(1,2,3,4,5,6)
                    val label = call.argument<String>("label") ?: "⏰ 기상 시간!"
                    scheduleNativeAlarm(hour, minute, activeDays, label)
                    result.success(true)
                }
                "cancelAlarm" -> {
                    cancelNativeAlarm()
                    result.success(true)
                }
                "requestBatteryOptExemption" -> {
                    requestBatteryOptimizationExemption()
                    result.success(true)
                }
                "isBatteryOptExempt" -> {
                    result.success(isBatteryOptimized())
                }
                "openBatterySettings" -> {
                    // Samsung 배터리 최적화 설정 직접 열기
                    try {
                        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        startActivity(intent)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        } catch (_: Exception) {}
                    }
                    result.success(true)
                }
                "canScheduleExactAlarms" -> {
                    result.success(canScheduleExactAlarms())
                }
                "requestExactAlarmPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                    }
                    result.success(true)
                }
                // ═══ F2: 볼륨 MAX 설정 ═══
                "setVolumeMax" -> {
                    try {
                        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        // 현재 볼륨 저장 (복원용)
                        getSharedPreferences("alarm_prefs", MODE_PRIVATE).edit().apply {
                            putInt("prev_alarm_vol", am.getStreamVolume(AudioManager.STREAM_ALARM))
                            putInt("prev_ring_vol", am.getStreamVolume(AudioManager.STREAM_RING))
                            putInt("prev_music_vol", am.getStreamVolume(AudioManager.STREAM_MUSIC))
                            putInt("prev_notif_vol", am.getStreamVolume(AudioManager.STREAM_NOTIFICATION))
                            apply()
                        }
                        // 모든 스트림 MAX
                        am.setStreamVolume(AudioManager.STREAM_ALARM, am.getStreamMaxVolume(AudioManager.STREAM_ALARM), 0)
                        am.setStreamVolume(AudioManager.STREAM_RING, am.getStreamMaxVolume(AudioManager.STREAM_RING), 0)
                        am.setStreamVolume(AudioManager.STREAM_MUSIC, am.getStreamMaxVolume(AudioManager.STREAM_MUSIC), 0)
                        am.setStreamVolume(AudioManager.STREAM_NOTIFICATION, am.getStreamMaxVolume(AudioManager.STREAM_NOTIFICATION), 0)
                        // 벨소리 모드 강제
                        am.ringerMode = AudioManager.RINGER_MODE_NORMAL
                    } catch (_: Exception) {}
                    result.success(true)
                }
                // ═══ F2: 볼륨 복원 ═══
                "restoreVolume" -> {
                    try {
                        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        val prefs = getSharedPreferences("alarm_prefs", MODE_PRIVATE)
                        val prevAlarm = prefs.getInt("prev_alarm_vol", -1)
                        val prevRing = prefs.getInt("prev_ring_vol", -1)
                        val prevMusic = prefs.getInt("prev_music_vol", -1)
                        val prevNotif = prefs.getInt("prev_notif_vol", -1)
                        if (prevAlarm >= 0) am.setStreamVolume(AudioManager.STREAM_ALARM, prevAlarm, 0)
                        if (prevRing >= 0) am.setStreamVolume(AudioManager.STREAM_RING, prevRing, 0)
                        if (prevMusic >= 0) am.setStreamVolume(AudioManager.STREAM_MUSIC, prevMusic, 0)
                        if (prevNotif >= 0) am.setStreamVolume(AudioManager.STREAM_NOTIFICATION, prevNotif, 0)
                    } catch (_: Exception) {}
                    result.success(true)
                }
                // ═══ F3: 반복 진동 시작 ═══
                "startVibration" -> {
                    try {
                        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as android.os.VibratorManager
                            vm.defaultVibrator
                        } else {
                            @Suppress("DEPRECATION")
                            getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
                        }
                        // 반복 진동 패턴: 대기-진동-대기-진동... (-1이 아닌 0=무한반복)
                        val pattern = longArrayOf(0, 1000, 500, 1000, 500, 1500, 800)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            vibrator.vibrate(android.os.VibrationEffect.createWaveform(pattern, 0))
                        } else {
                            @Suppress("DEPRECATION")
                            vibrator.vibrate(pattern, 0)
                        }
                        // 진동 객체 저장
                        _activeVibrator = vibrator
                    } catch (_: Exception) {}
                    result.success(true)
                }
                // ═══ F3: 진동 중지 (NFC 해제용) ═══
                "stopVibration" -> {
                    try {
                        _activeVibrator?.cancel()
                        _activeVibrator = null
                    } catch (_: Exception) {}
                    result.success(true)
                }
                // ═══ F3: 소리만 끄기 ═══
                "muteAlarmSound" -> {
                    try {
                        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        am.setStreamVolume(AudioManager.STREAM_ALARM, 0, 0)
                        am.setStreamVolume(AudioManager.STREAM_NOTIFICATION, 0, 0)
                    } catch (_: Exception) {}
                    result.success(true)
                }
                // ═══ 1순위: NFC로 알람 ForegroundService 종료 ═══
                "stopAlarmService" -> {
                    AlarmForegroundService.stop(this@MainActivity)
                    // 기존 알림도 정리
                    try {
                        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        nm.cancel(AlarmForegroundService.NOTIF_ID)
                        nm.cancel(ALARM_REQUEST_CODE)
                        _activeVibrator?.cancel()
                        _activeVibrator = null
                    } catch (_: Exception) {}
                    result.success(true)
                }
                // ═══ 1순위: 브리핑 데이터 캐시 (Flutter → SharedPreferences) ═══
                "cacheBriefingData" -> {
                    try {
                        val prefs = getSharedPreferences("briefing_cache", MODE_PRIVATE).edit()
                        call.argument<String>("exam_date")?.let { prefs.putString("exam_date", it) }
                        call.argument<String>("yesterday_grade")?.let { prefs.putString("yesterday_grade", it) }
                        call.argument<String>("yesterday_study_time")?.let { prefs.putString("yesterday_study_time", it) }
                        call.argument<String>("weather_desc")?.let { prefs.putString("weather_desc", it) }
                        call.argument<String>("weather_temp")?.let { prefs.putString("weather_temp", it) }
                        call.argument<String>("weather_city")?.let { prefs.putString("weather_city", it) }
                        prefs.apply()
                    } catch (_: Exception) {}
                    result.success(true)
                }
                // ═══ 1순위: OpenAI API 키 캐시 ═══
                "cacheOpenAiKey" -> {
                    try {
                        val key = call.argument<String>("key") ?: ""
                        getSharedPreferences("alarm_prefs", MODE_PRIVATE).edit()
                            .putString("openai_api_key", key).apply()
                    } catch (_: Exception) {}
                    result.success(true)
                }
                // ═══ BGM 타입 캐시 ═══
                "cacheBgmType" -> {
                    try {
                        val type = call.argument<String>("type") ?: "piano"
                        getSharedPreferences("alarm_prefs", MODE_PRIVATE).edit()
                            .putString("bgm_type", type).apply()
                    } catch (_: Exception) {}
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // ─── 앱 사용 통계 채널 ───
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USAGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "requestPermission" -> {
                    if (!hasUsageStatsPermission()) {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    }
                    result.success(true)
                }
                "getTodayUsage" -> {
                    if (!hasUsageStatsPermission()) {
                        result.success(emptyList<Map<String, Any>>())
                        return@setMethodCallHandler
                    }
                    result.success(getTodayUsageStats())
                }
                else -> result.notImplemented()
            }
        }

        // ─── WiFi SSID 채널 ───
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIFI_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getWifiSsid" -> {
                    result.success(getCurrentWifiSsid())
                }
                else -> result.notImplemented()
            }
        }

        // ─── 집중모드 채널 ───
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOCUS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableDnd" -> {
                    enableDndMode()
                    result.success(true)
                }
                "disableDnd" -> {
                    disableDndMode()
                    result.success(true)
                }
                "getForegroundApp" -> {
                    result.success(getForegroundPackage())
                }
                "showBlockOverlay" -> {
                    // TODO: SYSTEM_ALERT_WINDOW 오버레이
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // ─── 볼륨 제어 채널 (TTS 무음모드 우회) ───
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_CHANNEL).setMethodCallHandler { call, result ->
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            when (call.method) {
                "getVolume" -> {
                    result.success(am.getStreamVolume(AudioManager.STREAM_MUSIC))
                }
                "getMaxVolume" -> {
                    result.success(am.getStreamMaxVolume(AudioManager.STREAM_MUSIC))
                }
                "setVolume" -> {
                    val vol = call.argument<Int>("volume") ?: 10
                    am.setStreamVolume(AudioManager.STREAM_MUSIC, vol, 0)
                    result.success(true)
                }
                "getRingerMode" -> {
                    result.success(am.ringerMode)
                }
                "setRingerMode" -> {
                    val mode = call.argument<Int>("mode") ?: AudioManager.RINGER_MODE_NORMAL
                    try {
                        am.ringerMode = mode
                        result.success(true)
                    } catch (e: SecurityException) {
                        // DND 권한 없으면 실패 가능
                        result.success(false)
                    }
                }
                // ═══ #5b: 브리핑 배경음 시작 ═══
                "startBriefingBgm" -> {
                    val bgm = call.argument<String>("bgm") ?: "none"
                    if (bgm == "none") {
                        result.success(true)
                        return@setMethodCallHandler
                    }
                    try {
                        _bgmPlayer?.release()
                        _bgmPlayer = null
                        val filename = "bgm/$bgm.ogg"
                        val afd = assets.openFd(filename)
                        _bgmPlayer = MediaPlayer().apply {
                            setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                            afd.close()
                            // AudioAttributes: USAGE_MEDIA → TTS(USAGE_ASSISTANT)와 독립 스트림
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                setAudioAttributes(android.media.AudioAttributes.Builder()
                                    .setUsage(android.media.AudioAttributes.USAGE_MEDIA)
                                    .setContentType(android.media.AudioAttributes.CONTENT_TYPE_MUSIC)
                                    .build())
                            }
                            isLooping = true
                            setVolume(0.12f, 0.12f)
                            prepare()
                            start()
                        }
                        // AudioFocus duck 리스너: TTS 재생 시 볼륨 낮추고, 끝나면 복원
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                            _bgmFocusRequest = android.media.AudioFocusRequest.Builder(
                                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
                            ).setOnAudioFocusChangeListener { change ->
                                when (change) {
                                    AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK,
                                    AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                                        _bgmPlayer?.setVolume(0.03f, 0.03f)
                                    }
                                    AudioManager.AUDIOFOCUS_GAIN -> {
                                        _bgmPlayer?.setVolume(0.12f, 0.12f)
                                    }
                                    AudioManager.AUDIOFOCUS_LOSS -> {
                                        // 완전 손실 시에도 계속 재생 (낮은 볼륨)
                                        _bgmPlayer?.setVolume(0.03f, 0.03f)
                                    }
                                }
                            }.setAudioAttributes(android.media.AudioAttributes.Builder()
                                .setUsage(android.media.AudioAttributes.USAGE_MEDIA)
                                .setContentType(android.media.AudioAttributes.CONTENT_TYPE_MUSIC)
                                .build())
                            .build()
                            am.requestAudioFocus(_bgmFocusRequest!!)
                        }
                        Log.d("Volume", "BGM started: $bgm")
                    } catch (e: Exception) {
                        Log.e("Volume", "BGM start failed: $e")
                    }
                    result.success(true)
                }
                // ═══ #5b: 브리핑 배경음 정지 ═══
                "stopBriefingBgm" -> {
                    try {
                        _bgmPlayer?.apply {
                            if (isPlaying) stop()
                            release()
                        }
                        _bgmPlayer = null
                        // AudioFocus 해제
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && _bgmFocusRequest != null) {
                            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                            am.abandonAudioFocusRequest(_bgmFocusRequest!!)
                            _bgmFocusRequest = null
                        }
                        Log.d("Volume", "BGM stopped")
                    } catch (e: Exception) {
                        Log.e("Volume", "BGM stop failed: $e")
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }


        // 알람 알림 채널 생성
        createAlarmNotificationChannel()
        createNfcNotificationChannel()
    }

// ══════════════════════════════════════════
//  NFC: NDEF 인텐트 처리 → Flutter 전달
// ══════════════════════════════════════════

override fun onDestroy() {
    try {
        _bgmPlayer?.release()
        _bgmPlayer = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && _bgmFocusRequest != null) {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            am.abandonAudioFocusRequest(_bgmFocusRequest!!)
            _bgmFocusRequest = null
        }
    } catch (_: Exception) {}
    super.onDestroy()
}

override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent) // FlutterActivity가 들고 있는 intent 갱신
    handleNfcIntent(intent)?.let { payload ->
        sendNfcToFlutter(payload)
    }
}

// ★ NFC 첫 태그 보완: foreground dispatch로 앱이 포그라운드에서 NFC 우선 수신
override fun onResume() {
    super.onResume()
    enableNfcForegroundDispatch()
}

override fun onPause() {
    super.onPause()
    disableNfcForegroundDispatch()
}

private fun enableNfcForegroundDispatch() {
    try {
        val adapter = NfcAdapter.getDefaultAdapter(this) ?: return
        val intent = Intent(this, javaClass).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pendingIntent = PendingIntent.getActivity(this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE)

        // NDEF_DISCOVERED 우선, TECH_DISCOVERED 폴백
        val ndefFilter = android.content.IntentFilter(NfcAdapter.ACTION_NDEF_DISCOVERED).apply {
            try { addDataScheme("cheonhong") } catch (_: Exception) {}
        }
        val techFilter = android.content.IntentFilter(NfcAdapter.ACTION_TECH_DISCOVERED)
        val tagFilter = android.content.IntentFilter(NfcAdapter.ACTION_TAG_DISCOVERED)

        adapter.enableForegroundDispatch(
            this, pendingIntent,
            arrayOf(ndefFilter, techFilter, tagFilter),
            arrayOf(
                arrayOf(android.nfc.tech.Ndef::class.java.name),
                arrayOf(android.nfc.tech.NdefFormatable::class.java.name),
                arrayOf(android.nfc.tech.NfcA::class.java.name)
            )
        )
        Log.d("NFC", "✅ Foreground dispatch enabled")
    } catch (e: Exception) {
        Log.w("NFC", "⚠️ Foreground dispatch error: ${e.message}")
    }
}

private fun disableNfcForegroundDispatch() {
    try {
        val adapter = NfcAdapter.getDefaultAdapter(this) ?: return
        adapter.disableForegroundDispatch(this)
    } catch (_: Exception) {}
}

private fun sendNfcToFlutter(payload: HashMap<String, Any>) {
    val ch = nfcChannel
    if (ch != null && flutterReadyForNfc) {
        ch.invokeMethod("onNfcTagFromIntent", payload)
    } else {
        // 엔진/Flutter 준비 전이면 보류 (가장 최근 1건만 유지)
        pendingNfcPayload = payload
    }
}

private fun handleNfcIntent(intent: Intent?): HashMap<String, Any>? {
    if (intent == null) return null

    val action = intent.action ?: ""
    // 1) 커스텀 스킴 VIEW (NDEF URI + AAR로 실행될 때 흔함)
    if (action == Intent.ACTION_VIEW) {
        val data = intent.data ?: return null
        val role = data.getQueryParameter("role") ?: ""
        val tagId = data.getQueryParameter("tagId") ?: ""
        return hashMapOf(
            "uri" to data.toString(),
            "role" to role,
            "tagUid" to tagId
        )
    }

    // 2) NDEF_DISCOVERED / TECH_DISCOVERED 로 들어오는 경우
    if (action == "android.nfc.action.NDEF_DISCOVERED" || action == "android.nfc.action.TECH_DISCOVERED" || action == "android.nfc.action.TAG_DISCOVERED") {
        // ★ NFC 첫 태그 보완: TAG_DISCOVERED에서도 UID 추출
        val tag = intent.getParcelableExtra<android.nfc.Tag>(NfcAdapter.EXTRA_TAG)
        val tagUidHex = tag?.id?.joinToString("") { "%02X".format(it) } ?: ""

        // 먼저 intent.data를 시도
        val data = intent.data
        if (data != null) {
            val role = data.getQueryParameter("role") ?: ""
            val tagId = data.getQueryParameter("tagId") ?: tagUidHex
            return hashMapOf(
                "uri" to data.toString(),
                "role" to role,
                "tagUid" to tagId
            )
        }

        // fallback: EXTRA_NDEF_MESSAGES에서 URI 레코드 추출
        try {
            val rawMsgs = intent.getParcelableArrayExtra(NfcAdapter.EXTRA_NDEF_MESSAGES)
            if (rawMsgs != null && rawMsgs.isNotEmpty()) {
                val msg = rawMsgs[0] as NdefMessage
                val recs = msg.records
                if (recs.isNotEmpty()) {
                    val maybeUri = parseUriFromNdefRecord(recs[0])
                    if (maybeUri != null) {
                        val role = maybeUri.getQueryParameter("role") ?: ""
                        val tagId = maybeUri.getQueryParameter("tagId") ?: tagUidHex
                        return hashMapOf(
                            "uri" to maybeUri.toString(),
                            "role" to role,
                            "tagUid" to tagId
                        )
                    }
                }
            }
        } catch (_: Exception) { }

        // ★ NFC 첫 태그 보완: NDEF 없어도 UID만으로 전달 (UID 매칭 폴백)
        if (tagUidHex.isNotEmpty()) {
            Log.d("NFC", "TAG_DISCOVERED fallback: UID=$tagUidHex")
            return hashMapOf(
                "uri" to "",
                "role" to "",
                "tagUid" to tagUidHex
            )
        }
    }

    return null
}

// NDEF URI 레코드(RTD_URI 또는 WELL_KNOWN U)에서 Uri 파싱 (간단 버전)
private fun parseUriFromNdefRecord(record: NdefRecord): Uri? {
    return try {
        // WELL_KNOWN + RTD_URI
        val isWellKnownUri =
            record.tnf == NdefRecord.TNF_WELL_KNOWN &&
            record.type.contentEquals(NdefRecord.RTD_URI)

        if (!isWellKnownUri) return null

        val payload = record.payload ?: return null
        if (payload.isEmpty()) return null

        // NFC Forum "URI Record Type Definition"
        // payload[0] = URI Identifier Code (prefix)
        val prefix = when (payload[0].toInt()) {
            0x00 -> ""
            0x01 -> "http://www."
            0x02 -> "https://www."
            0x03 -> "http://"
            0x04 -> "https://"
            else -> ""
        }
        val uriStr = prefix + String(payload, 1, payload.size - 1, Charsets.UTF_8)
        Uri.parse(uriStr)
    } catch (_: Exception) {
        null
    }
}

private fun enableSilentReaderMode() {
    val adapter = NfcAdapter.getDefaultAdapter(this) ?: return
    if (silentReaderEnabled) return
    silentReaderEnabled = true

    val flags = NfcAdapter.FLAG_READER_NFC_A or
            NfcAdapter.FLAG_READER_NFC_B or
            NfcAdapter.FLAG_READER_NFC_F or
            NfcAdapter.FLAG_READER_NFC_V or
            NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS

    adapter.enableReaderMode(
        this,
        { /* reader callback not used */ },
        flags,
        Bundle()
    )
}

private fun disableSilentReaderMode() {
    val adapter = NfcAdapter.getDefaultAdapter(this) ?: return
    if (!silentReaderEnabled) return
    silentReaderEnabled = false
    adapter.disableReaderMode(this)
}


    // ══════════════════════════════════════════
    //  Bug #3: Kotlin AlarmManager (Samsung 호환)
    // ══════════════════════════════════════════

    companion object {
                const val NFC_NOTIF_CHANNEL_ID = "cheonhong_nfc"
        const val NFC_NOTIF_ID = 3001

const val ALARM_NOTIF_CHANNEL_ID = "cheonhong_native_alarm"
        const val ALARM_REQUEST_CODE = 2001
    }

    private fun createAlarmNotificationChannel() {

       
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                ALARM_NOTIF_CHANNEL_ID,
                "기상 알람 (네이티브)",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "CHEONHONG STUDIO 기상 알람 — 절대 놓치지 않는 알람"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500, 200, 500)
                setBypassDnd(true) // DND 무시
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                val sound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                setSound(sound, AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build())
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }


    private fun createNfcNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NFC_NOTIF_CHANNEL_ID,
                "NFC 처리 알림",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "NFC 태그 처리 결과 알림"
                enableVibration(false)
                setSound(null, null)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    private fun showNfcNotification(title: String, body: String) {
        val intent = Intent(this, MainActivity::class.java)
        val pi = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notif = NotificationCompat.Builder(this, NFC_NOTIF_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(pi)
            .build()

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NFC_NOTIF_ID, notif)
    }

    private fun requestPostNotificationsPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                9001
            )
        }
    }

    private fun scheduleNativeAlarm(hour: Int, minute: Int, activeDays: List<Int>, label: String) {
        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager

        // 다음 알람 시간 계산
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        // 이미 지난 시간이면 내일로
        if (cal.timeInMillis <= System.currentTimeMillis()) {
            cal.add(Calendar.DAY_OF_YEAR, 1)
        }
        // activeDays에 해당하는 요일까지 이동 (Calendar: 일=1, 월=2 ... 토=7)
        // Flutter activeDays: 월=1 ... 일=7 → Calendar: 월=2 ... 일=1
        if (activeDays.isNotEmpty()) {
            var safeguard = 0
            while (safeguard < 8) {
                val calDow = cal.get(Calendar.DAY_OF_WEEK)
                val flutterDow = if (calDow == Calendar.SUNDAY) 7 else calDow - 1
                if (activeDays.contains(flutterDow)) break
                cal.add(Calendar.DAY_OF_YEAR, 1)
                safeguard++
            }
        }

        val intent = Intent(this, AlarmReceiver::class.java).apply {
            putExtra("label", label)
            putExtra("hour", hour)
            putExtra("minute", minute)
        }
        val pi = PendingIntent.getBroadcast(
            this, ALARM_REQUEST_CODE, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // setAlarmClock: Samsung에서 가장 신뢰성 높음 (상태바에 알람 아이콘 표시)
        val showIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        try {
            am.setAlarmClock(
                AlarmManager.AlarmClockInfo(cal.timeInMillis, showIntent),
                pi
            )
        } catch (e: SecurityException) {
            // Fallback: exact alarm 불가 시 inexact
            am.set(AlarmManager.RTC_WAKEUP, cal.timeInMillis, pi)
        }

        // SharedPreferences에 저장 (다음 알람 스케줄링용)
        getSharedPreferences("alarm_prefs", MODE_PRIVATE).edit().apply {
            putInt("hour", hour)
            putInt("minute", minute)
            putString("activeDays", activeDays.joinToString(","))
            putString("label", label)
            putBoolean("enabled", true)
            apply()
        }
    }

    private fun cancelNativeAlarm() {
        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java)
        val pi = PendingIntent.getBroadcast(
            this, ALARM_REQUEST_CODE, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        am.cancel(pi)

        getSharedPreferences("alarm_prefs", MODE_PRIVATE).edit().apply {
            putBoolean("enabled", false)
            apply()
        }
    }

    private fun requestBatteryOptimizationExemption() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                try {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:$packageName")
                    }
                    startActivity(intent)
                } catch (_: Exception) {}
            }
        }
    }

    private fun isBatteryOptimized(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            return pm.isIgnoringBatteryOptimizations(packageName)
        }
        return true
    }

    private fun canScheduleExactAlarms(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            return am.canScheduleExactAlarms()
        }
        return true
    }

    // ─── 방해금지 모드 (Bug #1 관련 기능) ───

    private fun enableDndMode() {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.isNotificationPolicyAccessGranted) {
                nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
            }
        } catch (_: Exception) {}
    }

    private fun disableDndMode() {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.isNotificationPolicyAccessGranted) {
                nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
            }
        } catch (_: Exception) {}
    }

    // ─── UsageStats ───

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun getTodayUsageStats(): List<Map<String, Any>> {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val cal = Calendar.getInstance()
        val endTime = cal.timeInMillis
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        val startTime = cal.timeInMillis

        val stats = usm.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY, startTime, endTime
        )

        if (stats.isNullOrEmpty()) return emptyList()

        val pm = packageManager
        val result = mutableListOf<Map<String, Any>>()

        for (s in stats) {
            val totalMin = (s.totalTimeInForeground / 60000).toInt()
            if (totalMin < 1) continue

            val pkg = s.packageName
            if (pkg.startsWith("com.android.") || pkg.startsWith("com.sec.") ||
                pkg == packageName || pkg.startsWith("com.samsung.")) continue

            val appName = try {
                val ai = pm.getApplicationInfo(pkg, 0)
                pm.getApplicationLabel(ai).toString()
            } catch (e: PackageManager.NameNotFoundException) {
                pkg.substringAfterLast('.')
            }

            val category = categorizeApp(pkg)

            result.add(mapOf(
                "packageName" to pkg,
                "appName" to appName,
                "usageMinutes" to totalMin,
                "category" to category
            ))
        }

        return result.sortedByDescending { it["usageMinutes"] as Int }
    }

    private fun categorizeApp(pkg: String): String {
        val l = pkg.lowercase()
        return when {
            listOf("instagram", "twitter", "facebook", "tiktok", "reddit",
                "discord", "kakao", "line", "telegram", "snapchat", "threads")
                .any { l.contains(it) } -> "sns"
            listOf("youtube", "netflix", "twitch", "tving", "wavve", "watcha",
                "coupangplay", "disney")
                .any { l.contains(it) } -> "video"
            listOf("anki", "notion", "evernote", "goodnotes", "flexcil",
                "quizlet", "duolingo")
                .any { l.contains(it) } -> "study"
            else -> "other"
        }
    }

    // ─── Foreground App ───

    private fun getForegroundPackage(): String? {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val stats = usm.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY, now - 10000, now
        )
        if (stats.isNullOrEmpty()) return null
        return stats.maxByOrNull { it.lastTimeUsed }?.packageName
    }

    // ─── WiFi SSID ───

    private fun getCurrentWifiSsid(): String? {
        return try {
            val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val info = wm.connectionInfo
            if (info != null && info.ssid != null && info.ssid != "<unknown ssid>") {
                info.ssid.trim('"')
            } else null
        } catch (e: Exception) {
            null
        }
    }
}

// ══════════════════════════════════════════
//  AlarmReceiver: 알람 시간 → ForegroundService 기동
//  Samsung A15 프로세스 킬 대응: 모든 로직을 Service에서 처리
// ══════════════════════════════════════════
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val label = intent.getStringExtra("label") ?: "⏰ 기상 시간!"
        val hour = intent.getIntExtra("hour", 7)
        val minute = intent.getIntExtra("minute", 0)

        android.util.Log.d("AlarmReceiver", "🔔 알람 트리거: ${hour}:${minute}")

        // ═══ 핵심: ForegroundService 즉시 기동 ═══
        try {
            val serviceIntent = Intent(context, AlarmForegroundService::class.java).apply {
                putExtra("label", label)
                putExtra("hour", hour)
                putExtra("minute", minute)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (e: Exception) {
            android.util.Log.e("AlarmReceiver", "ForegroundService 시작 실패: $e")
            // 폴백: 기존 알림 방식
            fallbackNotification(context, label, hour, minute)
        }

        // 다음 알람 자동 스케줄링
        scheduleNextAlarm(context, hour, minute)
    }

    private fun fallbackNotification(context: Context, label: String, hour: Int, minute: Int) {
        val notifIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pi = PendingIntent.getActivity(
            context, 0, notifIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val sound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        val notif = NotificationCompat.Builder(context, MainActivity.ALARM_NOTIF_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(label)
            .setContentText("목표 기상: %02d:%02d — NFC 태그를 스캔하세요!".format(hour, minute))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(pi, true)
            .setOngoing(true)
            .setAutoCancel(false)
            .setSound(sound)
            .setContentIntent(pi)
            .build()
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(MainActivity.ALARM_REQUEST_CODE, notif)
    }

    private fun scheduleNextAlarm(context: Context, hour: Int, minute: Int) {
        val prefs = context.getSharedPreferences("alarm_prefs", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("enabled", false)) return

        val activeDaysStr = prefs.getString("activeDays", "1,2,3,4,5,6") ?: "1,2,3,4,5,6"
        val activeDays = activeDaysStr.split(",").mapNotNull { it.trim().toIntOrNull() }
        val label = prefs.getString("label", "⏰ 기상 시간!") ?: "⏰ 기상 시간!"

        val cal = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
        }

        if (activeDays.isNotEmpty()) {
            var safeguard = 0
            while (safeguard < 8) {
                val calDow = cal.get(Calendar.DAY_OF_WEEK)
                val flutterDow = if (calDow == Calendar.SUNDAY) 7 else calDow - 1
                if (activeDays.contains(flutterDow)) break
                cal.add(Calendar.DAY_OF_YEAR, 1)
                safeguard++
            }
        }

        val alarmIntent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra("label", label)
            putExtra("hour", hour)
            putExtra("minute", minute)
        }
        val pi = PendingIntent.getBroadcast(
            context, MainActivity.ALARM_REQUEST_CODE, alarmIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val showIntent = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        try {
            am.setAlarmClock(
                AlarmManager.AlarmClockInfo(cal.timeInMillis, showIntent),
                pi
            )
        } catch (e: SecurityException) {
            am.set(AlarmManager.RTC_WAKEUP, cal.timeInMillis, pi)
        }
    }
}

// ══════════════════════════════════════════
//  BootReceiver: 재부팅 후 알람 복원
// ══════════════════════════════════════════
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            val prefs = context.getSharedPreferences("alarm_prefs", Context.MODE_PRIVATE)
            if (!prefs.getBoolean("enabled", false)) return

            val hour = prefs.getInt("hour", 7)
            val minute = prefs.getInt("minute", 0)
            val activeDaysStr = prefs.getString("activeDays", "1,2,3,4,5,6") ?: "1,2,3,4,5,6"
            val activeDays = activeDaysStr.split(",").mapNotNull { it.trim().toIntOrNull() }
            val label = prefs.getString("label", "⏰ 기상 시간!") ?: "⏰ 기상 시간!"

            val cal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
            }
            if (cal.timeInMillis <= System.currentTimeMillis()) {
                cal.add(Calendar.DAY_OF_YEAR, 1)
            }
            if (activeDays.isNotEmpty()) {
                var safeguard = 0
                while (safeguard < 8) {
                    val calDow = cal.get(Calendar.DAY_OF_WEEK)
                    val flutterDow = if (calDow == Calendar.SUNDAY) 7 else calDow - 1
                    if (activeDays.contains(flutterDow)) break
                    cal.add(Calendar.DAY_OF_YEAR, 1)
                    safeguard++
                }
            }

            val alarmIntent = Intent(context, AlarmReceiver::class.java).apply {
                putExtra("label", label)
                putExtra("hour", hour)
                putExtra("minute", minute)
            }
            val pi = PendingIntent.getBroadcast(
                context, MainActivity.ALARM_REQUEST_CODE, alarmIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val showIntent = PendingIntent.getActivity(
                context, 0,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            try {
                am.setAlarmClock(
                    AlarmManager.AlarmClockInfo(cal.timeInMillis, showIntent),
                    pi
                )
            } catch (_: SecurityException) {
                am.set(AlarmManager.RTC_WAKEUP, cal.timeInMillis, pi)
            }
        }
    }
}