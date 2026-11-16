package com.Alertschool.alert_school

import android.Manifest
import android.app.AlarmManager
import android.content.Intent
import android.content.ActivityNotFoundException
import android.content.pm.PackageManager
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private var fileResult: MethodChannel.Result? = null

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
                    "getReadiness" -> result.success(readiness())
                    "repairPermission" -> {
                        openPermission(call.argument<String>("permission") ?: "")
                        result.success(null)
                    }
                    "confirmAutostartConfigured" -> {
                        AlarmStore.preferences(this)
                            .edit()
                            .putBoolean("autostart_confirmed", true)
                            .apply()
                        result.success(null)
                    }
                    "playTestBell" -> {
                        AlarmScheduler.startTestBell(this)
                        result.success(null)
                    }
                    "scheduleTestBell" -> {
                        AlarmScheduler.scheduleTestBell(this)
                        result.success(null)
                    }
                    "pickSound" -> pickDocument("audio/*", REQUEST_SOUND, result)
                    "importScheduleFile" ->
                        pickDocument("application/json", REQUEST_IMPORT, result)
                    "exportScheduleFile" ->
                        createDocument(call.argument<String>("json") ?: "", result)
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
        val audio = getSystemService(AUDIO_SERVICE) as AudioManager
        val volume = audio.getStreamVolume(AudioManager.STREAM_ALARM) > 0
        val manufacturer = Build.MANUFACTURER.orEmpty()
        val isKnownOem = listOf(
            "xiaomi", "redmi", "poco", "huawei", "honor", "oppo",
            "realme", "vivo", "samsung", "oneplus"
        ).any { manufacturer.contains(it, ignoreCase = true) }
        return mapOf(
            "notifications" to notifications,
            "exactAlarms" to exact,
            "battery" to battery,
            "autostart" to AlarmStore.preferences(this)
                .getBoolean("autostart_confirmed", !isKnownOem),
            "alarmVolume" to volume,
            "manufacturer" to manufacturer,
            "instructions" to manufacturerInstructions(manufacturer)
        )
    }

    private fun manufacturerInstructions(manufacturer: String): String {
        val name = manufacturer.lowercase()
        return when {
            name.contains("xiaomi") || name.contains("redmi") || name.contains("poco") ->
                "شاومي: فعّل التشغيل التلقائي من تطبيق الأمان، اختر بلا قيود للبطارية، " +
                    "ثم اقفل التطبيق في قائمة التطبيقات الحديثة."
            name.contains("huawei") || name.contains("honor") ->
                "هواوي/هونر: من تشغيل التطبيقات (App launch) فعّل الإدارة اليدوية " +
                    "للتطبيق والسماح بالتشغيل التلقائي والعمل بالخلفية."
            name.contains("oppo") || name.contains("realme") ->
                "أوبو/ريلمي: فعّل Auto launch وAllow background activity، " +
                    "واجعل تحسين البطارية غير مقيّد."
            name.contains("vivo") ->
                "فيفو: فعّل Autostart وHigh background power consumption، " +
                    "وأبقِ التطبيق ضمن التطبيقات الحديثة."
            name.contains("samsung") ->
                "سامسونج: أضف التطبيق إلى Never sleeping apps من إعدادات البطارية، " +
                    "ولا تضعه ضمن التطبيقات في وضع السكون."
            name.contains("oneplus") ->
                "ون بلس: اسمح بالتشغيل التلقائي والخلفية، واختر عدم تحسين البطارية، " +
                    "واقفل التطبيق في التطبيقات الحديثة إن توفر الخيار."
            else ->
                "أندرويد: اسمح بإشعارات التطبيق والمنبهات الدقيقة واستثناء تحسين البطارية. " +
                    "قد تتطلب بعض الواجهات المصنعة إعداداً يدوياً إضافياً."
        }
    }

    private fun openPermission(permission: String) {
        when (permission) {
            "notifications" -> {
                if (Build.VERSION.SDK_INT >= 33) {
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                        REQUEST_NOTIFICATIONS
                    )
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
            "autostart" -> startOemAutostartSettings()
            "alarmVolume" -> startSettings(Intent(Settings.ACTION_SOUND_SETTINGS))
        }
    }

    private fun startOemAutostartSettings() {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val candidates = when {
            manufacturer.contains("xiaomi") || manufacturer.contains("redmi") ||
                manufacturer.contains("poco") -> listOf(
                Intent("miui.intent.action.OP_AUTO_START")
                    .setClassName(
                        "com.miui.securitycenter",
                        "com.miui.permcenter.autostart.AutoStartManagementActivity"
                    )
            )
            manufacturer.contains("huawei") || manufacturer.contains("honor") -> listOf(
                Intent().setClassName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
                )
            )
            manufacturer.contains("oppo") || manufacturer.contains("realme") -> listOf(
                Intent().setClassName(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.startupapp.StartupAppListActivity"
                )
            )
            manufacturer.contains("vivo") -> listOf(
                Intent().setClassName(
                    "com.iqoo.secure",
                    "com.iqoo.secure.safeguard.PurviewTabActivity"
                )
            )
            manufacturer.contains("samsung") -> listOf(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(Uri.parse("package:$packageName")),
                Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS)
            )
            manufacturer.contains("oneplus") -> listOf(
                Intent().setClassName(
                    "com.oneplus.security",
                    "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"
                ),
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(Uri.parse("package:$packageName"))
            )
            else -> listOf(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(Uri.parse("package:$packageName"))
            )
        }
        val intent = candidates.firstOrNull {
            it.resolveActivity(packageManager) != null
        } ?: Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.parse("package:$packageName"))
        startSettings(intent)
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

    private fun pickDocument(
        mimeType: String,
        requestCode: Int,
        result: MethodChannel.Result
    ) {
        if (fileResult != null) {
            result.error("PICKER_BUSY", "A document picker is already open.", null)
            return
        }
        fileResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
            )
        }
        startActivityForResult(intent, requestCode)
    }

    private fun createDocument(json: String, result: MethodChannel.Result) {
        if (fileResult != null) {
            result.error("PICKER_BUSY", "A document picker is already open.", null)
            return
        }
        pendingExport = json
        fileResult = result
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
            putExtra(Intent.EXTRA_TITLE, "school_schedules.json")
        }
        startActivityForResult(intent, REQUEST_EXPORT)
    }

    private var pendingExport: String? = null
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val result = fileResult ?: return
        fileResult = null
        if (resultCode != RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }
        val uri = data.data!!
        try {
            when (requestCode) {
                REQUEST_SOUND -> {
                    contentResolver.takePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION
                    )
                    result.success(uri.toString())
                }
                REQUEST_IMPORT -> {
                    val contents = contentResolver.openInputStream(uri)
                        ?.bufferedReader()
                        ?.use { it.readText() }
                        ?: throw IllegalStateException("Unable to read selected JSON file.")
                    result.success(contents)
                }
                REQUEST_EXPORT -> {
                    val contents = pendingExport
                        ?: throw IllegalStateException("Export data is missing.")
                    contentResolver.openOutputStream(uri)?.bufferedWriter()?.use {
                        it.write(contents)
                    } ?: throw IllegalStateException("Unable to write selected file.")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("DOCUMENT_IO", error.message, null)
        } finally {
            pendingExport = null
        }
    }

    companion object {
        private const val CHANNEL = "school_bell/alarm"
        private const val REQUEST_SOUND = 4201
        private const val REQUEST_IMPORT = 4202
        private const val REQUEST_EXPORT = 4203
        private const val REQUEST_NOTIFICATIONS = 4204
    }
}
