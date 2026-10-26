package com.example.chatmate

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    // FCM falls back to this channel when a push does not name one, which is
    // what keep the notification quiet and grouped like a chat app.
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            "chatmate_messages",
            "ChatMate messages",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Chat requests and new messages in your rooms."
            enableVibration(true)
        }
        getSystemService(NotificationManager::class.java)
            ?.createNotificationChannel(channel)
    }
}
