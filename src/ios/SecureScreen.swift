import UIKit
 
/**
* SecureScreen — Cordova plugin (iOS)
*
* Revision notes vs. original:
*  1. Shield is installed ONCE and toggled via `isSecureTextEntry` instead of
*     tearing down / re-parenting CALayers on every screen change.
*  2. Scene-aware window lookup (UIApplication.shared.windows is deprecated iOS 15+).
*  3. Shield self-heals: layer ownership + frame are re-validated on rotation,
*     foreground and every toggle.
*  4. Plugin results are sent AFTER the main-queue work completes, and report
*     real success/failure so OutSystems can fall back.
*  5. Blur view is created once and reused; recording state checked at enable time.
*  6. Observers registered once in pluginInitialize (no duplicate registration).
*/
@objc(SecureScreen)
class SecureScreen: CDVPlugin {
 
    // MARK: - State
 
    private var secureField: UITextField?
    private weak var secureCanvas: UIView?
    private weak var shieldedRootView: UIView?
    private var blurView: UIVisualEffectView?
 
    private var screenshotProtectionEnabled = false
    private var recordingProtectionEnabled = false
    private var appSwitcherBlurEnabled = false
    private var screenshotCallbackId: String?
 
    // MARK: - Lifecycle
 
    override func pluginInitialize() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(screenshotTaken),
                       name: UIApplication.userDidTakeScreenshotNotification, object: nil)
        nc.addObserver(self, selector: #selector(screenCaptureChanged),
                       name: UIScreen.capturedDidChangeNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleWillResignActive),
                       name: UIApplication.willResignActiveNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleDidBecomeActive),
                       name: UIApplication.didBecomeActiveNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleLayoutChange),
                       name: UIDevice.orientationDidChangeNotification, object: nil)
    }
 
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
 
    // MARK: - Window helper (scene-aware)
 
    private var appWindow: UIWindow? {
        if #available(iOS 13.0, *) {
            let windows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .sorted { $0.activationState.rawValue < $1.activationState.rawValue }
                .flatMap { $0.windows }
            if let key = windows.first(where: { $0.isKeyWindow }) { return key }
            if let first = windows.first { return first }
        }
        return UIApplication.shared.windows.first(where: { $0.isKeyWindow })
            ?? UIApplication.shared.windows.first
    }
 
    // MARK: - Shield install / validate
 
    /// Installs the secure canvas once. Returns false if iOS no longer exposes it.
    @discardableResult
    private func installShieldIfNeeded() -> Bool {
        if secureField != nil, secureCanvas != nil { return true }
 
        guard let window = appWindow,
              let rootView = window.rootViewController?.view else { return false }
 
        let field = UITextField()
        field.isSecureTextEntry = true
        field.backgroundColor = .clear
        field.isUserInteractionEnabled = false   // touches pass through to the app
        field.frame = window.bounds
        field.autoresizingMask = [.flexibleWidth, .flexibleHeight]
 
        // Sits behind everything; only its private canvas is used as a container.
        window.insertSubview(field, at: 0)
        field.layoutIfNeeded()
 
        guard let canvas = field.subviews.first else {
            field.removeFromSuperview()
            return false
        }
 
        canvas.frame = window.bounds
        canvas.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        canvas.layer.addSublayer(rootView.layer)
 
        secureField = field
        secureCanvas = canvas
        shieldedRootView = rootView
        return true
    }
 
    /// Re-asserts frame + layer ownership. UIKit can re-adopt the root layer on
    /// rotation, foregrounding, or when isSecureTextEntry is toggled.
    private func revalidateShield() {
        guard let window = appWindow,
              let field = secureField,
              let canvas = secureCanvas,
              let rootView = shieldedRootView ?? window.rootViewController?.view else { return }
 
        field.frame = window.bounds
        canvas.frame = window.bounds
 
        if rootView.layer.superlayer !== canvas.layer {
            canvas.layer.addSublayer(rootView.layer)
        }
    }
 
    private func teardownShield() {
        guard let field = secureField else { return }
        if let window = appWindow, let rootView = shieldedRootView {
            window.layer.addSublayer(rootView.layer)
        }
        field.removeFromSuperview()
        secureField = nil
        secureCanvas = nil
        shieldedRootView = nil
    }
 
    // MARK: - Screenshot protection
 
    @objc(enableScreenshotProtection:)
    func enableScreenshotProtection(command: CDVInvokedUrlCommand) {
        DispatchQueue.main.async {
            let installed = self.installShieldIfNeeded()
            if installed {
                self.secureField?.isSecureTextEntry = true
                self.revalidateShield()
            }
            self.screenshotProtectionEnabled = installed
 
            let result = CDVPluginResult(
                status: installed ? CDVCommandStatus_OK : CDVCommandStatus_ERROR,
                messageAs: installed ? "PROTECTED" : "SHIELD_UNAVAILABLE"
            )
            self.commandDelegate.send(result, callbackId: command.callbackId)
        }
    }
 
    @objc(disableScreenshotProtection:)
    func disableScreenshotProtection(command: CDVInvokedUrlCommand) {
        DispatchQueue.main.async {
            self.screenshotProtectionEnabled = false
            // Keep the shield installed — only disarm it. Avoids layer churn.
            self.secureField?.isSecureTextEntry = false
            self.revalidateShield()
 
            let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "UNPROTECTED")
            self.commandDelegate.send(result, callbackId: command.callbackId)
        }
    }
 
    /// Optional: call on logout / app teardown to fully remove the shield.
    @objc(destroyScreenshotProtection:)
    func destroyScreenshotProtection(command: CDVInvokedUrlCommand) {
        DispatchQueue.main.async {
            self.screenshotProtectionEnabled = false
            self.teardownShield()
            let result = CDVPluginResult(status: CDVCommandStatus_OK)
            self.commandDelegate.send(result, callbackId: command.callbackId)
        }
    }
 
    // MARK: - Listeners & callbacks
 
    @objc(registerScreenshotListener:)
    func registerScreenshotListener(command: CDVInvokedUrlCommand) {
        // Release any previously held callback so it does not leak.
        if let old = screenshotCallbackId, old != command.callbackId {
            let done = CDVPluginResult(status: CDVCommandStatus_NO_RESULT)
            commandDelegate.send(done, callbackId: old)
        }
        screenshotCallbackId = command.callbackId
 
        let result = CDVPluginResult(status: CDVCommandStatus_NO_RESULT)
        result?.setKeepCallbackAs(true)
        commandDelegate.send(result, callbackId: command.callbackId)
    }
 
    @objc private func screenshotTaken() {
        guard screenshotProtectionEnabled, let callbackId = screenshotCallbackId else { return }
        let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "SCREENSHOT_DETECTED")
        result?.setKeepCallbackAs(true)
        commandDelegate.send(result, callbackId: callbackId)
    }
 
    // MARK: - Screen recording protection
 
    @objc(enableScreenRecordingProtection:)
    func enableScreenRecordingProtection(command: CDVInvokedUrlCommand) {
        DispatchQueue.main.async {
            self.recordingProtectionEnabled = true
            // Handle the case where recording/mirroring is ALREADY active.
            if UIScreen.main.isCaptured { self.addBlur() }
            let result = CDVPluginResult(status: CDVCommandStatus_OK)
            self.commandDelegate.send(result, callbackId: command.callbackId)
        }
    }
 
    @objc(disableScreenRecordingProtection:)
    func disableScreenRecordingProtection(command: CDVInvokedUrlCommand) {
        DispatchQueue.main.async {
            self.recordingProtectionEnabled = false
            self.removeBlur()
            let result = CDVPluginResult(status: CDVCommandStatus_OK)
            self.commandDelegate.send(result, callbackId: command.callbackId)
        }
    }
 
    @objc private func screenCaptureChanged() {
        guard recordingProtectionEnabled else { return }
        DispatchQueue.main.async {
            UIScreen.main.isCaptured ? self.addBlur() : self.removeBlur()
        }
    }
 
    // MARK: - App switcher blur
 
    @objc(enableAppSwitcherBlur:)
    func enableAppSwitcherBlur(command: CDVInvokedUrlCommand) {
        appSwitcherBlurEnabled = true
        let result = CDVPluginResult(status: CDVCommandStatus_OK)
        commandDelegate.send(result, callbackId: command.callbackId)
    }
 
    @objc(disableAppSwitcherBlur:)
    func disableAppSwitcherBlur(command: CDVInvokedUrlCommand) {
        appSwitcherBlurEnabled = false
        DispatchQueue.main.async { self.removeBlur() }
        let result = CDVPluginResult(status: CDVCommandStatus_OK)
        commandDelegate.send(result, callbackId: command.callbackId)
    }
 
    @objc private func handleWillResignActive() {
        guard appSwitcherBlurEnabled else { return }
        addBlur()
    }
 
    @objc private func handleDidBecomeActive() {
        revalidateShield()
        if !(recordingProtectionEnabled && UIScreen.main.isCaptured) {
            removeBlur()
        }
    }
 
    @objc private func handleLayoutChange() {
        DispatchQueue.main.async {
            self.revalidateShield()
            if let window = self.appWindow { self.blurView?.frame = window.bounds }
        }
    }
 
    // MARK: - Blur (single reused instance)
 
    @objc private func addBlur() {
        guard let window = appWindow else { return }
 
        if blurView == nil {
            let blur = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
            blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            blurView = blur
        }
        guard let blur = blurView else { return }
 
        blur.frame = window.bounds
        if blur.superview !== window {
            window.addSubview(blur)
        }
        window.bringSubviewToFront(blur)
    }
 
    @objc private func removeBlur() {
        blurView?.removeFromSuperview()   // instance kept for reuse
    }
}
