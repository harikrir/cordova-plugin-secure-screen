package com.yourplugin.securescreen;

import android.app.Activity;

import android.content.Context;

import android.graphics.Color;

import android.hardware.display.DisplayManager;

import android.os.Build;

import android.os.Handler;

import android.os.Looper;

import android.view.Display;

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

    private boolean isScreenshotProtected = false;             // Specific screens

    private boolean isScreenRecordingProtectionEnabled = false;  // Global recording block allowed?

    private boolean isScreenRecordingDetected = false;           // Is a recording active?

    private DisplayManager.DisplayListener displayListener;

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

                setupScreenRecordingDetection(); // Start listening

                updateSecurityFlags(activity);

                callbackContext.success();

                return true;

            case "disableScreenRecordingProtection":

                isScreenRecordingProtectionEnabled = false;

                teardownScreenRecordingDetection(); // Stop listening

                updateSecurityFlags(activity);

                callbackContext.success();

                return true;

            case "registerScreenshotListener":

                screenshotCallbackContext = callbackContext;

                // Android 14+ native screenshot detection API

                if (Build.VERSION.SDK_INT >= 34) {

                    activity.runOnUiThread(() -> {

                        activity.registerScreenCaptureCallback(

                            activity.getMainExecutor(),

                            () -> {

                                if (screenshotCallbackContext != null) {

                                    PluginResult result = new PluginResult(PluginResult.Status.OK, "screenshot_taken");

                                    result.setKeepCallback(true); // Keep callback alive for multiple screenshots

                                    screenshotCallbackContext.sendPluginResult(result);

                                }

                            }

                        );

                    });

                }

                // Return NO_RESULT immediately but keep the callback open

                PluginResult pluginResult = new PluginResult(PluginResult.Status.NO_RESULT);

                pluginResult.setKeepCallback(true);

                callbackContext.sendPluginResult(pluginResult);

                return true;

            default:

                return false;

        }

    }

    /**

     * Resolves the final state of FLAG_SECURE based on both features.

     */

    private void updateSecurityFlags(Activity activity) {

        if (activity == null) return;

        activity.runOnUiThread(() -> {

            boolean shouldSecure = isScreenshotProtected || (isScreenRecordingProtectionEnabled && isScreenRecordingDetected);

            if (shouldSecure) {

                activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);

            } else {

                activity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SECURE);

            }

        });

    }

    /**

     * Starts listening for virtual displays (screen recording/casting).

     */

    private void setupScreenRecordingDetection() {

        if (displayListener != null) {

            return; // Already listening

        }

        Activity activity = cordova.getActivity();

        if (activity == null) return;

        DisplayManager displayManager = (DisplayManager) activity.getSystemService(Context.DISPLAY_SERVICE);

        displayListener = new DisplayManager.DisplayListener() {

            @Override

            public void onDisplayAdded(int displayId) { checkDisplays(displayManager); }

            @Override

            public void onDisplayRemoved(int displayId) { checkDisplays(displayManager); }

            @Override

            public void onDisplayChanged(int displayId) { checkDisplays(displayManager); }

        };

        displayManager.registerDisplayListener(displayListener, new Handler(Looper.getMainLooper()));

        checkDisplays(displayManager); // Check immediately in case they are already recording

    }

    /**

     * Stops listening for virtual displays to save resources.

     */

    private void teardownScreenRecordingDetection() {

        Activity activity = cordova.getActivity();

        if (activity != null && displayListener != null) {

            DisplayManager displayManager = (DisplayManager) activity.getSystemService(Context.DISPLAY_SERVICE);

            displayManager.unregisterDisplayListener(displayListener);

            displayListener = null;

        }

        // Reset the detection state when disabled

        isScreenRecordingDetected = false; 

    }

    private void checkDisplays(DisplayManager displayManager) {

        Activity activity = cordova.getActivity();

        if (activity == null) return;

        boolean recordingDetected = false;

        Display[] displays = displayManager.getDisplays();

        for (Display display : displays) {

            if (display.getDisplayId() != Display.DEFAULT_DISPLAY) {

                recordingDetected = true;

                break;

            }

        }

        if (isScreenRecordingDetected != recordingDetected) {

            isScreenRecordingDetected = recordingDetected;

            updateSecurityFlags(activity);

        }

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

    @Override

    public void onDestroy() {

        super.onDestroy();

        // Ensure we clean up listeners if the app is force closed

        teardownScreenRecordingDetection();

    }

}
 
