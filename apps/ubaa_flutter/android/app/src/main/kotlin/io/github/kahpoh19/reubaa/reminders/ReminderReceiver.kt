package io.github.kahpoh19.reubaa.reminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** 闹钟到点后弹出提醒。 */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val group = intent.getStringExtra(Reminders.EXTRA_GROUP) ?: return
        val id = intent.getIntExtra(Reminders.EXTRA_ID, 0)
        val title = intent.getStringExtra(Reminders.EXTRA_TITLE) ?: return
        val body = intent.getStringExtra(Reminders.EXTRA_BODY) ?: ""
        Reminders.show(context, id, title, body)
        Reminders.forget(context, group, id)
    }
}
