package com.Alertschool.alert_school

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AlarmStore.log("System event received: ${intent.action}")
        if (intent.action == Intent.ACTION_LOCKED_BOOT_COMPLETED) {
            AlarmPlanner.rebuild(context)
            AlarmScheduler.scheduleNext(context)
        } else {
            AlarmScheduler.rebuildAndSchedule(context)
        }
    }
}
