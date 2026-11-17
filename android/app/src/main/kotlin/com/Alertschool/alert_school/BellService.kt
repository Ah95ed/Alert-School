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
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat
import org.json.JSONObject

class BellService : Service() {
    private var player: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val handler = Handler(Looper.getMainLooper())
    private val stopPlayback = Runnable { stopRinging() }
    private var vibrator: Vibrator? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopRinging()
            return START_NOT_STICKY
        }
        val bellJson = intent?.getStringExtra(EXTRA_BELL) ?: "{}"
        val bell = JSONObject(bellJson)
        val settings = AlarmStore.settings(this)
        player?.release()
        player = null
        handler.removeCallbacks(stopPlayback)
        AlarmStore.preferences(this).edit()
            .putBoolean(KEY_RINGING, true)
            .putString(KEY_RING_TITLE, bell.optString("lessonName", "جرس"))
            .putString(KEY_RING_TYPE, bell.optString("type", "start"))
            .apply()
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
        if (settings.optBoolean("vibrationEnabled", true)) vibrate()
        val durationSeconds = settings.optInt("ringDurationSeconds", 10).coerceIn(1, 120)
        handler.postDelayed(stopPlayback, durationSeconds * 1_000L)
        playSound(settings)
        return START_NOT_STICKY
    }

    private fun playSound(settings: JSONObject) {
        val sound = settings.optString("soundUri", "")
        val configuredVolume =
            settings.optDouble("alarmVolume", 1.0).toFloat().coerceIn(0f, 1f)
        val mediaPlayer = MediaPlayer()
        player = mediaPlayer
        try {
            mediaPlayer.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            if (sound.startsWith("file:")) {
                mediaPlayer.setDataSource(this, Uri.parse(sound))
            } else if (sound.startsWith("/")) {
                mediaPlayer.setDataSource(sound)
            } else if (sound.isNotEmpty()) {
                mediaPlayer.setDataSource(this, Uri.parse(sound))
            } else {
                mediaPlayer.setDataSource(this, defaultAlarmUri())
            }
            mediaPlayer.setVolume(configuredVolume, configuredVolume)
            mediaPlayer.setOnPreparedListener { it.start() }
            mediaPlayer.setOnCompletionListener { finishPlayback() }
            mediaPlayer.setOnErrorListener { _, what, extra ->
                AlarmStore.log("MediaPlayer error $what/$extra")
                useSystemAlarmAfterCustomFailure(settings)
                true
            }
            mediaPlayer.prepareAsync()
        } catch (error: Exception) {
            AlarmStore.log("Unable to play the configured bell sound.", error)
            useSystemAlarmAfterCustomFailure(settings)
        }
    }

    private fun useSystemAlarmAfterCustomFailure(settings: JSONObject) {
        player?.release()
        player = MediaPlayer()
        AlarmStore.log("Falling back to the system alarm sound.")
        val fallback = player ?: return
        try {
            fallback.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            fallback.setDataSource(this, defaultAlarmUri())
            val volume = settings.optDouble("alarmVolume", 1.0).toFloat().coerceIn(0f, 1f)
            fallback.setVolume(volume, volume)
            fallback.setOnPreparedListener { it.start() }
            fallback.setOnCompletionListener { finishPlayback() }
            fallback.prepareAsync()
        } catch (error: Exception) {
            AlarmStore.log("Unable to play the system alarm fallback.", error)
            finishPlayback()
        }
    }

    private fun defaultAlarmUri(): Uri =
        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            ?: throw IllegalStateException("No system alarm ringtone is available.")

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
    private fun vibrate() {
        val pattern = longArrayOf(0, 350, 180, 350)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            vibrator = getSystemService(VibratorManager::class.java).defaultVibrator
            vibrator?.vibrate(
                VibrationEffect.createWaveform(pattern, -1)
            )
        } else {
            vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, -1)
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
            else -> "بداية الحصة"
        }
        val stopIntent = PendingIntent.getBroadcast(
            this,
            8201,
            Intent(this, StopReceiver::class.java).setAction(StopReceiver.ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val ringIntent = PendingIntent.getActivity(
            this,
            8202,
            Intent(this, RingActivity::class.java)
                .putExtra(RingActivity.EXTRA_LESSON, bell.optString("lessonName", "جرس"))
                .putExtra(RingActivity.EXTRA_TYPE, bell.optString("type", "start")),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notificationManager = getSystemService(NotificationManager::class.java)
        val fullScreenAllowed = Build.VERSION.SDK_INT < 34 ||
            notificationManager.canUseFullScreenIntent()
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("جرس المدرسة · $type")
            .setContentText(bell.optString("lessonName", "جرس"))
            .setContentIntent(contentIntent)
            .setFullScreenIntent(ringIntent, fullScreenAllowed)
            .addAction(android.R.drawable.ic_media_pause, "إيقاف", stopIntent)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setOngoing(true)
            .setAutoCancel(false)
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
        handler.removeCallbacks(stopPlayback)
        vibrator?.cancel()
        vibrator = null
        clearRingingState()
        player?.release()
        player = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun stopRinging() {
        handler.removeCallbacks(stopPlayback)
        player?.release()
        player = null
        vibrator?.cancel()
        vibrator = null
        clearRingingState()
        getSystemService(NotificationManager::class.java).cancel(NOTIFICATION_ID)
        stopForeground(STOP_FOREGROUND_REMOVE)
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        stopSelf()
    }

    private fun clearRingingState() {
        AlarmStore.preferences(this).edit()
            .putBoolean(KEY_RINGING, false)
            .remove(KEY_RING_TITLE)
            .remove(KEY_RING_TYPE)
            .apply()
        sendBroadcast(
            Intent(StopReceiver.ACTION_RING_STOPPED).setPackage(packageName)
        )
    }

    override fun onDestroy() {
        handler.removeCallbacks(stopPlayback)
        vibrator?.cancel()
        vibrator = null
        player?.release()
        player = null
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        if (AlarmStore.preferences(this).getBoolean(KEY_RINGING, false)) {
            clearRingingState()
        }
        getSystemService(NotificationManager::class.java).cancel(NOTIFICATION_ID)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val ACTION_STOP = "com.Alertschool.alert_school.STOP_BELL"
        const val KEY_RINGING = "ringing_active"
        const val KEY_RING_TITLE = "ringing_title"
        const val KEY_RING_TYPE = "ringing_type"
        private const val CHANNEL_ID = "school_bells"
        private const val NOTIFICATION_ID = 42100
        private const val EXTRA_BELL = "bell_json"

        fun start(context: Context, bell: JSONObject) {
            val intent = Intent(context, BellService::class.java)
                .putExtra(EXTRA_BELL, bell.toString())
            androidx.core.content.ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            context.sendBroadcast(
                Intent(context, StopReceiver::class.java).setAction(StopReceiver.ACTION_STOP)
            )
        }
    }
}
