package com.cheonhong.cheonhong_studio

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationServices
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import java.util.Calendar

/**
 * 빅스비 루틴 알림 감지 → 외출/귀가 자동 기록
 *
 * - "CHSTUDIO_OUT"  → movement.pending 기록 + GPS
 * - "CHSTUDIO_HOME" → pending이면 취소, confirmed out이면 귀가 기록
 */
class BixbyNotificationListener : NotificationListenerService() {

    companion object {
        private const val TAG = "BixbyListener"
        private const val UID = "sJ8Pxusw9gR0tNR44RhkIge7OiG2"
        private const val OUT_KEYWORD = "CHSTUDIO_OUT"
        private const val HOME_KEYWORD = "CHSTUDIO_HOME"
        private const val MY_BOT = "8514127849:AAF8_F7SBfm51SGHtp9X5lva7yexdnFyapo"
        private const val MY_CHAT = "8724548311"
        private const val GF_BOT = "8613977898:AAEuuoTVARS-a9nrDp85NWHHOYM0lRvmZmc"
        private const val GF_CHAT = "8624466505"
    }

    private fun db() = FirebaseFirestore.getInstance()
    private fun iotRef() = db().document("users/$UID/data/iot")

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val notification = sbn?.notification ?: return
        val extras = notification.extras ?: return
        val title = extras.getString("android.title") ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        val content = "$title $text"

        when {
            content.contains(OUT_KEYWORD) -> handleOut()
            content.contains(HOME_KEYWORD) -> handleHome()
        }
    }

    // ═══════════════════════════════════════════
    //  OUT — 즉시 기록 안 함, pending만 저장
    // ═══════════════════════════════════════════

    private fun handleOut() {
        Log.d(TAG, "OUT detected")

        // GPS 1회 획득 후 Firestore 기록
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
            == PackageManager.PERMISSION_GRANTED
        ) {
            val client = LocationServices.getFusedLocationProviderClient(this)
            client.lastLocation.addOnSuccessListener { location: Location? ->
                writeOutPending(location?.latitude, location?.longitude)
            }.addOnFailureListener {
                writeOutPending(null, null)
            }
        } else {
            writeOutPending(null, null)
        }
    }

    private fun writeOutPending(lat: Double?, lng: Double?) {
        val timeStr = timeStr()
        val data = hashMapOf<String, Any>(
            "movement" to hashMapOf(
                "pending" to true,
                "leftAt" to FieldValue.serverTimestamp(),
                "leftAtLocal" to timeStr,
                "type" to "pending"
            )
        )

        if (lat != null && lng != null) {
            data["lastLocation"] = hashMapOf(
                "latitude" to lat,
                "longitude" to lng,
                "updatedAt" to FieldValue.serverTimestamp()
            )
        }

        iotRef().set(data, SetOptions.merge())
            .addOnSuccessListener {
                Log.d(TAG, "OUT pending saved: $timeStr")
                val locStr = if (lat != null && lng != null) "\n📍 ${String.format("%.4f", lat)},${String.format("%.4f", lng)}" else ""
                sendTelegram("🚶 외출 감지 $timeStr — 20분 타이머 시작$locStr", meOnly = true)
            }
            .addOnFailureListener { Log.e(TAG, "OUT save error: ${it.message}") }
    }

    // ═══════════════════════════════════════════
    //  HOME — pending이면 취소, confirmed이면 귀가
    // ═══════════════════════════════════════════

    private fun handleHome() {
        Log.d(TAG, "HOME detected")

        iotRef().get().addOnSuccessListener { doc ->
            @Suppress("UNCHECKED_CAST")
            val movement = doc.get("movement") as? Map<String, Any> ?: return@addOnSuccessListener
            val pending = movement["pending"] as? Boolean ?: false
            val type = movement["type"] as? String ?: ""

            if (pending) {
                // 20분 안 됐음 → pending 취소 (외출 아님)
                val returnTime = timeStr()
                iotRef().update(
                    mapOf(
                        "movement.pending" to false,
                        "movement.type" to "cancelled"
                    )
                )
                val leftLocal = movement["leftAtLocal"] as? String
                val dur = calcDuration(leftLocal, returnTime)
                sendTelegram("✅ 복귀 $returnTime — 외출 취소$dur", meOnly = true)
                Log.d(TAG, "HOME: pending cancelled (short outing)")
            } else if (type == "out") {
                // 확정된 외출에서 귀가
                confirmReturn(movement)
            }
        }
    }

    private fun confirmReturn(movement: Map<String, Any>) {
        val returnTime = timeStr()
        val dateStr = todayKey()

        // 경과시간 계산
        val leftAtLocal = movement["leftAtLocal"] as? String
        val durationStr = calcDuration(leftAtLocal, returnTime)

        // data/iot movement 업데이트
        iotRef().update(
            mapOf(
                "movement.type" to "home",
                "movement.returnedAt" to FieldValue.serverTimestamp(),
                "movement.returnedAtLocal" to returnTime
            )
        )

        // data/study timeRecords 귀가 기록
        db().document("users/$UID/data/study").set(
            hashMapOf("timeRecords" to hashMapOf(dateStr to hashMapOf("returnHome" to returnTime))),
            SetOptions.merge()
        )

        // SharedPreferences → Flutter 상태 동기화
        val prefs = applicationContext.getSharedPreferences(
            "FlutterSharedPreferences", Context.MODE_PRIVATE
        )
        prefs.edit()
            .putString("flutter.nfc_state", "returned")
            .putString("flutter.nfc_state_date", dateStr)
            .apply()

        // 텔레그램
        sendTelegram("🏠 귀가 $returnTime$durationStr")
        Log.d(TAG, "HOME: return confirmed $returnTime")
    }

    // ═══════════════════════════════════════════
    //  유틸
    // ═══════════════════════════════════════════

    private fun timeStr(): String {
        val cal = Calendar.getInstance()
        return String.format(
            "%02d:%02d",
            cal.get(Calendar.HOUR_OF_DAY),
            cal.get(Calendar.MINUTE)
        )
    }

    private fun todayKey(): String {
        val cal = Calendar.getInstance()
        if (cal.get(Calendar.HOUR_OF_DAY) < 4) {
            cal.add(Calendar.DAY_OF_MONTH, -1)
        }
        return String.format(
            "%d-%02d-%02d",
            cal.get(Calendar.YEAR),
            cal.get(Calendar.MONTH) + 1,
            cal.get(Calendar.DAY_OF_MONTH)
        )
    }

    private fun calcDuration(from: String?, to: String): String {
        if (from == null) return ""
        try {
            val fp = from.split(":").map { it.toInt() }
            val tp = to.split(":").map { it.toInt() }
            val m = (tp[0] * 60 + tp[1]) - (fp[0] * 60 + fp[1])
            if (m <= 0) return ""
            return " (${m / 60}h${(m % 60).toString().padStart(2, '0')}m)"
        } catch (_: Exception) {
            return ""
        }
    }

    private fun sendTelegram(msg: String, meOnly: Boolean = false) {
        Thread {
            try {
                val bots = if (meOnly) arrayOf(MY_BOT to MY_CHAT)
                           else arrayOf(MY_BOT to MY_CHAT, GF_BOT to GF_CHAT)
                for ((token, chatId) in bots) {
                    val url = java.net.URL("https://api.telegram.org/bot$token/sendMessage")
                    val conn = url.openConnection() as java.net.HttpURLConnection
                    conn.requestMethod = "POST"
                    conn.setRequestProperty("Content-Type", "application/json; charset=utf-8")
                    conn.doOutput = true
                    conn.outputStream.write(
                        """{"chat_id":"$chatId","text":"$msg"}""".toByteArray(Charsets.UTF_8)
                    )
                    conn.responseCode
                    conn.disconnect()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Telegram error: ${e.message}")
            }
        }.start()
    }
}
