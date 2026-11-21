package io.github.kahpoh19.reubaa

import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.github.kahpoh19.reubaa.background.EngineHolder
import io.github.kahpoh19.reubaa.background.KeepAlive
import io.github.kahpoh19.reubaa.platform.AgendaFileChannel

class MainActivity : FlutterActivity() {
    // 没开后台保活时界面自己持有通道；开了以后交给 EngineHolder，界面关掉也不注销。
    private var channels: ContextChannels? = null
    private var agendaFiles: AgendaFileChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        EngineHolder.activity = this
        super.onCreate(savedInstanceState)
    }

    // 后台服务已经起了引擎就直接接上；开着保活但还没起时由这里起一份托管引擎。
    override fun provideFlutterEngine(context: Context): FlutterEngine? =
        EngineHolder.cached() ?: if (KeepAlive.enabled(context)) EngineHolder.ensure(context) else null

    // 托管的引擎在界面关掉后要继续跑。
    override fun shouldDestroyEngineWithHost(): Boolean {
        val engine = flutterEngine
        return engine == null || engine !== EngineHolder.cached()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        NativeTls.initialize(applicationContext)
        super.configureFlutterEngine(flutterEngine)
        if (flutterEngine !== EngineHolder.cached()) {
            channels = ContextChannels(applicationContext, flutterEngine)
        }
        agendaFiles = AgendaFileChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        if (agendaFiles?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        val owner = channels ?: EngineHolder.channels()
        if (owner?.notifications?.onPermissionResult(requestCode) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onDestroy() {
        agendaFiles?.dispose()
        agendaFiles = null
        channels?.let { if (!EngineHolder.owns(it)) it.dispose() }
        channels = null
        if (EngineHolder.activity === this) EngineHolder.activity = null
        super.onDestroy()
    }
}
