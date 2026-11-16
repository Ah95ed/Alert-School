package com.Alertschool.alert_school

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

internal object AlarmStore {
    private const val TAG = "SchoolBell"
    private const val PREFS = "school_bell_native"
    private const val PLAN = "plan_json"
    private const val SCHEDULES = "schedules_json"
    private const val ACTIVE_SCHEDULE = "active_schedule_id"
    private const val SETTINGS = "settings_json"
    private const val SCHEDULED_ID = "scheduled_bell_id"
    private const val LAST_FIRED_ID = "last_fired_bell_id"

    fun preferences(context: Context) =
        context.createDeviceProtectedStorageContext()
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun saveFlutterPlan(context: Context, payload: JSONObject) {
        val preferences = preferences(context)
        preferences.edit()
            .putString(PLAN, payload.optJSONArray("bells")?.toString() ?: "[]")
            .putString(SCHEDULES, payload.optJSONArray("schedules")?.toString() ?: "[]")
            .putString(ACTIVE_SCHEDULE, payload.optString("activeScheduleId"))
            .putString(SETTINGS, payload.optJSONObject("settings")?.toString() ?: "{}")
            .apply()
    }

    fun plan(context: Context): JSONArray =
        JSONArray(preferences(context).getString(PLAN, "[]") ?: "[]")

    fun schedules(context: Context): JSONArray =
        JSONArray(preferences(context).getString(SCHEDULES, "[]") ?: "[]")

    fun settings(context: Context): JSONObject =
        JSONObject(preferences(context).getString(SETTINGS, "{}") ?: "{}")

    fun activeScheduleId(context: Context): String =
        preferences(context).getString(ACTIVE_SCHEDULE, "") ?: ""

    fun scheduledId(context: Context): String =
        preferences(context).getString(SCHEDULED_ID, "") ?: ""

    fun setScheduledId(context: Context, id: String) {
        preferences(context).edit().putString(SCHEDULED_ID, id).apply()
    }

    fun lastFiredId(context: Context): String =
        preferences(context).getString(LAST_FIRED_ID, "") ?: ""

    fun markFired(context: Context, id: String) {
        preferences(context).edit().putString(LAST_FIRED_ID, id).apply()
    }

    fun removeBell(context: Context, id: String) {
        val current = plan(context)
        val remaining = JSONArray()
        for (index in 0 until current.length()) {
            val bell = current.optJSONObject(index) ?: continue
            if (bell.optString("id") != id) remaining.put(bell)
        }
        preferences(context).edit().putString(PLAN, remaining.toString()).apply()
    }

    fun findBell(context: Context, id: String): JSONObject? {
        val bells = plan(context)
        for (index in 0 until bells.length()) {
            val bell = bells.optJSONObject(index) ?: continue
            if (bell.optString("id") == id) return bell
        }
        return null
    }

    fun bellsAt(context: Context, timestampMillis: Long): List<JSONObject> {
        val bells = plan(context)
        return (0 until bells.length()).mapNotNull { bells.optJSONObject(it) }
            .filter { it.optLong("timestampMillis") == timestampMillis }
    }

    fun log(message: String, error: Throwable? = null) {
        if (error == null) Log.i(TAG, message) else Log.e(TAG, message, error)
    }
}
