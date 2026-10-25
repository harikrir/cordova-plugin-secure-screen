package com.yourplugin.securescreen;

import android.app.Activity;

import android.graphics.Color;

import android.os.Build;

import android.util.Log;

import android.view.View;

import android.view.WindowManager;

import android.widget.FrameLayout;

import org.apache.cordova.CallbackContext;

import org.apache.cordova.CordovaPlugin;

import org.apache.cordova.PluginResult;

import org.json.JSONArray;

public class SecureScreen extends CordovaPlugin {

    private static final String TAG = "SecureScreen";

    private View overlayView;

    private FrameLayout rootView;

    private boolean blurEnabled = false;

    private boolean isScreenshotProtected = false;

    private boolean isScreenRecordingProtectionEnabled = false;

    private boolean screenshotCallbackRegistered = false;

    private CallbackContext screenshotCallbackContext;

    @Override

    public boolean execute(

            String action,

            JSONArray args,

            CallbackContext callbackContext) {

        final Activity activity = cordova.getActivity();

        if (activity == null) {

            callbackContext.error("Activity is unavailable");

            return true;

        }

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

            case "enableAppSwitcherBlur":

                blurEnabled = true;

                activity.runOnUiThread(() -> {

                    if (Build.VERSION.SDK_INT >= 33) {

                        // Protect the Recents preview only.

                        // Normal foreground screenshots remain allowed.

                        activity.setRecentsScreenshotEnabled(false);

                        removeOverlay();

                    } else {

                        // Best-effort fallback for Android 12 and below.

                        createOverlay(activity);

                    }

                });

                callbackContext.success();

                return true;

            case "disableAppSwitcherBlur":

                blurEnabled = false;

                activity.runOnUiThread(() -> {

                    if (Build.VERSION.SDK_INT >= 33) {

                        activity.setRecentsScreenshotEnabled(true);

                    }

                    removeOverlay();

                });

                callbackContext.success();

                return true;

            case "registerScreenshotListener":

                registerScreenshotListener(

                        activity, callbackContext);

                return true;

            default:

                return false;

        }

    }

    private void updateSecurityFlags(Activity activity) {

        activity.runOnUiThread(() -> {

            boolean shouldSecure =

                    isScreenshotProtected

                    || isScreenRecordingProtectionEnabled;

            if (shouldSecure) {

                activity.getWindow().addFlags(

                        WindowManager.LayoutParams.FLAG_SECURE);

            } else {

                activity.getWindow().clearFlags(

                        WindowManager.LayoutParams.FLAG_SECURE);

            }

        });

    }

    private void createOverlay(Activity activity) {

        if (!blurEnabled || Build.VERSION.SDK_INT >= 33) {

            return;

        }

        if (overlayView != null
&& overlayView.getParent() != null) {

            return;

        }

        rootView = activity.findViewById(android.R.id.content);

        if (rootView == null) {

            Log.e(TAG, "Root content view unavailable");

            return;

        }

        overlayView = new View(activity);

        overlayView.setBackgroundColor(Color.WHITE);

        overlayView.setClickable(false);

        overlayView.setFocusable(false);

        overlayView.setImportantForAccessibility(

                View.IMPORTANT_FOR_ACCESSIBILITY_NO);

        FrameLayout.LayoutParams params =

                new FrameLayout.LayoutParams(

                        FrameLayout.LayoutParams.MATCH_PARENT,

                        FrameLayout.LayoutParams.MATCH_PARENT);

        rootView.addView(overlayView, params);

        overlayView.setVisibility(View.GONE);

        Log.d(TAG, "Privacy overlay created");

    }

    private void showOverlay() {

        if (!blurEnabled

                || Build.VERSION.SDK_INT >= 33

                || overlayView == null) {

            return;

        }

        overlayView.setVisibility(View.VISIBLE);

        overlayView.bringToFront();

        Log.d(TAG, "Privacy overlay shown");

    }

    private void hideOverlay() {

        if (overlayView != null) {

            overlayView.setVisibility(View.GONE);

            Log.d(TAG, "Privacy overlay hidden");

        }

    }

    private void removeOverlay() {

        if (overlayView != null
&& overlayView.getParent() instanceof FrameLayout) {

            ((FrameLayout) overlayView.getParent())

                    .removeView(overlayView);

        }

        overlayView = null;

        rootView = null;

    }

    private void registerScreenshotListener(

            Activity activity,

            CallbackContext callbackContext) {

        screenshotCallbackContext = callbackContext;

        if (Build.VERSION.SDK_INT >= 34
&& !screenshotCallbackRegistered) {

            activity.runOnUiThread(() -> {

                if (screenshotCallbackRegistered) {

                    return;

                }

                try {

                    activity.registerScreenCaptureCallback(

                            activity.getMainExecutor(),

                            () -> {

                                CallbackContext current =

                                        screenshotCallbackContext;

                                if (current != null) {

                                    PluginResult result =

                                            new PluginResult(

                                                    PluginResult.Status.OK,

                                                    "screenshot_taken");

                                    result.setKeepCallback(true);

                                    current.sendPluginResult(result);

                                }

                            });

                    screenshotCallbackRegistered = true;

                } catch (Exception e) {

                    Log.e(TAG,

                            "Screenshot callback registration failed",

                            e);

                }

            });

        }

        PluginResult result = new PluginResult(

                PluginResult.Status.NO_RESULT);

        result.setKeepCallback(true);

        callbackContext.sendPluginResult(result);

    }

    @Override

    public void onPause(boolean multitasking) {

        super.onPause(multitasking);

        Log.d(TAG, "onPause");

        showOverlay();

    }

    @Override

    public void onStop() {

        super.onStop();

        Log.d(TAG, "onStop");

        showOverlay();

    }

    @Override

    public void onResume(boolean multitasking) {

        super.onResume(multitasking);

        Log.d(TAG, "onResume");

        hideOverlay();

    }

    @Override

    public void onDestroy() {

        Activity activity = cordova.getActivity();

        if (activity != null) {

            if (Build.VERSION.SDK_INT >= 33 && blurEnabled) {

                activity.setRecentsScreenshotEnabled(true);

            }

            if (Build.VERSION.SDK_INT >= 34
&& screenshotCallbackRegistered) {

                try {

                    activity.unregisterScreenCaptureCallback(

                            activity.getMainExecutor(),

                            screenshotCaptureCallback);

                } catch (Exception e) {

                    Log.w(TAG,

                            "Could not unregister screenshot callback",

                            e);

                }

            }

        }

        screenshotCallbackRegistered = false;

        screenshotCallbackContext = null;

        removeOverlay();

        super.onDestroy();

    }

    private final Activity.ScreenCaptureCallback

            screenshotCaptureCallback = () -> {

        CallbackContext current = screenshotCallbackContext;

        if (current != null) {

            PluginResult result = new PluginResult(

                    PluginResult.Status.OK,

                    "screenshot_taken");

            result.setKeepCallback(true);

            current.sendPluginResult(result);

        }

    };

}
 
