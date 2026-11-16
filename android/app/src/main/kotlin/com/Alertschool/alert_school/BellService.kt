package com.Alertschool.alert_school

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat
import org.json.JSONObject

class BellService : Service() {
    private var player: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val bellJson = intent?.getStringExtra(EXTRA_BELL) ?: "{}"
        val bell = JSONObject(bellJson)
        val settings = AlarmStore.settings(this)
        createNotificationChannel()
        val notification = buildNotification(bell)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        acquireWakeLock()
        val reminder = bell.optString("type") == "reminder"
        if (settings.optBoolean("vibrationEnabled", true)) vibrate(reminder)
        playSound(settings, reminder)
        return START_NOT_STICKY
    }

    private fun playSound(settings: JSONObject, reminder: Boolean) {
        val sound = if (reminder) {
            "builtin:notification"
        } else {
            settings.optString("soundUri", "builtin:alarm")
        }
        val uri = when (sound) {
            "builtin:notification" ->
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            "builtin:ringtone" ->
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            "builtin:alarm", "" ->
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            else -> Uri.parse(sound)
        } ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            ?: throw IllegalStateException("No system alarm sound is available.")
        val configuredVolume =
            settings.optDouble("alarmVolume", 1.0).toFloat().coerceIn(0f, 1f)
        val volume = if (reminder) minOf(configuredVolume, 0.45f) else configuredVolume
        val mediaPlayer = MediaPlayer()
        player?.release()
        player = mediaPlayer
        try {
            mediaPlayer.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            mediaPlayer.setDataSource(this, uri)
            mediaPlayer.setVolume(volume, volume)
            mediaPlayer.setOnPreparedListener { it.start() }
            mediaPlayer.setOnCompletionListener { finishPlayback() }
            mediaPlayer.setOnErrorListener { _, what, extra ->
                AlarmStore.log("MediaPlayer error $what/$extra")
                if (!reminder && sound.startsWith("content:")) {
                    useSystemAlarmAfterCustomFailure(settings)
                } else {
                    finishPlayback()
                }
                true
            }
            mediaPlayer.prepareAsync()
        } catch (error: Exception) {
            AlarmStore.log("Unable to play the configured bell sound.", error)
            if (!reminder && sound.startsWith("content:")) {
                useSystemAlarmAfterCustomFailure(settings)
            } else {
                finishPlayback()
            }
        }
    }

    private fun useSystemAlarmAfterCustomFailure(settings: JSONObject) {
        player?.release()
        player = null
        AlarmStore.log("Falling back to the system alarm sound.")
        playSound(JSONObject(settings.toString()).put("soundUri", "builtin:alarm"), false)
    }

    private fun acquireWakeLock() {
        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = power.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "alert_school:bell_playback"
        ).apply {
            setReferenceCounted(false)
            acquire(180_000L)
        }
    }

    @Suppress("DEPRECATION")
    private fun vibrate(reminder: Boolean) {
        val pattern = if (reminder) longArrayOf(0, 120) else longArrayOf(0, 350, 180, 350)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(VibratorManager::class.java).defaultVibrator.vibrate(
                VibrationEffect.createWaveform(pattern, -1)
            )
        } else {
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                vibrator.vibrate(pattern, -1)
            }
        }
    }

    private fun buildNotification(bell: JSONObject): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        val contentIntent = PendingIntent.getActivity(
            this,
            8200,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val type = when (bell.optString("type")) {
            "end" -> "انتهاء الحصة"
            "reminder" -> "تذكير بموعد الحصة"
            else -> "بداية الحصة"
        }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("جرس المدرسة · $type")
            .setContentText(bell.optString("lessonName", "جرس"))
            .setContentIntent(contentIntent)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setAutoCancel(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "أجراس المدرسة",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "تنبيهات الدخول والخروج من الحصص"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    private fun finishPlayback() {
        player?.release()
        player = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        player?.release()
        player = null
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val CHANNEL_ID = "school_bells"
        private const val NOTIFICATION_ID = 42100
        private const val EXTRA_BELL = "bell_json"

        fun start(context: Context, bell: JSONObject, testMode: Boolean) {
            val intent = Intent(context, BellService::class.java)
                .putExtra(EXTRA_BELL, bell.toString())
                .putExtra("test_mode", testMode)
            androidx.core.content.ContextCompat.startForegroundService(context, intent)
        }
    }
}
