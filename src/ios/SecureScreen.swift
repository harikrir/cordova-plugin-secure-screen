import UIKit

import WebKit

/**

* SecureScreen — Cordova plugin (iOS)

*/

@objc(SecureScreen)

class SecureScreen: CDVPlugin {

    // MARK: - State

    private var secureField: SecureContainerField?

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

    // MARK: - Screenshot Protection (Native Secure View Injection)

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

            // 1. Create a custom secure UITextField to handle touches

            let field = SecureContainerField()

            field.isSecureTextEntry = true

            field.backgroundColor = .clear

            field.targetWebView = webView

            // Force rendering of the secure canvas without displaying artifacts

            field.text = " "

            field.textColor = .clear

            field.tintColor = .clear

            // 2. Add field to the original view container

            webViewSuperview.addSubview(field)

            field.frame = webView.frame

            field.autoresizingMask = [.flexibleWidth, .flexibleHeight]

            // 3. Find the internal secure canvas view of the UITextField

            let canvasView = field.subviews.first(where: { String(describing: type(of: $0)).contains("Canvas") }) ?? field.subviews.first

            // 4. Move WKWebView INTO the canvas view

            // This keeps the View Hierarchy intact for touches, while placing it under the DRM Layer for blank screenshots

            if let canvas = canvasView {

                canvas.isUserInteractionEnabled = true

                canvas.addSubview(webView)

                webView.frame = canvas.bounds

                webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

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

                  let originalSuperview = field.superview else {

                let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "UNPROTECTED")

                self.commandDelegate.send(result, callbackId: command.callbackId)

                return

            }

            // 1. Restore the webView back to the original container

            originalSuperview.addSubview(webView)

            webView.frame = field.frame

            // 2. Clean up the secure text field

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

// MARK: - Custom Touch Routing Field

class SecureContainerField: UITextField {

    weak var targetWebView: UIView?

    // Prevents the keyboard from ever popping up

    override var canBecomeFirstResponder: Bool { false }

    // Bypasses the TextField's internal touch logic and routes taps directly to the Web View

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {

        guard let webView = targetWebView else {

            return super.hitTest(point, with: event)

        }

        let convertedPoint = self.convert(point, to: webView)

        // If the tap happens over the web app, let the web app handle it

        if webView.bounds.contains(convertedPoint) {

            if let hitView = webView.hitTest(convertedPoint, with: event) {

                return hitView

            }

        }

        return super.hitTest(point, with: event)

    }

}
 
