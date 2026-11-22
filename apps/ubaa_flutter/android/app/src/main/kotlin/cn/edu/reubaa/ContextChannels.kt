package cn.edu.reubaa

import android.content.Context
import cn.edu.reubaa.background.EngineHolder
import cn.edu.reubaa.background.KeepAliveChannel
import cn.edu.reubaa.platform.AppUpdateChannel
import cn.edu.reubaa.platform.AppearanceChannel
import cn.edu.reubaa.platform.DefaultNetworkChannel
import cn.edu.reubaa.platform.PrivatePaths
import cn.edu.reubaa.reminders.NotificationsChannel
import cn.edu.reubaa.widgets.WidgetChannel
import io.flutter.embedding.engine.FlutterEngine

/** 只需要 Context 的平台通道，没有界面的后台引擎也要注册这些。 */
class ContextChannels(context: Context, engine: FlutterEngine) {
    private val messenger = engine.dartExecutor.binaryMessenger
    private val network = DefaultNetworkChannel(context, messenger)
    private val paths = PrivatePaths(context, messenger)
    private val widgets = WidgetChannel(context, messenger)
    private val appearance = AppearanceChannel(context, messenger)
    private val update = AppUpdateChannel(context, messenger)
    val notifications = NotificationsChannel(context, messenger) { EngineHolder.activity }
    val keepAlive = KeepAliveChannel(context, engine, this)

    fun dispose() {
        keepAlive.dispose()
        notifications.dispose()
        update.dispose()
        appearance.dispose()
        widgets.dispose()
        paths.dispose()
        network.dispose()
    }
}
