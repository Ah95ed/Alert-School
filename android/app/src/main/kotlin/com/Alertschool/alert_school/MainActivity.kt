package com.Alertschool.alert_school

import android.Manifest
import android.app.AlarmManager
import android.content.Intent
import android.content.ActivityNotFoundException
import android.content.pm.PackageManager
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import java.io.File
import java.io.FileInputStream
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private var fileResult: MethodChannel.Result? = null
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "syncPlan" -> {
                        val payload = JSONObject(call.arguments as Map<*, *>)
                        AlarmScheduler.syncFromFlutter(this, payload)
                        result.success(null)
                    }
                    "isBellRinging" -> result.success(
                        AlarmStore.preferences(this)
                            .getBoolean(BellService.KEY_RINGING, false)
                    )
                    "stopBell" -> {
                        BellService.stop(this)
                        result.success(null)
                    }
                    "getReadiness" -> result.success(readiness())
                    "repairPermission" -> {
                        val waitsForPermission =
                            openPermission(call.argument<String>("permission") ?: "", result)
                        if (!waitsForPermission) result.success(null)
                    }
                    "chooseSystemSound" -> chooseSystemSound(result)
                    "copySoundFile" -> copySoundFile(
                        call.argument<String>("path") ?: "",
                        call.argument<String>("name") ?: "",
                        result
                    )
                    else -> result.notImplemented()
                }
            }
    }

    override fun onResume() {
        super.onResume()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
        ) {
            AlarmScheduler.scheduleNext(this)
        }
    }

    private fun readiness(): Map<String, Any> {
        val alarmManager = getSystemService(AlarmManager::class.java)
        val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            alarmManager.canScheduleExactAlarms()
        val notifications = Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        val power = getSystemService(POWER_SERVICE) as PowerManager
        val battery = Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            power.isIgnoringBatteryOptimizations(packageName)
        return mapOf(
            "notifications" to notifications,
            "exactAlarms" to exact,
            "battery" to battery
        )
    }

    private fun openPermission(
        permission: String,
        result: MethodChannel.Result
    ): Boolean {
        when (permission) {
            "notifications" -> {
                if (Build.VERSION.SDK_INT >= 33) {
                    if (ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.POST_NOTIFICATIONS
                        ) == PackageManager.PERMISSION_GRANTED
                    ) {
                        return false
                    }
                    val permissionPreferences =
                        getSharedPreferences(PERMISSION_PREFS, MODE_PRIVATE)
                    val requestedBefore = permissionPreferences.getBoolean(
                        NOTIFICATIONS_REQUESTED,
                        false
                    )
                    if (requestedBefore &&
                        !ActivityCompat.shouldShowRequestPermissionRationale(
                            this,
                            Manifest.permission.POST_NOTIFICATIONS
                        )
                    ) {
                        startSettings(
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        )
                        return false
                    }
                    permissionPreferences.edit()
                        .putBoolean(NOTIFICATIONS_REQUESTED, true)
                        .apply()
                    permissionResult = result
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                        REQUEST_NOTIFICATIONS
                    )
                    return true
                }
            }
            "exactAlarms" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    startSettings(
                        Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                            .setData(Uri.parse("package:$packageName"))
                    )
                }
            }
            "battery" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    startSettings(
                        Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                            .setData(Uri.parse("package:$packageName"))
                    )
                }
            }
        }
        return false
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_NOTIFICATIONS) {
            permissionResult?.success(null)
            permissionResult = null
        }
    }

    private fun startSettings(intent: Intent) {
        try {
            startActivity(intent)
        } catch (_: ActivityNotFoundException) {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(Uri.parse("package:$packageName"))
            )
        }
    }

    private fun chooseSystemSound(result: MethodChannel.Result) {
        if (fileResult != null) {
            result.error("PICKER_BUSY", "A picker is already open.", null)
            return
        }
        fileResult = result
        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
            putExtra(
                RingtoneManager.EXTRA_RINGTONE_TYPE,
                RingtoneManager.TYPE_ALARM or
                    RingtoneManager.TYPE_NOTIFICATION or
                    RingtoneManager.TYPE_RINGTONE
            )
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
            val saved = AlarmStore.settings(this@MainActivity).optString("soundUri")
            if (saved.isNotEmpty() && saved.startsWith("content:")) {
                putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, Uri.parse(saved))
            }
        }
        try {
            startActivityForResult(intent, REQUEST_SYSTEM_SOUND)
        } catch (error: ActivityNotFoundException) {
            fileResult = null
            result.error("RINGTONE_PICKER", "No system ringtone picker is available.", null)
        }
    }

    private fun copySoundFile(path: String, name: String, result: MethodChannel.Result) {
        try {
            val source = File(path).canonicalFile
            if (!source.isFile) {
                throw IllegalArgumentException("The selected audio file is unavailable.")
            }
            val extension = name.substringAfterLast('.', "").lowercase()
            if (extension !in setOf("mp3", "wav", "ogg", "m4a")) {
                throw IllegalArgumentException("Choose an MP3, WAV, OGG or M4A audio file.")
            }
            val directory = File(filesDir, "bell_audio")
            if (!directory.exists() && !directory.mkdirs()) {
                throw IllegalStateException("Unable to create the audio storage directory.")
            }
            val target = File(directory, "school_bell.$extension")
            val temporary = File(directory, "school_bell.$extension.tmp")
            FileInputStream(source).use { input ->
                temporary.outputStream().use { output -> input.copyTo(output) }
            }
            if (target.exists() && !target.delete()) {
                temporary.delete()
                throw IllegalStateException("Unable to replace the saved audio file.")
            }
            if (!temporary.renameTo(target)) {
                temporary.delete()
                throw IllegalStateException("Unable to finish saving the audio file.")
            }
            result.success(
                mapOf(
                    "uri" to Uri.fromFile(target).toString(),
                    "name" to name
                )
            )
        } catch (error: Exception) {
            result.error("AUDIO_COPY", error.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val result = fileResult ?: return
        fileResult = null
        if (resultCode != RESULT_OK || requestCode != REQUEST_SYSTEM_SOUND) {
            result.success(null)
            return
        }
        try {
            val picked = data?.getParcelableExtra<Uri>(
                RingtoneManager.EXTRA_RINGTONE_PICKED_URI
            ) ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                ?: throw IllegalStateException("No system ringtone is available.")
            val title = RingtoneManager.getRingtone(this, picked)
                ?.getTitle(this) ?: "منبه النظام"
            result.success(mapOf("uri" to picked.toString(), "name" to title))
        } catch (error: Exception) {
            result.error("RINGTONE_PICKER", error.message, null)
        }
    }

    companion object {
        private const val CHANNEL = "school_bell/alarm"
        private const val REQUEST_NOTIFICATIONS = 4204
        private const val REQUEST_SYSTEM_SOUND = 4205
        private const val PERMISSION_PREFS = "school_bell_permission_state"
        private const val NOTIFICATIONS_REQUESTED = "notifications_requested"
    }
}
