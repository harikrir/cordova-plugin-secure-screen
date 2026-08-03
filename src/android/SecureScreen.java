package com.yourplugin.securescreen;

import android.app.Activity;
import android.graphics.Color;
import android.view.View;
import android.view.WindowManager;
import android.widget.FrameLayout;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.json.JSONArray;

public class SecureScreen extends CordovaPlugin {

    private View overlayView;
    private boolean blurEnabled = false;

    @Override
    public boolean execute(
            String action,
            JSONArray args,
            CallbackContext callbackContext) {

        Activity activity = cordova.getActivity();

        switch (action) {

            case "enableScreenshotProtection":

                activity.runOnUiThread(() ->
                        activity.getWindow().addFlags(
                                WindowManager.LayoutParams.FLAG_SECURE));

                callbackContext.success();
                return true;

            case "disableScreenshotProtection":

                activity.runOnUiThread(() ->
                        activity.getWindow().clearFlags(
                                WindowManager.LayoutParams.FLAG_SECURE));

                callbackContext.success();
                return true;

            case "enableAppSwitcherBlur":

                blurEnabled = true;
                createOverlay(activity);

                callbackContext.success();
                return true;

            case "disableAppSwitcherBlur":

                blurEnabled = false;
                removeOverlay();

                callbackContext.success();
                return true;

            default:
                return false;
        }
    }

    private void createOverlay(Activity activity) {

        if (overlayView != null) {
            return;
        }

        overlayView = new View(activity);
        overlayView.setBackgroundColor(Color.WHITE);

        FrameLayout.LayoutParams params =
                new FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.MATCH_PARENT
                );

        activity.addContentView(overlayView, params);

        overlayView.setVisibility(View.GONE);
    }

    private void removeOverlay() {

        if (overlayView != null
                && overlayView.getParent() instanceof FrameLayout) {

            ((FrameLayout) overlayView.getParent())
                    .removeView(overlayView);

            overlayView = null;
        }
    }

    @Override
    public void onPause(boolean multitasking) {

        if (blurEnabled && overlayView != null) {
            overlayView.setVisibility(View.VISIBLE);
        }
    }

    @Override
    public void onResume(boolean multitasking) {

        if (overlayView != null) {
            overlayView.setVisibility(View.GONE);
        }
    }
}
