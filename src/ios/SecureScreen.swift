import UIKit

/**

* SecureScreen — Cordova plugin (iOS)

*/

@objc(SecureScreen)

class SecureScreen: CDVPlugin {

    // MARK: - State

    private var secureField: SecureContainerField?

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

    @discardableResult

    private func installShieldIfNeeded() -> Bool {

        if secureField != nil, secureCanvas != nil { return true }

        guard let targetView = self.webView,

              let parentView = targetView.superview else { return false }

        let field = SecureContainerField(frame: parentView.bounds)

        field.passthroughView = targetView

        field.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        parentView.insertSubview(field, belowSubview: targetView)

        field.layoutIfNeeded()

        guard let canvas = field.subviews.first else {

            field.removeFromSuperview()

            return false

        }

        canvas.frame = parentView.bounds

        canvas.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        canvas.addSubview(targetView)

        secureField = field

        secureCanvas = canvas

        shieldedRootView = targetView

        return true

    }

    private func revalidateShield() {

        guard let field = secureField,

              let canvas = secureCanvas,

              let targetView = shieldedRootView else { return }

        field.frame = field.superview?.bounds ?? field.frame

        canvas.frame = field.bounds

        if targetView.superview !== canvas {

            canvas.addSubview(targetView)

        }

    }

    private func teardownShield() {

        guard let field = secureField, 

              let targetView = shieldedRootView,

              let parentView = field.superview else { return }

        parentView.insertSubview(targetView, aboveSubview: field)

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

            self.secureField?.isSecureTextEntry = false

            self.revalidateShield()

            let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "UNPROTECTED")

            self.commandDelegate.send(result, callbackId: command.callbackId)

        }

    }

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

        blurView?.removeFromSuperview()

    }

}

// MARK: - Secure Container Field

class SecureContainerField: UITextField {

    weak var passthroughView: UIView?

    override init(frame: CGRect) {

        super.init(frame: frame)

        setup()

    }

    required init?(coder: NSCoder) {

        super.init(coder: coder)

        setup()

    }

    private func setup() {

        self.isSecureTextEntry = true

        self.backgroundColor = .clear

        self.textColor = .clear

        self.tintColor = .clear 

        self.isUserInteractionEnabled = true 

    }

    override var canBecomeFirstResponder: Bool {

        return false

    }

    override func becomeFirstResponder() -> Bool {

        return false

    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {

        guard let target = passthroughView else {

            return super.hitTest(point, with: event)

        }

        let convertedPoint = self.convert(point, to: target)

        if let hitView = target.hitTest(convertedPoint, with: event) {

            return hitView

        }

        return super.hitTest(point, with: event)

    }

}
 
