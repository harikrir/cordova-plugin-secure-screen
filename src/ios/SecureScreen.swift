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
      // 1. Create a transparent text field to provide the secure layer
      let textField = UITextField()
      textField.isSecureTextEntry = true
      textField.isUserInteractionEnabled = false // Let touches pass through
      textField.backgroundColor = .clear
      // 2. Match the exact layout of the web view
      textField.frame = webView.frame
      textField.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      // 3. Insert into the view hierarchy
      parent.insertSubview(textField, belowSubview: webView)
      // CRITICAL FIX 1: Force iOS to build the internal layers immediately.
      // Without this, the subviews/sublayers don't exist yet on modern iOS.
      textField.setNeedsLayout()
      textField.layoutIfNeeded()
      // CRITICAL FIX 2: Target the first subview's layer (the actual text canvas in iOS 15+)
      guard let secureCanvasView = textField.subviews.first else {
          print("SecureScreen: Could not find secure canvas")
          return
      }
      // 4. Move ONLY the rendering layer into the secure text field canvas.
      secureCanvasView.layer.addSublayer(webView.layer)
      // Ensure the webview layout dimensions stay perfectly aligned inside the new layer
      webView.layer.frame = secureCanvasView.bounds
      self.secureTextField = textField
  }
  private func removeSecureView() {
      guard let textField = secureTextField, let webView = self.webView, let parent = textField.superview else { return }
      // 1. Natively reparent the webView back to the main view.
      // Calling addSubview natively restores the layer hierarchy safely.
      parent.addSubview(webView)
      // 2. Clean up the text field
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
