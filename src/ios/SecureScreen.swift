import UIKit

@objc(SecureScreen)
class SecureScreen: CDVPlugin {

    private var blurView: UIVisualEffectView?

    @objc(enableScreenshotProtection:)
    func enableScreenshotProtection(command: CDVInvokedUrlCommand) {

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

        let result = CDVPluginResult(
            status: CDVCommandStatus_OK
        )

        commandDelegate.send(
            result,
            callbackId: command.callbackId
        )
    }

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

        let result = CDVPluginResult(
            status: CDVCommandStatus_OK
        )

        commandDelegate.send(
            result,
            callbackId: command.callbackId
        )
    }

    @objc(disableAppSwitcherBlur:)
    func disableAppSwitcherBlur(command: CDVInvokedUrlCommand) {

        NotificationCenter.default.removeObserver(self)

        let result = CDVPluginResult(
            status: CDVCommandStatus_OK
        )

        commandDelegate.send(
            result,
            callbackId: command.callbackId
        )
    }

    @objc
    private func addBlur() {

        guard blurView == nil else {
            return
        }

        let blurEffect = UIBlurEffect(style: .light)

        let blur = UIVisualEffectView(
            effect: blurEffect
        )

        blur.frame = UIScreen.main.bounds
        blur.autoresizingMask = [
            .flexibleWidth,
            .flexibleHeight
        ]

        UIApplication.shared.windows.first?.addSubview(
            blur
        )

        blurView = blur
    }

    @objc
    private func removeBlur() {

        blurView?.removeFromSuperview()
        blurView = nil
    }
}
