package com.Alertschool.alert_school

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.NotificationManager
import android.os.Build
import android.os.Vibrator
import android.os.VibratorManager

class StopReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_STOP) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(VibratorManager::class.java).defaultVibrator.cancel()
        } else {
            @Suppress("DEPRECATION")
            (context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator).cancel()
        }
        context.getSystemService(NotificationManager::class.java).cancel(42100)
        AlarmStore.preferences(context).edit()
            .putBoolean(BellService.KEY_RINGING, false)
            .remove(BellService.KEY_RING_TITLE)
            .remove(BellService.KEY_RING_TYPE)
            .apply()
        context.sendBroadcast(
            Intent(ACTION_RING_STOPPED).setPackage(context.packageName)
        )
        context.stopService(Intent(context, BellService::class.java))
    }

    companion object {
        const val ACTION_STOP = "com.Alertschool.alert_school.STOP_RINGING"
        const val ACTION_RING_STOPPED = "com.Alertschool.alert_school.RING_STOPPED"
    }
}
