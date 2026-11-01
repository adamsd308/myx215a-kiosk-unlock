package org.myxunlock.navigation;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.SystemClock;

public final class BootReceiver extends BroadcastReceiver {
    private static final String RESTORE = "org.myxunlock.navigation.RESTORE";

    static void showNavigation(Context context) {
        Intent intent = new Intent("android.intent.action.SHOW_NAVIGATION_BAR");
        intent.setPackage("com.android.systemui");
        intent.addFlags(Intent.FLAG_RECEIVER_FOREGROUND);
        context.sendBroadcast(intent);
    }

    @Override public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();
        if (!Intent.ACTION_BOOT_COMPLETED.equals(action) && !RESTORE.equals(action)) return;
        showNavigation(context);
        if (Intent.ACTION_BOOT_COMPLETED.equals(action)) {
            // Retry once in case the vendor UI was still initializing at boot completion.
            AlarmManager alarms = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            Intent retry = new Intent(context, BootReceiver.class).setAction(RESTORE);
            PendingIntent pending = PendingIntent.getBroadcast(context, 1, retry,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
            alarms.set(AlarmManager.ELAPSED_REALTIME, SystemClock.elapsedRealtime() + 15000, pending);
        }
    }
}
