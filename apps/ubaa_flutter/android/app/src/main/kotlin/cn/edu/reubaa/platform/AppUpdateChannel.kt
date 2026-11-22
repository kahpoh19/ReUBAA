package cn.edu.reubaa.platform

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** 应用内更新：Dart 下载好 APK 后，这里交给系统安装器。 */
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
                "install" -> {
                    val file = File(requireNotNull(call.arguments<String>()))
                    val uri = FileProvider.getUriForFile(context, "${context.packageName}.diagnostic-reports", file)
                    val intent = Intent(Intent.ACTION_VIEW)
                        .setDataAndType(uri, "application/vnd.android.package-archive")
                        .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun dispose() = channel.setMethodCallHandler(null)
}
