package cn.edu.ubaa.ubaa_flutter.background

import android.content.Context
import cn.edu.ubaa.ubaa_flutter.ContextChannels
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Dart 的 ChannelKeepAliveGateway 对应的原生端。 */
class KeepAliveChannel(
    private val context: Context,
    private val engine: FlutterEngine,
    private val owner: ContextChannels,
) {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "cn.edu.buaa.ubaa/keep-alive")

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setEnabled" -> {
                    val enabled = call.arguments as? Boolean ?: false
                    // 先接管引擎再起服务，服务里就不会再新建一个。
                    if (enabled) EngineHolder.adopt(engine, owner)
                    KeepAlive.setEnabled(context, enabled)
                    result.success(null)
                }
                "scheduleWakes" -> {
                    val times = (call.arguments as? List<*>)?.mapNotNull { (it as? Number)?.toLong() }
                    KeepAlive.scheduleWakes(context, times ?: emptyList())
                    result.success(null)
                }
                "release" -> {
                    KeepAlive.release()
                    result.success(null)
                }
                "batteryUnrestricted" -> result.success(KeepAlive.batteryUnrestricted(context))
                "requestUnrestricted" -> {
                    KeepAlive.requestUnrestricted(context)
                    result.success(null)
                }
                "openAutostart" -> {
                    KeepAlive.openAutostart(context)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun sendWake() {
        channel.invokeMethod("wake", null)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }
}
