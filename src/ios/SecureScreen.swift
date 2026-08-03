import UIKit
import Cordova

@objc(SecureScreen)
class SecureScreen: CDVPlugin {

    private var blurView: UIVisualEffectView?

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
    // Screenshot Detection
    // =====================================================

    @objc(enableScreenshotProtection:)
    func enableScreenshotProtection(command: CDVInvokedUrlCommand) {

        screenshotProtectionEnabled = true

        let result = CDVPluginResult(
            status: CDVCommandStatus_OK
        )

        commandDelegate.send(
            result,
            callbackId: command.callbackId
        )
    }

    @objc(disableScreenshotProtection:)
    func disableScreenshotProtection(command: CDVInvokedUrlCommand) {

        screenshotProtectionEnabled = false

        let result = CDVPluginResult(
            status: CDVCommandStatus_OK
        )

        commandDelegate.send(
            result,
            callbackId: command.callbackId
        )
    }

    @objc(registerScreenshotListener:)
    func registerScreenshotListener(
        command: CDVInvokedUrlCommand
    ) {

        screenshotCallbackId = command.callbackId

        let result = CDVPluginResult(
            status: CDVCommandStatus_NO_RESULT
        )

        result?.setKeepCallbackAs(true)

        commandDelegate.send(
            result,
            callbackId: command.callbackId
        )
    }

    @objc
    private func screenshotTaken() {

        guard screenshotProtectionEnabled else {
            return
        }

        print("Screenshot detected")

        guard let callbackId = screenshotCallbackId else {
            return
        }

        let result = CDVPluginResult(
            status: CDVCommandStatus_OK,
            messageAs: "SCREENSHOT_DETECTED"
        )

        result?.setKeepCallbackAs(true)

        commandDelegate.send(
            result,
            callbackId: callbackId
        )
    }

    // =====================================================
    // Screen Recording Protection
    // =====================================================

    @objc(enableScreenRecordingProtection:)
    func enableScreenRecordingProtection(
        command: CDVInvokedUrlCommand
    ) {

        recordingProtectionEnabled = true

        let result = CDVPluginResult(
            status: CDVCommandStatus_OK
        )

        commandDelegate.send(
            result,
            callbackId: command.callbackId
        )
    }

    @objc(disableScreenRecordingProtection:)
    func disableScreenRecordingProtection(
        command: CDVInvokedUrlCommand
    ) {

        recordingProtectionEnabled = false

        removeBlur()

        let result = CDVPluginResult(
            status: CDVCommandStatus_OK
        )

        commandDelegate.send(
            result,
            callbackId: command.callbackId
        )
    }

    @objc
    private func screenCaptureChanged() {

        guard recordingProtectionEnabled else {
            return
        }

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
    func enableAppSwitcherBlur(
        command: CDVInvokedUrlCommand
    ) {

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

        let result = CDVPluginResult(
            status: CDVCommandStatus_OK
        )

        commandDelegate.send(
            result,
            callbackId: command.callbackId
        )
    }

    @objc(disableAppSwitcherBlur:)
    func disableAppSwitcherBlur(
        command: CDVInvokedUrlCommand
    ) {

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

        removeBlur()

        let result = CDVPluginResult(
            status: CDVCommandStatus_OK
        )

        commandDelegate.send(
            result,
            callbackId: command.callbackId
        )
    }

    // =====================================================
    // Blur Helpers
    // =====================================================

    @objc
    private func addBlur() {

        guard blurView == nil else {
            return
        }

        let blurEffect = UIBlurEffect(style: .light)

        let blur = UIVisualEffectView(
            effect: blurEffect
        )

        if let window = UIApplication.shared.windows.first {

            blur.frame = window.bounds
            blur.autoresizingMask = [
                .flexibleWidth,
                .flexibleHeight
            ]

            window.addSubview(blur)

            blurView = blur
        }
    }

    @objc
    private func removeBlur() {

        blurView?.removeFromSuperview()
        blurView = nil
    }

    deinit {

        NotificationCenter.default.removeObserver(self)
    }
}
