package com.Alertschool.alert_school

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONObject

class BellReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_MISSED_BELL) {
            val missed = intent.getStringExtra(EXTRA_BELL_JSON)?.let(::JSONObject) ?: return
            val missedId = missed.optString("id")
            if (AlarmStore.lastFiredId(context) == missedId) return
            playDueBells(context, AlarmStore.bellsAt(
                context,
                missed.optLong("timestampMillis")
            ).ifEmpty { listOf(missed) })
            AlarmScheduler.scheduleNext(context)
            return
        }
        val id = intent.getStringExtra(EXTRA_BELL_ID) ?: return
        if (AlarmStore.lastFiredId(context) == id) return
        val bell = AlarmStore.findBell(context, id) ?: return
        playDueBells(context, AlarmStore.bellsAt(
            context,
            bell.optLong("timestampMillis")
        ).ifEmpty { listOf(bell) })
        AlarmScheduler.scheduleNext(context)
    }

    private fun playDueBells(context: Context, bells: List<JSONObject>) {
        bells.forEach { bell ->
            AlarmStore.markFired(context, bell.optString("id"))
            AlarmStore.removeBell(context, bell.optString("id"))
        }
        val type = if (bells.any { it.optString("type") == "start" }) "start" else "end"
        val combined = JSONObject()
            .put("id", bells.joinToString("_") { it.optString("id") })
            .put("type", type)
            .put(
                "lessonName",
                bells.map { it.optString("lessonName") }.distinct().joinToString("، ")
            )
        BellService.start(context, combined)
    }

    companion object {
        const val ACTION_BELL = "com.Alertschool.alert_school.SCHOOL_BELL"
        const val ACTION_MISSED_BELL = "com.Alertschool.alert_school.MISSED_BELL"
        const val EXTRA_BELL_ID = "bell_id"
        const val EXTRA_BELL_JSON = "bell_json"
    }
}
