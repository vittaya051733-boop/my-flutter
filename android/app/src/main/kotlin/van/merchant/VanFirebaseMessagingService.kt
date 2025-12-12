package van.merchant

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.media.RingtoneManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

class VanFirebaseMessagingService : FlutterFirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        when (data["type"]) {
            "call" -> showIncomingCallNotification(data)
            "call_cancel" -> dismissIncomingCall(data)
        }
        // ส่งต่อให้ plugin จัดการ notification/chat อื่น ๆ (เช่น FCM -> Dart)
        super.onMessageReceived(message)
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
    }

    private fun showIncomingCallNotification(data: Map<String, String>) {
        val channelId = data["channelId"] ?: return
        val token = data["token"] ?: return
        val callerName = data["callerName"] ?: "ผู้โทร"
        val callerId = data["callerId"] ?: data["caller_id"]
        val callerPhoto = data["callerPhotoUrl"]
        val isVideo = data["callType"] == "video" || data["isVideo"].equals("true", true)

        val intent = MainActivityIntentBuilder.build(
            context = this,
            channelId = channelId,
            token = token,
            callerId = callerId,
            callerName = callerName,
            callerPhoto = callerPhoto,
            isVideo = isVideo
        )

        val pendingIntent = PendingIntent.getActivity(
            this,
            REQUEST_CODE_INCOMING_CALL,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(notificationManager)

        val notification = NotificationCompat.Builder(this, CALL_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle(if (isVideo) "สายวิดีโอคอลเข้า" else "สายเข้าจาก $callerName")
            .setContentText("แตะเพื่อรับสาย")
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setOngoing(true)
            .setAutoCancel(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(pendingIntent, true)
            .setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE))
            .setContentIntent(pendingIntent)
            .setTimeoutAfter(60000)
            .build()

        notificationManager.notify(NOTIFICATION_ID_INCOMING_CALL, notification)
        CallIntentRouter.deliverIntent(intent)
        try {
            startActivity(intent)
        } catch (error: Exception) {
            Log.w(TAG, "Unable to start call UI", error)
        }
    }

    private fun dismissIncomingCall(data: Map<String, String>) {
        val channelId = data["channelId"] ?: return
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFICATION_ID_INCOMING_CALL)
        sendCancelIntent(channelId)
    }

    private fun ensureChannel(notificationManager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CALL_CHANNEL_ID,
            "Incoming Calls",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Full-screen notifications for incoming calls"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        notificationManager.createNotificationChannel(channel)
    }

    companion object {
        private const val CALL_CHANNEL_ID = "call_channel"
        private const val REQUEST_CODE_INCOMING_CALL = 3182
        private const val NOTIFICATION_ID_INCOMING_CALL = 2387
        private const val TAG = "VanFcmService"
    }
}

private object MainActivityIntentBuilder {
    fun build(
        context: Context,
        channelId: String,
        token: String,
        callerId: String?,
        callerName: String,
        callerPhoto: String?,
        isVideo: Boolean
    ) = android.content.Intent(context, MainActivity::class.java).apply {
        action = MainActivity.ACTION_SHOW_INCOMING_CALL
        flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or
            android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP or
            android.content.Intent.FLAG_ACTIVITY_SINGLE_TOP
        putExtra(MainActivity.EXTRA_CHANNEL_ID, channelId)
        putExtra(MainActivity.EXTRA_CALL_TOKEN, token)
        putExtra(MainActivity.EXTRA_CALLER_ID, callerId.orEmpty())
        putExtra(MainActivity.EXTRA_CALLER_NAME, callerName)
        putExtra(MainActivity.EXTRA_CALLER_PHOTO, callerPhoto)
        putExtra(MainActivity.EXTRA_IS_VIDEO, isVideo)
        putExtra(MainActivity.EXTRA_APP_WAS_FOREGROUND, VanMerchantApp.isAppInForeground())
    }

    fun cancelIntent(context: Context, channelId: String) = android.content.Intent(context, MainActivity::class.java).apply {
        action = MainActivity.ACTION_CANCEL_INCOMING_CALL
        flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or
            android.content.Intent.FLAG_ACTIVITY_SINGLE_TOP
        putExtra(MainActivity.EXTRA_CHANNEL_ID, channelId)
    }
}

private fun VanFirebaseMessagingService.sendCancelIntent(channelId: String) {
    val intent = MainActivityIntentBuilder.cancelIntent(this, channelId)
    CallIntentRouter.deliverIntent(intent)
}
