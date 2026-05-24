package com.brcm.rpi4.alesqgc.autostart;

import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

public final class BootReceiver extends BroadcastReceiver {
    private static final String TAG = "ALESQGCAutostart";
    private static final ComponentName ALES_QGC_ACTIVITY = new ComponentName(
            "org.Agosdyne.alesqgc",
            "org.mavlink.qgroundcontrol.QGCActivity");

    @Override
    public void onReceive(Context context, Intent intent) {
        final String action = intent != null ? intent.getAction() : null;
        if (!Intent.ACTION_BOOT_COMPLETED.equals(action)
                && !Intent.ACTION_LOCKED_BOOT_COMPLETED.equals(action)) {
            return;
        }

        final Context appContext = context.getApplicationContext();
        new Handler(Looper.getMainLooper()).postDelayed(() -> launchAlesQgc(appContext), 5000);
    }

    private static void launchAlesQgc(Context context) {
        Intent launchIntent = new Intent(Intent.ACTION_MAIN)
                .setComponent(ALES_QGC_ACTIVITY)
                .addCategory(Intent.CATEGORY_LAUNCHER)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                        | Intent.FLAG_ACTIVITY_CLEAR_TOP
                        | Intent.FLAG_ACTIVITY_SINGLE_TOP);

        try {
            context.startActivity(launchIntent);
            Log.i(TAG, "Started ALES QGroundControl after boot");
        } catch (RuntimeException e) {
            Log.e(TAG, "Failed to start ALES QGroundControl", e);
        }
    }
}
