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
      // 1. Create a transparent text field to act as the secure container
      let textField = UITextField()
      textField.isSecureTextEntry = true
      textField.backgroundColor = .clear
      // CRITICAL FIX 1: This MUST be true. If false, the webview inside won't receive touches/scrolls.
      textField.isUserInteractionEnabled = true
      // 2. Match the exact layout of the web view
      textField.frame = webView.frame
      textField.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      // 3. Insert the text field in the exact same z-index position the webview was in
      if let index = parent.subviews.firstIndex(of: webView) {
          parent.insertSubview(textField, at: index)
      } else {
          parent.addSubview(textField)
      }
      // Force iOS to build the internal secure layers immediately
      textField.setNeedsLayout()
      textField.layoutIfNeeded()
      guard let secureCanvasView = textField.subviews.first else {
          print("SecureScreen: Could not find secure canvas")
          textField.removeFromSuperview()
          return
      }
      // Ensure touches pass through the internal canvas to your app
      secureCanvasView.isUserInteractionEnabled = true
      // CRITICAL FIX 2: Move the ENTIRE view using addSubview, not addSublayer.
      // WKWebView will turn completely white if its layer is detached from its UI hierarchy.
      secureCanvasView.addSubview(webView)
      // Match frames so the webview stretches correctly inside the secure canvas
      webView.frame = secureCanvasView.bounds
      webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
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
      // 2. Restore layout bindings
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
