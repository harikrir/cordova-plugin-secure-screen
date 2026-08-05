import UIKit

@objc(SecureScreen)

class SecureScreen: CDVPlugin {

    private var blurView: UIVisualEffectView?

    private var secureTextField: UITextField?

    private var screenshotProtectionEnabled = false

    private var recordingProtectionEnabled = false

    private var screenshotCallbackId: String?

    override func pluginInitialize() {

        // Keep your existing observers if you still want to log or send callbacks

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

    // Screenshot Protection (The Workaround)

    // =====================================================

    @objc(enableScreenshotProtection:)

    func enableScreenshotProtection(command: CDVInvokedUrlCommand) {

        screenshotProtectionEnabled = true

        // Setup the secure view on the main thread

        DispatchQueue.main.async {

            self.setupSecureView()

        }

        let result = CDVPluginResult(status: CDVCommandStatus_OK)

        commandDelegate.send(result, callbackId: command.callbackId)

    }

    @objc(disableScreenshotProtection:)

    func disableScreenshotProtection(command: CDVInvokedUrlCommand) {

        screenshotProtectionEnabled = false

        // Remove the secure view on the main thread

        DispatchQueue.main.async {

            self.removeSecureView()

        }

        let result = CDVPluginResult(status: CDVCommandStatus_OK)

        commandDelegate.send(result, callbackId: command.callbackId)

    }

    // =====================================================

    // Secure View Setup (The Magic Hack)

    // =====================================================

    private func setupSecureView() {

        // Ensure we haven't already set it up, and we have a webView

        guard secureTextField == nil, let webView = self.webView, let parent = webView.superview else { return }

        // Create a secure text field

        let textField = UITextField()

        textField.isSecureTextEntry = true

        textField.isUserInteractionEnabled = false

        // Add it to the parent view hierarchy

        parent.insertSubview(textField, belowSubview: webView)

        // Extract the secure view container from the text field

        guard let secureContainer = textField.subviews.first else {

            textField.removeFromSuperview()

            return

        }

        // Move the Cordova webView inside the secure container

        secureContainer.addSubview(webView)

        // Ensure the webView still fills the entire screen

        webView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([

            webView.topAnchor.constraint(equalTo: parent.topAnchor),

            webView.bottomAnchor.constraint(equalTo: parent.bottomAnchor),

            webView.leadingAnchor.constraint(equalTo: parent.leadingAnchor),

            webView.trailingAnchor.constraint(equalTo: parent.trailingAnchor)

        ])

        self.secureTextField = textField

    }

    private func removeSecureView() {

        guard let textField = secureTextField, let webView = self.webView, let parent = textField.superview else { return }

        // Move the webView back to its original parent

        parent.addSubview(webView)

        // Restore layout constraints

        webView.translatesAutoresizingMaskIntoConstraints = true

        webView.frame = parent.bounds

        // Remove the secure text field

        textField.removeFromSuperview()

        self.secureTextField = nil

    }

    // =====================================================

    // Listeners & Callbacks (Unchanged)

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

    // Note: The secure UITextField workaround above usually blacks out 

    // screen recordings automatically as well. 

    @objc(enableScreenRecordingProtection:)

    func enableScreenRecordingProtection(command: CDVInvokedUrlCommand) {

        recordingProtectionEnabled = true

        let result = CDVPluginResult(status: CDVCommandStatus_OK)

        commandDelegate.send(result, callbackId: command.callbackId)

    }

    @objc(disableScreenRecordingProtection:)

    func disableScreenRecordingProtection(command: CDVInvokedUrlCommand) {

        recordingProtectionEnabled = false

        removeBlur()

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
 
