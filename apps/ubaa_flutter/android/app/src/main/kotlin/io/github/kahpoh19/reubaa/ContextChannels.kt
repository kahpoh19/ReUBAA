package io.github.kahpoh19.reubaa

import android.content.Context
import io.github.kahpoh19.reubaa.background.EngineHolder
import io.github.kahpoh19.reubaa.background.KeepAliveChannel
import io.github.kahpoh19.reubaa.platform.AppearanceChannel
import io.github.kahpoh19.reubaa.platform.DefaultNetworkChannel
import io.github.kahpoh19.reubaa.platform.PrivatePaths
import io.github.kahpoh19.reubaa.reminders.NotificationsChannel
import io.github.kahpoh19.reubaa.widgets.WidgetChannel
import io.flutter.embedding.engine.FlutterEngine

/** 只需要 Context 的平台通道，没有界面的后台引擎也要注册这些。 */
class ContextChannels(context: Context, engine: FlutterEngine) {
    private val messenger = engine.dartExecutor.binaryMessenger
    private val network = DefaultNetworkChannel(context, messenger)
    private val paths = PrivatePaths(context, messenger)
    private val widgets = WidgetChannel(context, messenger)
    private val appearance = AppearanceChannel(context, messenger)
    val notifications = NotificationsChannel(context, messenger) { EngineHolder.activity }
    val keepAlive = KeepAliveChannel(context, engine, this)

    fun dispose() {
        keepAlive.dispose()
        notifications.dispose()
        appearance.dispose()
        widgets.dispose()
        paths.dispose()
        network.dispose()
    }
}
