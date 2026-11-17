package com.Alertschool.alert_school

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class RingActivity : Activity() {
    private val stoppedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            finish()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        val title = intent.getStringExtra(EXTRA_LESSON) ?: "جرس المدرسة"
        val type = if (intent.getStringExtra(EXTRA_TYPE) == "end") {
            "انتهاء الحصة"
        } else {
            "دخول الحصة"
        }
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(40), dp(40), dp(40), dp(40))
            setBackgroundColor(Color.rgb(255, 248, 231))
        }
        content.addView(TextView(this).apply {
            text = title
            textSize = 30f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.rgb(74, 59, 38))
            gravity = Gravity.CENTER
        })
        content.addView(TextView(this).apply {
            text = type
            textSize = 20f
            setTextColor(Color.rgb(138, 122, 92))
            gravity = Gravity.CENTER
            setPadding(0, dp(24), 0, dp(40))
        })
        content.addView(Button(this).apply {
            text = "إيقاف"
            textSize = 24f
            setTextColor(Color.rgb(74, 59, 38))
            setBackgroundColor(Color.rgb(224, 169, 59))
            setOnClickListener {
                sendBroadcast(
                    Intent(this@RingActivity, StopReceiver::class.java)
                        .setAction(StopReceiver.ACTION_STOP)
                )
                finish()
            }
        }, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            dp(72)
        ))
        setContentView(content)

        val filter = IntentFilter(StopReceiver.ACTION_RING_STOPPED)
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(stoppedReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(stoppedReceiver, filter)
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(stoppedReceiver)
        } catch (_: IllegalArgumentException) {
            // The receiver may not be registered if creation failed before setup.
        }
        super.onDestroy()
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density + 0.5f).toInt()

    companion object {
        const val EXTRA_LESSON = "lesson_name"
        const val EXTRA_TYPE = "bell_type"
    }
}
