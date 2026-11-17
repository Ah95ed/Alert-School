package com.Alertschool.alert_school

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale

internal object AlarmPlanner {
    fun rebuild(context: Context) {
        val schedules = AlarmStore.schedules(context)
        val settings = AlarmStore.settings(context)
        val activeId = AlarmStore.activeScheduleId(context)
        val schedule = findSchedule(schedules, activeId)
        if (schedule == null) {
            AlarmStore.preferences(context).edit().putString("plan_json", "[]").apply()
            return
        }
        val bells = JSONArray()
        val now = System.currentTimeMillis()
        val pausedDate = settings.optString("pausedDate", "")
        val lessons = schedule.optJSONArray("lessons") ?: JSONArray()
        val activeWeekdays = schedule.optJSONArray("activeWeekdays") ?: JSONArray()

        for (offset in 0..6) {
            val day = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                add(Calendar.DAY_OF_YEAR, offset)
            }
            if (!contains(activeWeekdays, day.get(Calendar.DAY_OF_WEEK).toDateTimeWeekday())) {
                continue
            }
            if (dateKey(day) == pausedDate) continue

            var previousStart: Calendar? = null
            var previousLesson: JSONObject? = null
            for (index in 0 until lessons.length()) {
                val lesson = lessons.optJSONObject(index) ?: continue
                if (!lesson.optBoolean("enabled", true)) continue
                val start = if (lesson.optString("startMode") == "auto" &&
                    previousStart != null && previousLesson != null
                ) {
                    (previousStart.clone() as Calendar).apply {
                        add(Calendar.MINUTE, previousLesson.optInt("durationMinutes", 0))
                        add(Calendar.MINUTE, previousLesson.optInt("breakAfterMinutes", 0))
                    }
                } else {
                    (day.clone() as Calendar).apply {
                        add(Calendar.MINUTE, lesson.optInt("startMinute", 0))
                        if (previousStart != null && !after(previousStart)) {
                            add(Calendar.DAY_OF_YEAR, 1)
                        }
                    }
                }

                if (lesson.optBoolean("bellOnStart", true)) {
                    addBell(bells, start.timeInMillis, "start", lesson, now)
                }
                if (lesson.optBoolean("bellOnEnd", true)) {
                    val end = (start.clone() as Calendar).apply {
                        add(Calendar.MINUTE, lesson.optInt("durationMinutes", 0))
                    }
                    addBell(bells, end.timeInMillis, "end", lesson, now)
                }
                previousStart = start
                previousLesson = lesson
            }
        }

        val sorted = (0 until bells.length())
            .mapNotNull { bells.optJSONObject(it) }
            .sortedBy { it.optLong("timestampMillis") }
        val result = JSONArray()
        sorted.forEach(result::put)
        AlarmStore.preferences(context).edit().putString("plan_json", result.toString()).apply()
    }

    private fun findSchedule(schedules: JSONArray, id: String): JSONObject? {
        for (index in 0 until schedules.length()) {
            val schedule = schedules.optJSONObject(index) ?: continue
            if (schedule.optString("id") == id) return schedule
        }
        return null
    }

    private fun addBell(
        bells: JSONArray,
        timestamp: Long,
        type: String,
        lesson: JSONObject,
        now: Long
    ) {
        if (timestamp <= now) return
        val lessonId = lesson.optString("id")
        val bell = JSONObject()
            .put("timestampMillis", timestamp)
            .put("type", type)
            .put("lessonName", lesson.optString("name"))
            .put("lessonId", lessonId)
            .put("id", "${lessonId}_${type}_$timestamp")
        bells.put(bell)
    }

    private fun contains(values: JSONArray, target: Int): Boolean =
        (0 until values.length()).any { values.optInt(it) == target }

    private fun Int.toDateTimeWeekday(): Int =
        if (this == Calendar.SUNDAY) 7 else this - 1

    private fun dateKey(calendar: Calendar): String =
        String.format(
            Locale.US,
            "%04d-%02d-%02d",
            calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH) + 1,
            calendar.get(Calendar.DAY_OF_MONTH)
        )
}
