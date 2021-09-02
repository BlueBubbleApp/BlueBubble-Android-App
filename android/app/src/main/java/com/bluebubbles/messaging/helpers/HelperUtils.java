package com.bluebubbles.messaging.helpers;

import android.app.Notification;
import android.app.NotificationManager;
import android.content.Context;
import android.service.notification.StatusBarNotification;
import androidx.core.app.NotificationManagerCompat;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffXfermode;
import android.graphics.Rect;
import android.graphics.RectF;

import android.util.Log;

import java.sql.Timestamp;
import java.util.Map;

public class HelperUtils {
    public static String TAG = "HelperUtils";

    public static Object parseField(Map<String, Object> json, String field, String intendedType) {
        // Handle cases where we want to return null
        if (!json.containsKey(field) || json.get(field) == null) {
            if (intendedType.equals("boolean")) return false;  // If null, let's assume false
            return null;
        }

        String stringVal = String.valueOf(json.get(field));
        if (stringVal.equals("null")) {
            if (intendedType.equals("boolean")) return false;  // If null, let's assume false
            return null;
        }

        switch (intendedType) {
            case "integer":
                return Integer.valueOf(stringVal);
            case "long":
                return Long.valueOf(stringVal);
            case "boolean":
                return Boolean.valueOf(stringVal);
            case "timestamp":
                return new Timestamp(Long.valueOf(stringVal));
            default:
                return stringVal;
        }
    }

    public static Bitmap getCircleBitmap(Bitmap bitmap) {
        final Bitmap output = Bitmap.createBitmap(bitmap.getWidth(),
                bitmap.getHeight(), Bitmap.Config.ARGB_8888);
        final Canvas canvas = new Canvas(output);

        final int color = Color.RED;
        final Paint paint = new Paint();
        final Rect rect = new Rect(0, 0, bitmap.getWidth(), bitmap.getHeight());
        final RectF rectF = new RectF(rect);

        paint.setAntiAlias(true);
        canvas.drawARGB(0, 0, 0, 0);
        paint.setColor(color);
        canvas.drawOval(rectF, paint);

        paint.setXfermode(new PorterDuffXfermode(PorterDuff.Mode.SRC_IN));
        canvas.drawBitmap(bitmap, rect, rect, paint);

        bitmap.recycle();

        return output;
    }

    public static void tryCancelNotificationSummary(Context context) {
        Log.d(HelperUtils.TAG, "Attempting to cancel notification summary...");
        NotificationManagerCompat notificationManager = NotificationManagerCompat.from(context);
        NotificationManager manager = (NotificationManager) context.getSystemService(context.NOTIFICATION_SERVICE);
        StatusBarNotification[] notifications = manager.getActiveNotifications();

        // If there are no more notifications (only the group is left). Clear the group
        Log.d(HelperUtils.TAG, "Notification Count: " + notifications.length);
        if (notifications.length <= 0 || (notifications.length == 1 && notifications[0].getId() == -1)) {
            Log.d(HelperUtils.TAG, "Cancelling the notification summary...");

            // Using cancel all because it seems cancelling it by ID sometimes doesn't work
            notificationManager.cancelAll();
        }
    }
}