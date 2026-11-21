package cn.edu.ubaa.ubaa_flutter.background

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import cn.edu.ubaa.ubaa_flutter.R
import cn.edu.ubaa.ubaa_flutter.reminders.Reminders

/**
 * 常驻前台服务：让进程不被系统随手回收，并在没有界面时托管一份 Flutter 引擎。
 *
 * 用 specialUse 类型，开机广播和精确闹钟都允许拉起它（Android 15 起 dataSync 不行）。
 */
class KeepAliveService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startInForeground()
        if (!KeepAlive.enabled(this)) {
            stopSelf()
            return START_NOT_STICKY
        }
        val existed = EngineHolder.cached() != null
        EngineHolder.ensure(this)
        // 新起的引擎还没跑到 Dart，启动后会自己检查签到窗口。
        if (intent?.action == KeepAlive.ACTION_WAKE && existed) EngineHolder.wake()
        return START_STICKY
    }

    private fun startInForeground() {
        val manager = getSystemService(NotificationManager::class.java)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (manager?.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(CHANNEL_ID, "后台运行", NotificationManager.IMPORTANCE_MIN)
                channel.description = "课前自动签到需要应用在后台保持运行"
                channel.setShowBadge(false)
                manager?.createNotificationChannel(channel)
            }
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this).setPriority(Notification.PRIORITY_MIN)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_reminder)
            .setContentTitle("UBAA 后台运行中")
            .setContentText("用于课前自动签到，可在设置中关闭")
            .setOngoing(true)
            .setContentIntent(Reminders.openApp(this))
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    companion object {
        private const val CHANNEL_ID = "background"
        private const val NOTIFICATION_ID = 4108
    }
}
