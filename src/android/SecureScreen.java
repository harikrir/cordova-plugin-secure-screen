package com.yourplugin.securescreen;

import android.app.Activity;

import android.graphics.Color;

import android.os.Build;

import android.view.View;

import android.view.WindowManager;

import android.widget.FrameLayout;

import org.apache.cordova.CallbackContext;

import org.apache.cordova.CordovaPlugin;

import org.apache.cordova.PluginResult;

import org.json.JSONArray;

public class SecureScreen extends CordovaPlugin {

    private View overlayView;

    private boolean blurEnabled = false;

    // State Tracking

    private boolean isScreenshotProtected = false;

    private boolean isScreenRecordingProtectionEnabled = false; 

    private CallbackContext screenshotCallbackContext;

    @Override

    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) {

        Activity activity = cordova.getActivity();

        switch (action) {

            case "enableScreenshotProtection":

                isScreenshotProtected = true;

                updateSecurityFlags(activity);

                callbackContext.success();

                return true;

            case "disableScreenshotProtection":

                isScreenshotProtected = false;

                updateSecurityFlags(activity);

                callbackContext.success();

                return true;

            case "enableAppSwitcherBlur":

                blurEnabled = true;

                activity.runOnUiThread(() -> createOverlay(activity));

                callbackContext.success();

                return true;

            case "disableAppSwitcherBlur":

                blurEnabled = false;

                activity.runOnUiThread(this::removeOverlay);

                callbackContext.success();

                return true;

            case "enableScreenRecordingProtection":

                isScreenRecordingProtectionEnabled = true;

                updateSecurityFlags(activity);

                callbackContext.success();

                return true;

            case "disableScreenRecordingProtection":

                isScreenRecordingProtectionEnabled = false;

                updateSecurityFlags(activity);

                callbackContext.success();

                return true;

            case "registerScreenshotListener":

                screenshotCallbackContext = callbackContext;

                if (Build.VERSION.SDK_INT >= 34) {

                    activity.runOnUiThread(() -> {

                        activity.registerScreenCaptureCallback(

                            activity.getMainExecutor(),

                            () -> {

                                if (screenshotCallbackContext != null) {

                                    PluginResult result = new PluginResult(PluginResult.Status.OK, "screenshot_taken");

                                    result.setKeepCallback(true); 

                                    screenshotCallbackContext.sendPluginResult(result);

                                }

                            }

                        );

                    });

                }

                PluginResult pluginResult = new PluginResult(PluginResult.Status.NO_RESULT);

                pluginResult.setKeepCallback(true);

                callbackContext.sendPluginResult(pluginResult);

                return true;

            default:

                return false;

        }

    }

    private void updateSecurityFlags(Activity activity) {

        if (activity == null) return;

        activity.runOnUiThread(() -> {

            // If EITHER screenshot OR recording protection is enabled, we MUST apply FLAG_SECURE.

            boolean shouldSecure = isScreenshotProtected || isScreenRecordingProtectionEnabled;

            if (shouldSecure) {

                activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);

            } else {

                activity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SECURE);

            }

        });

    }

    private void createOverlay(Activity activity) {

        if (overlayView != null) return;

        overlayView = new View(activity);

        overlayView.setBackgroundColor(Color.WHITE);

        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(

                FrameLayout.LayoutParams.MATCH_PARENT,

                FrameLayout.LayoutParams.MATCH_PARENT

        );

        activity.addContentView(overlayView, params);

        overlayView.setVisibility(View.GONE);

    }

    private void removeOverlay() {

        if (overlayView != null && overlayView.getParent() instanceof FrameLayout) {

            ((FrameLayout) overlayView.getParent()).removeView(overlayView);

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
 
