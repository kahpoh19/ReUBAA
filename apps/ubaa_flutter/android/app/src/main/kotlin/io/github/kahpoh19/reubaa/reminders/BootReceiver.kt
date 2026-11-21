package io.github.kahpoh19.reubaa.reminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.github.kahpoh19.reubaa.background.KeepAlive

/** 开机、应用更新、改系统时间后闹钟会被清掉，这里重排；开着后台保活时顺便拉起服务。 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> {
                Reminders.rescheduleAll(context)
                if (KeepAlive.enabled(context)) {
                    KeepAlive.rescheduleWakes(context)
                    // 改时间不算后台启动的豁免，只有开机和更新才拉服务。
                    if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
                        intent.action == Intent.ACTION_MY_PACKAGE_REPLACED
                    ) {
                        KeepAlive.startService(context, wake = false)
                    }
                }
            }
        }
    }
}
