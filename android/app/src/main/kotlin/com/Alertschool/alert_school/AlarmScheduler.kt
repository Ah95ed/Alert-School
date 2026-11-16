package com.Alertschool.alert_school

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject

internal object AlarmScheduler {
    private const val TEST_ACTION = "com.Alertschool.alert_school.TEST_BELL"

    fun syncFromFlutter(context: Context, payload: JSONObject) {
        AlarmStore.saveFlutterPlan(context, payload)
        scheduleNext(context)
        BellWorkers.enqueue(context)
    }

    fun rebuildAndSchedule(context: Context) {
        AlarmPlanner.rebuild(context)
        scheduleNext(context)
        BellWorkers.enqueueDailyRefresh(context)
    }

    fun scheduleNext(context: Context) {
        val manager = context.getSystemService(AlarmManager::class.java)
        cancelCurrent(context, manager)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            !manager.canScheduleExactAlarms()
        ) {
            AlarmStore.log("Exact alarm access is not granted; no alarm was scheduled.")
            return
        }
        val now = System.currentTimeMillis()
        val next = (0 until AlarmStore.plan(context).length())
            .mapNotNull { AlarmStore.plan(context).optJSONObject(it) }
            .filter { it.optLong("timestampMillis") > now }
            .minByOrNull { it.optLong("timestampMillis") }
            ?: return
        val id = next.optString("id")
        val receiver = PendingIntent.getBroadcast(
            context,
            id.hashCode(),
            Intent(context, BellReceiver::class.java)
                .setAction(BellReceiver.ACTION_BELL)
                .putExtra(BellReceiver.EXTRA_BELL_ID, id),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val showApp = PendingIntent.getActivity(
            context,
            9100,
            context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        try {
            manager.setAlarmClock(
                AlarmManager.AlarmClockInfo(next.optLong("timestampMillis"), showApp),
                receiver
            )
            AlarmStore.setScheduledId(context, id)
            AlarmStore.log("Scheduled next bell $id")
        } catch (error: SecurityException) {
            AlarmStore.log("Alarm scheduling was denied by Android.", error)
            AlarmStore.setScheduledId(context, "")
        }
    }

    fun scheduleTestBell(context: Context) {
        val manager = context.getSystemService(AlarmManager::class.java)
        val id = "test_${System.currentTimeMillis()}"
        val triggerAt = System.currentTimeMillis() + 60_000
        val operation = PendingIntent.getBroadcast(
            context,
            id.hashCode(),
            Intent(context, BellReceiver::class.java)
                .setAction(TEST_ACTION)
                .putExtra(BellReceiver.EXTRA_BELL_ID, id),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val showApp = PendingIntent.getActivity(
            context,
            id.hashCode(),
            context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        try {
            manager.setAlarmClock(
                AlarmManager.AlarmClockInfo(triggerAt, showApp),
                operation
            )
        } catch (error: SecurityException) {
            AlarmStore.log("Unable to schedule the one-minute test alarm.", error)
            throw error
        }
    }

    fun scheduleMissedBell(context: Context, bell: JSONObject) {
        val id = bell.optString("id")
        val operation = PendingIntent.getBroadcast(
            context,
            id.hashCode() xor 0x4B11,
            Intent(context, BellReceiver::class.java)
                .setAction(BellReceiver.ACTION_MISSED_BELL)
                .putExtra(BellReceiver.EXTRA_BELL_ID, id)
                .putExtra(BellReceiver.EXTRA_BELL_JSON, bell.toString()),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val showApp = PendingIntent.getActivity(
            context,
            id.hashCode() xor 0x4B12,
            context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        context.getSystemService(AlarmManager::class.java).setAlarmClock(
            AlarmManager.AlarmClockInfo(System.currentTimeMillis() + 1_000L, showApp),
            operation
        )
    }

    fun isTest(action: String?): Boolean = action == TEST_ACTION

    fun startTestBell(context: Context) {
        val test = JSONObject()
            .put("id", "test_${System.currentTimeMillis()}")
            .put("type", "start")
            .put("lessonName", "جرس تجريبي")
        BellService.start(context, test, testMode = true)
    }

    private fun cancelCurrent(context: Context, manager: AlarmManager) {
        val id = AlarmStore.scheduledId(context)
        if (id.isEmpty()) return
        val old = PendingIntent.getBroadcast(
            context,
            id.hashCode(),
            Intent(context, BellReceiver::class.java)
                .setAction(BellReceiver.ACTION_BELL)
                .putExtra(BellReceiver.EXTRA_BELL_ID, id),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        if (old != null) {
            manager.cancel(old)
            old.cancel()
        }
        AlarmStore.setScheduledId(context, "")
    }
}
