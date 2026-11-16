package com.Alertschool.alert_school

import android.content.Context
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.Calendar
import java.util.concurrent.TimeUnit

internal object BellWorkers {
    private const val WATCHDOG_WORK = "school_bell_watchdog"
    private const val DAILY_WORK = "school_bell_daily_refresh"

    fun enqueue(context: Context) {
        val work = PeriodicWorkRequestBuilder<WatchdogWorker>(15, TimeUnit.MINUTES)
            .build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            WATCHDOG_WORK,
            ExistingPeriodicWorkPolicy.KEEP,
            work
        )
        enqueueDailyRefresh(context)
    }

    fun enqueueDailyRefresh(context: Context) {
        val now = Calendar.getInstance()
        val midnight = (now.clone() as Calendar).apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 1)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val delay = (midnight.timeInMillis - now.timeInMillis).coerceAtLeast(1_000L)
        val work = OneTimeWorkRequestBuilder<DailyRefreshWorker>()
            .setInitialDelay(delay, TimeUnit.MILLISECONDS)
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(
            DAILY_WORK,
            ExistingWorkPolicy.REPLACE,
            work
        )
    }
}

class WatchdogWorker(context: Context, parameters: WorkerParameters) :
    Worker(context, parameters) {
    override fun doWork(): Result {
        return try {
            val now = System.currentTimeMillis()
            val bells = AlarmStore.plan(applicationContext)
            var missed: org.json.JSONObject? = null
            for (index in 0 until bells.length()) {
                val bell = bells.optJSONObject(index) ?: continue
                val timestamp = bell.optLong("timestampMillis")
                val id = bell.optString("id")
                if (timestamp <= now && now - timestamp < 120_000L &&
                    id != AlarmStore.lastFiredId(applicationContext)
                ) {
                    missed = bell
                    break
                }
            }
            if (missed != null) {
                AlarmScheduler.scheduleMissedBell(applicationContext, missed)
            } else {
                AlarmScheduler.scheduleNext(applicationContext)
            }
            Result.success()
        } catch (error: SecurityException) {
            AlarmStore.log("Watchdog could not start or schedule an exact alarm.", error)
            Result.retry()
        }
    }
}

class DailyRefreshWorker(context: Context, parameters: WorkerParameters) :
    Worker(context, parameters) {
    override fun doWork(): Result {
        AlarmStore.log("Refreshing the rolling seven-day bell plan.")
        AlarmScheduler.rebuildAndSchedule(applicationContext)
        return Result.success()
    }
}
