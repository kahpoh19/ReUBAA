package cn.edu.ubaa.ubaa_flutter

import android.content.Context
import cn.edu.ubaa.ubaa_flutter.background.EngineHolder
import cn.edu.ubaa.ubaa_flutter.background.KeepAliveChannel
import cn.edu.ubaa.ubaa_flutter.platform.AppearanceChannel
import cn.edu.ubaa.ubaa_flutter.platform.DefaultNetworkChannel
import cn.edu.ubaa.ubaa_flutter.platform.PrivatePaths
import cn.edu.ubaa.ubaa_flutter.reminders.NotificationsChannel
import cn.edu.ubaa.ubaa_flutter.widgets.WidgetChannel
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
