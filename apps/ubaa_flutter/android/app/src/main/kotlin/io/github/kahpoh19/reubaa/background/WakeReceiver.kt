package io.github.kahpoh19.reubaa.background

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** 课前的精确闹钟：拿住唤醒锁，确保服务和引擎在跑，再通知 Dart 检查签到窗口。 */
class WakeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (!KeepAlive.enabled(context)) return
        KeepAlive.hold(context)
        KeepAlive.startService(context, wake = true)
    }
}
