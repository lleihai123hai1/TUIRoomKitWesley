package com.tencent.qcloud.tuicore.util;

import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.View;
import android.widget.TextView;
import android.widget.Toast;

import com.tencent.qcloud.tuicore.ServiceInitializer;

public class ToastUtil {

    private final static Handler handler = new Handler(Looper.getMainLooper());

    public static void toastLongMessage(final String message) {
        toastMessage(message, true);
    }

    public static void toastShortMessage(final String message) {
        toastMessage(message, false);
    }

    private static void toastMessage(final String message, boolean isLong) {
        handler.post(new Runnable() {
            @Override
            public void run() {
                Toast toast = Toast.makeText(ServiceInitializer.getAppContext(), message,
                        isLong ? Toast.LENGTH_LONG : Toast.LENGTH_SHORT);
                View view = toast.getView();
                if (view != null) {
                    TextView textView = view.findViewById(android.R.id.message);
                    if (textView != null) {
                        textView.setGravity(Gravity.CENTER);
                    }
                }
                toast.show();
            }
        });
    }
}
