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

   // Secure View Setup (The Layer Hack for OutSystems/Cordova)

   // =====================================================

   private func setupSecureView() {

       guard secureTextField == nil, let webView = self.webView, let parent = webView.superview else { return }

       let textField = UITextField()

       textField.isSecureTextEntry = true

       textField.backgroundColor = .clear

       textField.isUserInteractionEnabled = true

       // 1. Insert text field exactly where the webview was

       if let index = parent.subviews.firstIndex(of: webView) {

           parent.insertSubview(textField, at: index)

       } else {

           parent.addSubview(textField)

       }

       // 2. Force the TextField to stretch to the parent's edges using Constraints

       textField.translatesAutoresizingMaskIntoConstraints = false

       NSLayoutConstraint.activate([

           textField.topAnchor.constraint(equalTo: parent.topAnchor),

           textField.bottomAnchor.constraint(equalTo: parent.bottomAnchor),

           textField.leadingAnchor.constraint(equalTo: parent.leadingAnchor),

           textField.trailingAnchor.constraint(equalTo: parent.trailingAnchor)

       ])

       // Force iOS to build the internal secure layers immediately

       textField.setNeedsLayout()

       textField.layoutIfNeeded()

       guard let secureCanvasView = textField.subviews.first else { 

           print("SecureScreen: Could not find secure canvas")

           textField.removeFromSuperview()

           return 

       }

       secureCanvasView.isUserInteractionEnabled = true

       // 3. Move the WKWebView inside the secure canvas

       secureCanvasView.addSubview(webView)

       // 4. CRITICAL FIX: Force the WebView to stretch to the TextField edges using Constraints.

       // This prevents the WebView from collapsing to 0x0 inside the empty canvas.

       webView.translatesAutoresizingMaskIntoConstraints = false

       NSLayoutConstraint.activate([

           webView.topAnchor.constraint(equalTo: textField.topAnchor),

           webView.bottomAnchor.constraint(equalTo: textField.bottomAnchor),

           webView.leadingAnchor.constraint(equalTo: textField.leadingAnchor),

           webView.trailingAnchor.constraint(equalTo: textField.trailingAnchor)

       ])

       self.secureTextField = textField

   }

   private func removeSecureView() {

       guard let textField = secureTextField, let webView = self.webView, let originalParent = textField.superview else { return }

       // 1. Restore the webview back to the main view controller

       if let index = originalParent.subviews.firstIndex(of: textField) {

           originalParent.insertSubview(webView, at: index)

       } else {

           originalParent.addSubview(webView)

       }

       // 2. Restore Cordova's default sizing behavior (removing constraints)

       webView.translatesAutoresizingMaskIntoConstraints = true

       webView.frame = originalParent.bounds

       webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

       // 3. Clean up the hack

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
       // Add the blur to the highest possible view layer to ensure it covers everything
       if let window = UIApplication.shared.windows.first {
           blur.frame = window.bounds
           window.addSubview(blur)
       } else {
           webView.addSubview(blur)
       }
       self.blurView = blur
   }
   @objc private func removeBlur() {
       blurView?.removeFromSuperview()
       blurView = nil
   }
}
