package cn.edu.reubaa.platform

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * 应用内更新：Dart 下载好 APK 后，这里用 PackageInstaller 安装。
 *
 * 安卓 12 起声明不需要用户操作，更新自己时系统直接安装，装好后结束当前进程；
 * 系统仍要求确认时（旧系统、部分厂商系统）弹出系统的确认框。
 */
class AppUpdateChannel(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "cn.edu.buaa.ubaa/app-update")

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                // Release 里按架构分包，取系统首选的那个。
                "abi" -> result.success(Build.SUPPORTED_ABIS.firstOrNull())
                "directory" -> result.success(File(context.cacheDir, "updates").path)
                "canInstall" -> result.success(
                    Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                        context.packageManager.canRequestPackageInstalls()
                )
                "openInstallSettings" -> {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:${context.packageName}"),
                    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    result.success(null)
                }
                "install" -> install(File(requireNotNull(call.arguments<String>())), result)
                else -> result.notImplemented()
            }
        }
    }

    private fun install(file: File, result: MethodChannel.Result) {
        if (pending != null) {
            result.error("busy", "上一次安装还没结束", null)
            return
        }
        pending = result
        // 四十多兆的安装包写进会话要一会儿，放到后台线程。
        Thread {
            try {
                val installer = context.packageManager.packageInstaller
                val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
                params.setAppPackageName(context.packageName)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
                }
                val id = installer.createSession(params)
                installer.openSession(id).use { session ->
                    file.inputStream().use { input ->
                        session.openWrite("base.apk", 0, file.length()).use { output ->
                            input.copyTo(output)
                            session.fsync(output)
                        }
                    }
                    // 结果由系统广播给 AppUpdateReceiver，需要可变的 PendingIntent 才能带上状态。
                    val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                        (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
                    val callback = PendingIntent.getBroadcast(
                        context,
                        id,
                        Intent(context, AppUpdateReceiver::class.java),
                        flags,
                    )
                    session.commit(callback.intentSender)
                }
            } catch (error: Exception) {
                main.post { finish { it.error("install_failed", error.message, null) } }
            }
        }.start()
    }

    fun dispose() = channel.setMethodCallHandler(null)

    companion object {
        private val main = Handler(Looper.getMainLooper())

        /** 等待安装结果的那次调用；装好时进程会被结束，这次调用不会返回。 */
        private var pending: MethodChannel.Result? = null

        fun finish(reply: (MethodChannel.Result) -> Unit) {
            val result = pending ?: return
            pending = null
            reply(result)
        }
    }
}

/** 接收 PackageInstaller 的安装结果。 */
class AppUpdateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                val confirm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_INTENT)
                }
                if (confirm != null) {
                    context.startActivity(confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                }
                AppUpdateChannel.finish { it.success("confirm") }
            }
            PackageInstaller.STATUS_SUCCESS -> AppUpdateChannel.finish { it.success("done") }
            else -> {
                val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE) ?: "状态码 $status"
                AppUpdateChannel.finish { it.error("install_failed", message, null) }
            }
        }
    }
}
