package io.github.kahpoh19.reubaa.background

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import org.json.JSONArray

/**
 * 课前签到的后台保活：开关存档、精确闹钟唤醒、唤醒锁和系统设置跳转。
 *
 * 不需要 root：前台服务 + 忽略电池优化在原生 Android 上就够了；国产系统还要用户
 * 自己在设置里允许自启动，这一步只能引导，代码里改不了。
 */
object KeepAlive {
    const val ACTION_WAKE = "io.github.kahpoh19.reubaa.WAKE"
    private const val PREFS = "ubaa_keep_alive"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_WAKES = "wakes"

    // 一节课的签到窗口是 20 分钟，唤醒锁多留 5 分钟，Dart 做完会提前释放。
    private const val HOLD_MS = 25 * 60 * 1000L
    private var wakeLock: PowerManager.WakeLock? = null

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun enabled(context: Context) = prefs(context).getBoolean(KEY_ENABLED, false)

    fun setEnabled(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_ENABLED, enabled).apply()
        if (enabled) {
            startService(context, wake = false)
        } else {
            scheduleWakes(context, emptyList())
            context.stopService(Intent(context, KeepAliveService::class.java))
            release()
        }
    }

    fun startService(context: Context, wake: Boolean) {
        val intent = Intent(context, KeepAliveService::class.java)
        if (wake) intent.action = ACTION_WAKE
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        } catch (_: Exception) {
            // Android 12 起后台不让随便起前台服务；闹钟、开机和界面里起都不受限，这里只是兜底。
        }
    }

    /** 整组替换唤醒时刻（毫秒时间戳），开机后按存档重排。 */
    fun scheduleWakes(context: Context, times: List<Long>) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        for (time in load(context)) {
            pending(context, time, PendingIntent.FLAG_NO_CREATE)?.let {
                alarms.cancel(it)
                it.cancel()
            }
        }
        val now = System.currentTimeMillis()
        val future = times.filter { it > now }.distinct().sorted()
        prefs(context).edit().putString(KEY_WAKES, JSONArray(future).toString()).apply()
        for (time in future) {
            val intent = pending(context, time, PendingIntent.FLAG_UPDATE_CURRENT) ?: continue
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarms.canScheduleExactAlarms()) {
                alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, intent)
            } else {
                alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, intent)
            }
        }
    }

    fun rescheduleWakes(context: Context) = scheduleWakes(context, load(context))

    private fun pending(context: Context, time: Long, flag: Int): PendingIntent? =
        PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, WakeReceiver::class.java)
                .setAction(ACTION_WAKE)
                .setData(Uri.parse("ubaa-wake://$time")),
            flag or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun load(context: Context): List<Long> = try {
        val array = JSONArray(prefs(context).getString(KEY_WAKES, "[]"))
        (0 until array.length()).map { array.getLong(it) }
    } catch (_: Exception) {
        emptyList()
    }

    /** 闹钟叫醒后拿住 CPU，熄屏也能把这一轮签到跑完。 */
    @Synchronized
    fun hold(context: Context) {
        val power = context.getSystemService(PowerManager::class.java) ?: return
        val lock = wakeLock ?: power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ubaa:course").also {
            it.setReferenceCounted(false)
            wakeLock = it
        }
        lock.acquire(HOLD_MS)
    }

    @Synchronized
    fun release() {
        wakeLock?.let { if (it.isHeld) it.release() }
    }

    fun batteryUnrestricted(context: Context): Boolean =
        context.getSystemService(PowerManager::class.java)?.isIgnoringBatteryOptimizations(context.packageName) == true

    fun requestUnrestricted(context: Context) {
        val request = Intent(
            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
            Uri.parse("package:${context.packageName}"),
        )
        if (!launch(context, request)) {
            launch(context, Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        }
    }

    // 各家自启动管理页的位置，系统更新后可能会变，找不到就退到应用详情页。
    private val autostartPages = listOf(
        "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
        "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
        "com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
        "com.oplus.safecenter" to "com.oplus.safecenter.permission.startup.StartupAppListActivity",
        "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
        "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
        "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
        "com.hihonor.systemmanager" to "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
        "com.samsung.android.lool" to "com.samsung.android.sm.battery.ui.BatteryActivity",
    )

    fun openAutostart(context: Context) {
        for ((pkg, cls) in autostartPages) {
            if (launch(context, Intent().setComponent(ComponentName(pkg, cls)))) return
        }
        launch(
            context,
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}")),
        )
    }

    private fun launch(context: Context, intent: Intent): Boolean = try {
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (_: Exception) {
        false
    }
}
