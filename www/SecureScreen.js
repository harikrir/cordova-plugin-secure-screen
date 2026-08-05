import UIKit

@objc(SecureScreen)

class SecureScreen: CDVPlugin {

    private var blurView: UIVisualEffectView?

    private var secureTextField: UITextField?

    private var screenshotProtectionEnabled = false

    private var recordingProtectionEnabled = false

    private var screenshotCallbackId: String?

    override func pluginInitialize() {

        NotificationCenter.default.addObserver(

            self,

            selector: #selector(screenshotTaken),

            name: UIApplication.userDidTakeScreenshotNotification,

            object: nil

        )

        NotificationCenter.default.addObserver(

            self,

            selector: #selector(screenCaptureChanged),

            name: UIScreen.capturedDidChangeNotification,

            object: nil

        )

    }

    // =====================================================

    // Screenshot Protection

    // =====================================================

    @objc(enableScreenshotProtection:)

    func enableScreenshotProtection(command: CDVInvokedUrlCommand) {

        screenshotProtectionEnabled = true

        DispatchQueue.main.async {

            self.setupSecureView()

        }

        let result = CDVPluginResult(status: CDVCommandStatus_OK)

        commandDelegate.send(result, callbackId: command.callbackId)

    }

    @objc(disableScreenshotProtection:)

    func disableScreenshotProtection(command: CDVInvokedUrlCommand) {

        screenshotProtectionEnabled = false

        DispatchQueue.main.async {

            self.removeSecureView()

        }

        let result = CDVPluginResult(status: CDVCommandStatus_OK)

        commandDelegate.send(result, callbackId: command.callbackId)

    }

    // =====================================================

    // Secure View Setup (Fixed for Cordova/OutSystems)

    // =====================================================

    private func setupSecureView() {

        guard secureTextField == nil, let webView = self.webView, let parent = webView.superview else { return }

        // 1. Create text field using standard frame layout instead of AutoLayout

        let textField = UITextField(frame: parent.bounds)

        textField.backgroundColor = .clear

        textField.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // FIX FOR FREEZE: Do NOT set isUserInteractionEnabled to false. 

        // Leaving it true allows the OutSystems web view to receive touches normally.

        textField.isUserInteractionEnabled = true 

        // 2. Add to parent BEFORE making it secure (required for iOS 14+)

        parent.insertSubview(textField, belowSubview: webView)

        textField.isSecureTextEntry = true

        // 3. Extract the secure view container

        guard let secureContainer = textField.subviews.first else {

            textField.removeFromSuperview()

            return

        }

        // 4. Move the Cordova webView inside the secure container

        secureContainer.addSubview(webView)

        // FIX FOR BLANKING: Force the webview to match the textfield bounds exactly

        webView.frame = textField.bounds

        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        self.secureTextField = textField

    }

    private func removeSecureView() {

        guard let textField = secureTextField, let webView = self.webView, let parent = textField.superview else { return }

        // Move the webView back to its original parent

        parent.addSubview(webView)

        // Restore standard Cordova frame layout

        webView.frame = parent.bounds

        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Clean up the text field

        textField.removeFromSuperview()

        self.secureTextField = nil

    }

    // =====================================================

    // Listeners & Callbacks

    // =====================================================

    @objc(registerScreenshotListener:)

    func registerScreenshotListener(command: CDVInvokedUrlCommand) {

        screenshotCallbackId = command.callbackId

        let result = CDVPluginResult(status: CDVCommandStatus_NO_RESULT)

        result?.setKeepCallbackAs(true)

        commandDelegate.send(result, callbackId: command.callbackId)

    }

    @objc private func screenshotTaken() {

        guard screenshotProtectionEnabled else { return }

        print("Screenshot detected")

        guard let callbackId = screenshotCallbackId else { return }

        let result = CDVPluginResult(

            status: CDVCommandStatus_OK,

            messageAs: "SCREENSHOT_DETECTED"

        )

        result?.setKeepCallbackAs(true)

        commandDelegate.send(result, callbackId: callbackId)

    }

    // =====================================================

    // Screen Recording Protection

    // =====================================================

    @objc(enableScreenRecordingProtection:)

    func enableScreenRecordingProtection(command: CDVInvokedUrlCommand) {

        recordingProtectionEnabled = true

        let result = CDVPluginResult(status: CDVCommandStatus_OK)

        commandDelegate.send(result, callbackId: command.callbackId)

    }

    @objc(disableScreenRecordingProtection:)

    func disableScreenRecordingProtection(command: CDVInvokedUrlCommand) {

        recordingProtectionEnabled = false

        DispatchQueue.main.async {

            self.removeBlur()

        }

        let result = CDVPluginResult(status: CDVCommandStatus_OK)

        commandDelegate.send(result, callbackId: command.callbackId)

    }

    @objc private func screenCaptureChanged() {

        guard recordingProtectionEnabled else { return }

        DispatchQueue.main.async {

            if UIScreen.main.isCaptured {

                print("Screen recording detected")

                self.addBlur()

            } else {

                print("Screen recording stopped")

                self.removeBlur()

            }

        }

    }

    // =====================================================

    // App Switcher Blur

    // =====================================================

    @objc(enableAppSwitcherBlur:)

    func enableAppSwitcherBlur(command: CDVInvokedUrlCommand) {

        NotificationCenter.default.addObserver(

            self,

            selector: #selector(addBlur),

            name: UIApplication.willResignActiveNotification,

            object: nil

        )

        NotificationCenter.default.addObserver(

            self,

            selector: #selector(removeBlur),

            name: UIApplication.didBecomeActiveNotification,

            object: nil

        )

        let result = CDVPluginResult(status: CDVCommandStatus_OK)

        commandDelegate.send(result, callbackId: command.callbackId)

    }

    @objc(disableAppSwitcherBlur:)

    func disableAppSwitcherBlur(command: CDVInvokedUrlCommand) {

        NotificationCenter.default.removeObserver(

            self,

            name: UIApplication.willResignActiveNotification,

            object: nil

        )

        NotificationCenter.default.removeObserver(

            self,

            name: UIApplication.didBecomeActiveNotification,

            object: nil

        )

        DispatchQueue.main.async {

            self.removeBlur()

        }

        let result = CDVPluginResult(status: CDVCommandStatus_OK)

        commandDelegate.send(result, callbackId: command.callbackId)

    }

    @objc private func addBlur() {

        guard blurView == nil, let webView = self.webView else { return }

        let effect = UIBlurEffect(style: .dark)

        let blur = UIVisualEffectView(effect: effect)

        blur.frame = webView.bounds

        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        webView.addSubview(blur)

        self.blurView = blur

    }

    @objc private func removeBlur() {

        blurView?.removeFromSuperview()

        blurView = nil

    }

}
 
