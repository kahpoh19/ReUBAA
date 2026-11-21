package cn.edu.reubaa.reminders

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import cn.edu.reubaa.R
import org.json.JSONArray
import org.json.JSONObject

/** Dart 排好的一条提醒，[at] 是毫秒时间戳。 */
data class ReminderItem(val id: Int, val title: String, val body: String, val at: Long)

/**
 * 提醒的本地存档和闹钟调度。
 *
 * 提醒交给 AlarmManager，应用被杀也会弹；存档用来开机后重排和整组撤销。
 */
object Reminders {
    private const val PREFS = "ubaa_reminders"
    private const val ACTION = "cn.edu.reubaa.REMINDER"
    const val CHANNEL_ID = "reminders"
    const val EXTRA_GROUP = "group"
    const val EXTRA_ID = "id"
    const val EXTRA_TITLE = "title"
    const val EXTRA_BODY = "body"

    /** 整组替换：先撤掉旧闹钟，再按新列表重排。 */
    fun replace(context: Context, group: String, items: List<ReminderItem>) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        load(prefs.getString(group, null)).forEach { cancel(context, group, it) }
        val now = System.currentTimeMillis()
        val future = items.filter { it.at > now }
        prefs.edit().putString(group, encode(future)).apply()
        future.forEach { schedule(context, group, it) }
    }

    /** 开机、改时间或应用更新后闹钟会丢，按存档重排一遍。 */
    fun rescheduleAll(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        for (group in prefs.all.keys) {
            replace(context, group, load(prefs.getString(group, null)))
        }
    }

    /** 弹完的提醒从存档里删掉，免得开机又弹一次。 */
    fun forget(context: Context, group: String, id: Int) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val rest = load(prefs.getString(group, null)).filter { it.id != id }
        prefs.edit().putString(group, encode(rest)).apply()
    }

    fun show(context: Context, id: Int, title: String, body: String) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        ensureChannel(manager)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context).setPriority(Notification.PRIORITY_HIGH)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_reminder)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(openApp(context))
            .build()
        // 没有通知权限时系统直接丢弃，不会抛异常。
        manager.notify(id, notification)
    }

    fun openApp(context: Context): PendingIntent? {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return null
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(
            context,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun ensureChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(CHANNEL_ID, "课程与待办提醒", NotificationManager.IMPORTANCE_HIGH)
        channel.description = "上课前和待办截止前的提醒"
        manager.createNotificationChannel(channel)
    }

    private fun schedule(context: Context, group: String, item: ReminderItem) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        val intent = alarmIntent(context, group, item)
            .putExtra(EXTRA_TITLE, item.title)
            .putExtra(EXTRA_BODY, item.body)
        val pending = PendingIntent.getBroadcast(
            context,
            item.id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        // 精确闹钟权限被用户关掉时退回不精确闹钟，最多晚几分钟。
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarms.canScheduleExactAlarms()) {
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, item.at, pending)
        } else {
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, item.at, pending)
        }
    }

    private fun cancel(context: Context, group: String, item: ReminderItem) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        val pending = PendingIntent.getBroadcast(
            context,
            item.id,
            alarmIntent(context, group, item),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        ) ?: return
        alarms.cancel(pending)
        pending.cancel()
    }

    // data 带上分组和编号，不同提醒的 PendingIntent 不会互相覆盖。
    private fun alarmIntent(context: Context, group: String, item: ReminderItem) =
        Intent(context, ReminderReceiver::class.java)
            .setAction(ACTION)
            .setData(Uri.parse("ubaa-reminder://$group/${item.id}"))
            .putExtra(EXTRA_GROUP, group)
            .putExtra(EXTRA_ID, item.id)

    fun parse(raw: List<*>): List<ReminderItem> = raw.mapNotNull { value ->
        val map = value as? Map<*, *> ?: return@mapNotNull null
        val id = (map["id"] as? Number)?.toInt() ?: return@mapNotNull null
        val title = map["title"] as? String ?: return@mapNotNull null
        val body = map["body"] as? String ?: return@mapNotNull null
        val at = (map["at"] as? Number)?.toLong() ?: return@mapNotNull null
        ReminderItem(id, title, body, at)
    }

    private fun encode(items: List<ReminderItem>): String {
        val array = JSONArray()
        for (item in items) {
            array.put(
                JSONObject()
                    .put("id", item.id)
                    .put("title", item.title)
                    .put("body", item.body)
                    .put("at", item.at),
            )
        }
        return array.toString()
    }

    private fun load(raw: String?): List<ReminderItem> {
        if (raw == null) return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).map { index ->
                val item = array.getJSONObject(index)
                ReminderItem(item.getInt("id"), item.getString("title"), item.getString("body"), item.getLong("at"))
            }
        } catch (_: Exception) {
            emptyList()
        }
    }
}
