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

   // Secure View Setup (OutSystems / Cordova Safe Layer Hack)

   // =====================================================

   private func setupSecureView() {

       guard secureTextField == nil, let webView = self.webView, let parent = webView.superview else { return }

       // 1. Create the fake password field

       let textField = UITextField()

       textField.isSecureTextEntry = true

       textField.backgroundColor = .clear

       textField.textColor = .clear // Hide any dummy text

       textField.isUserInteractionEnabled = false // Let touches pass through to OutSystems

       // Add a blank space to force iOS to wake up the internal secure canvas

       textField.text = " " 

       // 2. Set it to exactly match the screen size

       textField.frame = parent.bounds

       textField.autoresizingMask = [.flexibleWidth, .flexibleHeight]

       // 3. Insert behind the OutSystems webview

       parent.insertSubview(textField, belowSubview: webView)

       textField.layoutIfNeeded()

       // 4. Find the internal privacy canvas (iOS 15+)

       guard let secureCanvasView = textField.subviews.first else { 

           textField.removeFromSuperview()

           return 

       }

       // 5. CRITICAL FIX FOR iOS 17 SCREENSHOT LEAK:

       // The internal canvas defaults to the size of the text. If it's too small, iOS 

       // won't blur the whole screen. We MUST force it to physically cover the app!

       secureCanvasView.frame = textField.bounds

       secureCanvasView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

       // 6. THE OUTSYSTEMS HACK:

       // We move ONLY the webView's *layer*, not the view itself!

       // Moving the view crashes OutSystems (causing the White Screen).

       // Moving the layer protects the screen visually while leaving the view hierarchy perfectly intact.

       secureCanvasView.layer.addSublayer(webView.layer)

       self.secureTextField = textField

   }

   private func removeSecureView() {

       guard let textField = secureTextField, let webView = self.webView, let parent = webView.superview else { return }

       // 1. Restore the webView's layer back to its original parent's layer

       // This flawlessly reverses the hack without triggering an OutSystems/Cordova reload

       parent.layer.addSublayer(webView.layer)

       // 2. Destroy the fake password field

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
