package cn.edu.reubaa.background

import android.app.Activity
import android.content.Context
import cn.edu.reubaa.ContextChannels
import cn.edu.reubaa.NativeTls
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * 开启后台保活后，Flutter 引擎跟着进程走而不是跟着界面走：
 * 界面关掉引擎继续跑，后台服务拉起时没有界面也能跑 Dart，重新打开界面直接接上同一个引擎。
 *
 * 同一进程只能有一个 Dart 实例，不然会有两份 Core 会话、两份签到计划。
 */
object EngineHolder {
    private const val ENGINE_ID = "ubaa_main"

    /** 当前界面，申请通知权限要用；没有界面时为 null。 */
    var activity: Activity? = null
    private var channels: ContextChannels? = null

    fun cached(): FlutterEngine? = FlutterEngineCache.getInstance().get(ENGINE_ID)

    fun owns(owned: ContextChannels?) = owned != null && owned === channels

    fun channels(): ContextChannels? = channels

    /** 没有引擎就新建一个跑 main；只有和界面无关的通道，界面打开后再补上界面那几个。 */
    fun ensure(context: Context): FlutterEngine {
        cached()?.let { return it }
        val app = context.applicationContext
        NativeTls.initialize(app)
        val engine = FlutterEngine(app)
        channels = ContextChannels(app, engine)
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        return engine
    }

    /** 在界面里打开保活时，直接接管界面正在用的引擎和通道。 */
    fun adopt(engine: FlutterEngine, owned: ContextChannels) {
        if (cached() != null) return
        channels = owned
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }

    fun wake() {
        channels?.keepAlive?.sendWake()
    }
}
