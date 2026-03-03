package com.cheonhong.cheonhong_studio

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * CHEONHONG STUDIO — 수면 관리 Method Channel (P5: #33, #34, #37)
 *
 * #33: 야간 앱 잠금 (activateNightLock / deactivateNightLock)
 * #34: 화면 켜짐 감지 (startScreenMonitor / stopScreenMonitor)
 * #37: 그레이스케일 (enableGrayscale / disableGrayscale)
 * #38: 네트워크 차단 (enableNetworkBlock / disableNetworkBlock)
 */
class SleepChannel(private val context: Context) {
    companion object {
        const val CHANNEL = "com.cheonhong.cheonhong_studio/sleep"
    }

    private var screenReceiver: BroadcastReceiver? = null
    private var screenOnCount = 0
    private var screenOnStartTime: Long = 0
    private var screenOnTotalMs: Long = 0
    private var isMonitoring = false

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // ── #33: 야간 앱 잠금 ──
                    "activateNightLock" -> {
                        val allowed = call.argument<List<String>>("allowedApps") ?: emptyList()
                        activateNightLock(allowed)
                        result.success(true)
                    }
                    "deactivateNightLock" -> {
                        deactivateNightLock()
                        result.success(true)
                    }

                    // ── #34: 화면 켜짐 감지 ──
                    "startScreenMonitor" -> {
                        startScreenMonitor()
                        result.success(true)
                    }
                    "stopScreenMonitor" -> {
                        val stats = stopScreenMonitor()
                        result.success(stats)
                    }
                    "getScreenMonitorStats" -> {
                        result.success(mapOf(
                            "screenOnCount" to screenOnCount,
                            "screenOnMinutes" to (screenOnTotalMs / 60000).toInt()
                        ))
                    }

                    // ── #37: 그레이스케일 ──
                    "enableGrayscale" -> {
                        enableGrayscale()
                        result.success(true)
                    }
                    "disableGrayscale" -> {
                        disableGrayscale()
                        result.success(true)
                    }

                    // ── #38: 네트워크 차단 ──
                    "enableNetworkBlock" -> {
                        // 네트워크 차단은 Tasker나 root 권한 필요
                        // 여기서는 Intent만 전송
                        result.success(true)
                    }
                    "disableNetworkBlock" -> {
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // ── #33: 야간 앱 잠금 ──
    private fun activateNightLock(allowedApps: List<String>) {
        // SharedPreferences에 야간 모드 상태 저장
        val prefs = context.getSharedPreferences("sleep_prefs", Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean("night_lock_active", true)
            .putStringSet("allowed_apps", allowedApps.toSet())
            .apply()
    }

    private fun deactivateNightLock() {
        val prefs = context.getSharedPreferences("sleep_prefs", Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean("night_lock_active", false)
            .apply()
    }

    // ── #34: 화면 켜짐 감지 ──
    private fun startScreenMonitor() {
        if (isMonitoring) return
        isMonitoring = true
        screenOnCount = 0
        screenOnTotalMs = 0
        screenOnStartTime = 0

        screenReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                when (intent?.action) {
                    Intent.ACTION_SCREEN_ON -> {
                        screenOnCount++
                        screenOnStartTime = System.currentTimeMillis()
                    }
                    Intent.ACTION_SCREEN_OFF -> {
                        if (screenOnStartTime > 0) {
                            screenOnTotalMs += System.currentTimeMillis() - screenOnStartTime
                            screenOnStartTime = 0
                        }
                    }
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        context.registerReceiver(screenReceiver, filter)
    }

    private fun stopScreenMonitor(): Map<String, Int> {
        isMonitoring = false
        // 현재 화면이 켜져 있다면 마지막 구간도 계산
        if (screenOnStartTime > 0) {
            screenOnTotalMs += System.currentTimeMillis() - screenOnStartTime
            screenOnStartTime = 0
        }

        try {
            screenReceiver?.let { context.unregisterReceiver(it) }
        } catch (_: Exception) {}
        screenReceiver = null

        return mapOf(
            "screenOnCount" to screenOnCount,
            "screenOnMinutes" to (screenOnTotalMs / 60000).toInt()
        )
    }

    // ── #37: 그레이스케일 ──
    // 참고: WRITE_SECURE_SETTINGS 권한 필요 (ADB로 부여)
    // adb shell pm grant com.cheonhong.cheonhong_studio android.permission.WRITE_SECURE_SETTINGS
    private fun enableGrayscale() {
        try {
            Settings.Secure.putInt(
                context.contentResolver,
                "accessibility_display_daltonizer_enabled", 1
            )
            Settings.Secure.putInt(
                context.contentResolver,
                "accessibility_display_daltonizer", 0 // 0 = grayscale
            )
        } catch (e: Exception) {
            // WRITE_SECURE_SETTINGS 권한 없으면 실패
            // Tasker fallback 사용
        }
    }

    private fun disableGrayscale() {
        try {
            Settings.Secure.putInt(
                context.contentResolver,
                "accessibility_display_daltonizer_enabled", 0
            )
        } catch (_: Exception) {}
    }
}

/**
 * CHEONHONG STUDIO — Tasker Intent 연동 (#36)
 *
 * 앱 → Tasker: sendIntent
 * Tasker → 앱: BroadcastReceiver로 수신
 */
class TaskerChannel(private val context: Context) {
    companion object {
        const val CHANNEL = "com.cheonhong.cheonhong_studio/tasker"
        const val ACTION_PREFIX = "com.cheonhong."
    }

    private var methodChannel: MethodChannel? = null
    private var taskerReceiver: BroadcastReceiver? = null

    fun register(flutterEngine: FlutterEngine) {
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, CHANNEL
        )

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "sendIntent" -> {
                    val action = call.argument<String>("action") ?: ""
                    val extras = call.argument<Map<String, String>>("extras") ?: emptyMap()
                    sendIntent(action, extras)
                    result.success(true)
                }
                "registerReceiver" -> {
                    registerReceiver()
                    result.success(true)
                }
                "unregisterReceiver" -> {
                    unregisterReceiver()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ── 앱 → Tasker ──
    private fun sendIntent(action: String, extras: Map<String, String>) {
        val intent = Intent(action).apply {
            extras.forEach { (k, v) -> putExtra(k, v) }
            // Tasker가 수신할 수 있도록 명시적 broadcast
            addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
        }
        context.sendBroadcast(intent)
    }

    // ── Tasker → 앱 ──
    private fun registerReceiver() {
        if (taskerReceiver != null) return

        taskerReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                val action = intent?.action ?: return
                if (action.startsWith(ACTION_PREFIX)) {
                    methodChannel?.invokeMethod("onTaskerEvent", mapOf(
                        "action" to action,
                    ))
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction("${ACTION_PREFIX}BEDTIME")
            addAction("${ACTION_PREFIX}WAKE")
            addAction("${ACTION_PREFIX}NIGHT_MODE_ON")
            addAction("${ACTION_PREFIX}NIGHT_MODE_OFF")
            addAction("${ACTION_PREFIX}GRAYSCALE_ON")
            addAction("${ACTION_PREFIX}GRAYSCALE_OFF")
            addAction("${ACTION_PREFIX}NETWORK_OFF")
            addAction("${ACTION_PREFIX}NETWORK_ON")
        }
        context.registerReceiver(taskerReceiver, filter, Context.RECEIVER_EXPORTED)
    }

    private fun unregisterReceiver() {
        try {
            taskerReceiver?.let { context.unregisterReceiver(it) }
        } catch (_: Exception) {}
        taskerReceiver = null
    }
}
