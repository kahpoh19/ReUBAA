package cn.edu.ubaa.ubaa_flutter.reminders

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Dart 的 ChannelNotificationGateway 对应的原生端。 */
class NotificationsChannel(
    private val context: Context,
    messenger: BinaryMessenger,
    private val activity: () -> Activity?,
) {
    private val channel = MethodChannel(messenger, "cn.edu.buaa.ubaa/notifications")
    private var pendingPermission: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> requestPermission(result)
                "replace" -> {
                    val group = call.argument<String>("group")
                    val items = call.argument<List<*>>("items")
                    if (group == null || items == null) {
                        result.error("invalid_reminders", "提醒参数无效", null)
                    } else {
                        Reminders.replace(context, group, Reminders.parse(items))
                        result.success(null)
                    }
                }
                "show" -> {
                    val id = call.argument<Int>("id")
                    val title = call.argument<String>("title")
                    if (id == null || title == null) {
                        result.error("invalid_notification", "通知参数无效", null)
                    } else {
                        Reminders.show(context, id, title, call.argument<String>("body") ?: "")
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun granted() = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
        context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    // Android 13 起通知要运行时权限；后台没有界面时只返回当前状态。
    private fun requestPermission(result: MethodChannel.Result) {
        val host = activity()
        if (granted() || host == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(granted())
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        host.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST)
    }

    /** MainActivity 收到权限结果后转进来，不是这里的请求返回 false。 */
    fun onPermissionResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST) return false
        pendingPermission?.success(granted())
        pendingPermission = null
        return true
    }

    fun dispose() {
        pendingPermission?.success(false)
        pendingPermission = null
        channel.setMethodCallHandler(null)
    }

    companion object {
        private const val REQUEST = 4107
    }
}
