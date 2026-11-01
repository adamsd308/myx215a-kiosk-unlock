package org.myxunlock.navigation;

import android.app.Activity;
import android.os.Bundle;
import android.widget.TextView;

public final class MainActivity extends Activity {
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        BootReceiver.showNavigation(this);
        TextView message = new TextView(this);
        message.setText("Navigation buttons enabled.\n\n"
            + "This helper also enables them automatically after startup.\n\n"
            + "You can return Home now. Uninstall this helper to remove the startup action.");
        message.setTextSize(22);
        int padding = (int) (32 * getResources().getDisplayMetrics().density);
        message.setPadding(padding, padding, padding, padding);
        setContentView(message);
    }
}
