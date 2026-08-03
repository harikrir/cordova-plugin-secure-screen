import UIKit

@objc(SecureScreen)
class SecureScreen: CDVPlugin {

    private var blurView: UIVisualEffectView?

    private var secureTextField: UITextField?
private var originalSuperview: UIView?
private var screenshotProtectionEnabled = false

@objc(enableScreenshotProtection:)
func enableScreenshotProtection(command: CDVInvokedUrlCommand) {

    DispatchQueue.main.async {

        if self.screenshotProtectionEnabled {
            return
        }

        guard let webView = self.webView else {
            return
        }

        guard let superview = webView.superview else {
            return
        }

        let secureField = UITextField(frame: superview.bounds)
        secureField.isSecureTextEntry = true
        secureField.isUserInteractionEnabled = false
        secureField.translatesAutoresizingMaskIntoConstraints = false

        superview.addSubview(secureField)

        guard let secureContainer = secureField.subviews.first else {
            return
        }

        self.originalSuperview = superview

        webView.removeFromSuperview()

        secureContainer.addSubview(webView)

        webView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: secureContainer.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: secureContainer.trailingAnchor),
            webView.topAnchor.constraint(equalTo: secureContainer.topAnchor),
            webView.bottomAnchor.constraint(equalTo: secureContainer.bottomAnchor)
        ])

        self.secureTextField = secureField
        self.screenshotProtectionEnabled = true
    }

    let result = CDVPluginResult(status: CDVCommandStatus_OK)

    commandDelegate.send(
        result,
        callbackId: command.callbackId
    )
}

@objc(disableScreenshotProtection:)
func disableScreenshotProtection(command: CDVInvokedUrlCommand) {

    DispatchQueue.main.async {

        guard self.screenshotProtectionEnabled,
              let webView = self.webView,
              let originalSuperview = self.originalSuperview else {
            return
        }

        webView.removeFromSuperview()

        originalSuperview.addSubview(webView)

        webView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: originalSuperview.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: originalSuperview.trailingAnchor),
            webView.topAnchor.constraint(equalTo: originalSuperview.topAnchor),
            webView.bottomAnchor.constraint(equalTo: originalSuperview.bottomAnchor)
        ])

        self.secureTextField?.removeFromSuperview()

        self.secureTextField = nil
        self.originalSuperview = nil
        self.screenshotProtectionEnabled = false
    }

    let result = CDVPluginResult(status: CDVCommandStatus_OK)

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
