package com.yourplugin.securescreen;

import android.app.Activity;

import android.graphics.Color;

import android.os.Build;

import android.util.Log;

import android.view.View;

import android.view.ViewTreeObserver;

import android.view.WindowManager;

import android.widget.FrameLayout;

import org.apache.cordova.CallbackContext;

import org.apache.cordova.CordovaInterface;

import org.apache.cordova.CordovaPlugin;

import org.apache.cordova.CordovaWebView;

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

    private ViewTreeObserver.OnWindowFocusChangeListener windowFocusListener;

    private final Activity.ScreenCaptureCallback screenshotCaptureCallback = () -> {

        CallbackContext callback = screenshotCallbackContext;

        if (callback != null) {

            PluginResult result = new PluginResult(PluginResult.Status.OK, "screenshot_taken");

            result.setKeepCallback(true);

            callback.sendPluginResult(result);

        }

    };

    @Override

    public void initialize(CordovaInterface cordova, CordovaWebView webView) {

        super.initialize(cordova, webView);

        final Activity activity = cordova.getActivity();

        if (activity != null) {

            activity.runOnUiThread(() -> {

                windowFocusListener = hasFocus -> handleFocusChange(activity, hasFocus);

                View decorView = activity.getWindow().getDecorView();

                if (decorView != null) {

                    decorView.getViewTreeObserver().addOnWindowFocusChangeListener(windowFocusListener);

                }

            });

        }

    }

    @Override

    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) {

        final Activity activity = cordova.getActivity();

        if (activity == null) {

            callbackContext.error("Activity unavailable");

            return true;

        }

        switch (action) {

            case "enableScreenshotProtection":

                isScreenshotProtected = true;

                applySecurityFlags(activity);

                callbackContext.success();

                return true;

            case "disableScreenshotProtection":

                isScreenshotProtected = false;

                applySecurityFlags(activity);

                callbackContext.success();

                return true;

            case "enableScreenRecordingProtection":

                isScreenRecordingProtectionEnabled = true;

                applySecurityFlags(activity);

                callbackContext.success();

                return true;

            case "disableScreenRecordingProtection":

                isScreenRecordingProtectionEnabled = false;

                applySecurityFlags(activity);

                callbackContext.success();

                return true;

            case "enableAppSwitcherBlur":

                blurEnabled = true;

                activity.runOnUiThread(() -> {

                    if (Build.VERSION.SDK_INT >= 33) {

                        try {

                            activity.setRecentsScreenshotEnabled(false);

                        } catch (Exception e) {

                            Log.w(TAG, "setRecentsScreenshotEnabled failed", e);

                        }

                    }

                    createOverlay(activity);

                });

                callbackContext.success();

                return true;

            case "disableAppSwitcherBlur":

                blurEnabled = false;

                activity.runOnUiThread(() -> {

                    if (Build.VERSION.SDK_INT >= 33) {

                        try {

                            activity.setRecentsScreenshotEnabled(true);

                        } catch (Exception e) {

                            Log.w(TAG, "setRecentsScreenshotEnabled failed", e);

                        }

                    }

                    removeOverlay();

                    applySecurityFlags(activity);

                });

                callbackContext.success();

                return true;

            case "registerScreenshotListener":

                registerScreenshotListener(activity, callbackContext);

                return true;

            default:

                return false;

        }

    }

    private void handleFocusChange(Activity activity, boolean hasFocus) {

        if (!blurEnabled) return;

        activity.runOnUiThread(() -> {

            if (!hasFocus) {

                showOverlay();

                activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);

            } else {

                hideOverlay();

                if (!isScreenshotProtected && !isScreenRecordingProtectionEnabled) {

                    activity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SECURE);

                }

            }

        });

    }

    private void applySecurityFlags(Activity activity) {

        activity.runOnUiThread(() -> {

            boolean shouldSecure = isScreenshotProtected || isScreenRecordingProtectionEnabled;

            if (shouldSecure) {

                activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);

            } else {

                activity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SECURE);

            }

        });

    }

    private void createOverlay(Activity activity) {

        if (!blurEnabled) return;

        if (overlayView != null && overlayView.getParent() != null) return;

        rootView = activity.findViewById(android.R.id.content);

        if (rootView == null) {

            Log.e(TAG, "Unable to find activity content view");

            return;

        }

        overlayView = new View(activity);

        overlayView.setBackgroundColor(Color.WHITE);

        overlayView.setClickable(false);

        overlayView.setFocusable(false);

        overlayView.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO);

        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(

                FrameLayout.LayoutParams.MATCH_PARENT,

                FrameLayout.LayoutParams.MATCH_PARENT);

        rootView.addView(overlayView, params);

        overlayView.setVisibility(View.GONE);

    }

    private void showOverlay() {

        if (!blurEnabled || overlayView == null) return;

        overlayView.setVisibility(View.VISIBLE);

        overlayView.bringToFront();

    }

    private void hideOverlay() {

        if (overlayView != null) {

            overlayView.setVisibility(View.GONE);

        }

    }

    private void removeOverlay() {

        if (overlayView != null && overlayView.getParent() instanceof FrameLayout) {

            ((FrameLayout) overlayView.getParent()).removeView(overlayView);

        }

        overlayView = null;

        rootView = null;

    }

    private void registerScreenshotListener(Activity activity, CallbackContext callbackContext) {

        screenshotCallbackContext = callbackContext;

        if (Build.VERSION.SDK_INT >= 34 && !screenshotCallbackRegistered) {

            activity.runOnUiThread(() -> {

                if (screenshotCallbackRegistered) return;

                try {

                    activity.registerScreenCaptureCallback(

                            activity.getMainExecutor(),

                            screenshotCaptureCallback);

                    screenshotCallbackRegistered = true;

                    Log.d(TAG, "Screenshot listener registered");

                } catch (Exception e) {

                    Log.e(TAG, "Failed to register screenshot listener", e);

                }

            });

        }

        PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);

        result.setKeepCallback(true);

        callbackContext.sendPluginResult(result);

    }

    @Override

    public void onPause(boolean multitasking) {

        super.onPause(multitasking);

        Activity activity = cordova.getActivity();

        if (blurEnabled && activity != null) {

            activity.runOnUiThread(() -> {

                showOverlay();

                activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);

            });

        }

    }

    @Override

    public void onStop() {

        super.onStop();

        Activity activity = cordova.getActivity();

        if (blurEnabled && activity != null) {

            activity.runOnUiThread(() -> {

                showOverlay();

                activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);

            });

        }

    }

    @Override

    public void onResume(boolean multitasking) {

        super.onResume(multitasking);

        Activity activity = cordova.getActivity();

        if (activity != null) {

            activity.runOnUiThread(() -> {

                hideOverlay();

                if (!isScreenshotProtected && !isScreenRecordingProtectionEnabled) {

                    activity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SECURE);

                }

            });

        }

    }

    @Override

    public void onDestroy() {

        Activity activity = cordova.getActivity();

        if (activity != null) {

            if (windowFocusListener != null) {

                View decorView = activity.getWindow().getDecorView();

                if (decorView != null) {

                    decorView.getViewTreeObserver().removeOnWindowFocusChangeListener(windowFocusListener);

                }

            }

            if (Build.VERSION.SDK_INT >= 34 && screenshotCallbackRegistered) {

                try {

                    activity.unregisterScreenCaptureCallback(screenshotCaptureCallback);

                } catch (Exception e) {

                    Log.w(TAG, "Screenshot listener cleanup failed", e);

                }

            }

            if (Build.VERSION.SDK_INT >= 33 && blurEnabled) {

                try {

                    activity.setRecentsScreenshotEnabled(true);

                } catch (Exception ignored) {}

            }

        }

        screenshotCallbackRegistered = false;

        screenshotCallbackContext = null;

        removeOverlay();

        super.onDestroy();

    }

}
 
