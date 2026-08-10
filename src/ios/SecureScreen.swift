import UIKit

import WebKit

/**

* SecureScreen — Cordova plugin (iOS)

*/

@objc(SecureScreen)

class SecureScreen: CDVPlugin {

    // MARK: - State

    private var secureField: UITextField?

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

    }

    deinit {

        NotificationCenter.default.removeObserver(self)

    }

    // MARK: - Window Helper

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

    // MARK: - Screenshot Protection (Native Secure Layer Injection)

    @objc(enableScreenshotProtection:)

    func enableScreenshotProtection(command: CDVInvokedUrlCommand) {

        DispatchQueue.main.async {

            guard let webView = self.webView, 

                  let webViewSuperview = webView.superview, 

                  self.secureField == nil else {

                let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "ALREADY_PROTECTED")

                self.commandDelegate.send(result, callbackId: command.callbackId)

                return

            }

            // 1. Create a secure UITextField

            let field = UITextField()

            field.isSecureTextEntry = true

            field.backgroundColor = .clear

            field.isUserInteractionEnabled = false // Allow touches to pass through directly to the webview

            // Force rendering of the secure canvas without displaying artifacts

            field.text = " "

            field.textColor = .clear

            field.tintColor = .clear

            // 2. Insert field behind webview as a sibling (Fixes the recursive freeze bug)

            webViewSuperview.insertSubview(field, belowSubview: webView)

            field.frame = webView.frame

            field.autoresizingMask = [.flexibleWidth, .flexibleHeight]

            // 3. Inject the WKWebView's layer directly inside the secure text field's DRM layer.

            if let secureCanvas = field.layer.sublayers?.last {

                secureCanvas.addSublayer(webView.layer)

            } else if let secureCanvasFallback = field.layer.sublayers?.first {

                secureCanvasFallback.addSublayer(webView.layer)

            }

            self.secureField = field

            self.screenshotProtectionEnabled = true

            let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "PROTECTED")

            self.commandDelegate.send(result, callbackId: command.callbackId)

        }

    }

    @objc(disableScreenshotProtection:)

    func disableScreenshotProtection(command: CDVInvokedUrlCommand) {

        DispatchQueue.main.async {

            guard let field = self.secureField, 

                  let webView = self.webView, 

                  let webViewSuperview = webView.superview else {

                let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "UNPROTECTED")

                self.commandDelegate.send(result, callbackId: command.callbackId)

                return

            }

            // 1. Restore the webView's layer to its original superlayer 

            webViewSuperview.layer.addSublayer(webView.layer)

            // 2. Clean up the text field

            field.layer.removeFromSuperlayer()

            field.removeFromSuperview()

            self.secureField = nil

            self.screenshotProtectionEnabled = false

            let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "UNPROTECTED")

            self.commandDelegate.send(result, callbackId: command.callbackId)

        }

    }

    @objc(destroyScreenshotProtection:)

    func destroyScreenshotProtection(command: CDVInvokedUrlCommand) {

        disableScreenshotProtection(command: command)

    }

    // MARK: - Listeners & Callbacks

    @objc(registerScreenshotListener:)

    func registerScreenshotListener(command: CDVInvokedUrlCommand) {

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

    // MARK: - Screen Recording Protection

    @objc(enableScreenRecordingProtection:)

    func enableScreenRecordingProtection(command: CDVInvokedUrlCommand) {

        DispatchQueue.main.async {

            self.recordingProtectionEnabled = true

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

    // MARK: - App Switcher Blur

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

        if !(recordingProtectionEnabled && UIScreen.main.isCaptured) {

            removeBlur()

        }

    }

    // MARK: - Blur Utilities

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

        blurView?.removeFromSuperview()

    }

}
 
