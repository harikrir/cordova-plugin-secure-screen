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

   // Secure View Setup (Window-Level / Global Blanket Approach)

   // =====================================================

   private func setupSecureView() {

       // 1. Safely unwrap the Global Window and Root View.

       // (Notice 'window' does NOT have a question mark on line 3 of this block to prevent the Swift compilation error)

       guard secureTextField == nil, 

             let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first,

             let rootView = window.rootViewController?.view else { return }

       // 2. Create the fake password field to generate the iOS security shield

       let textField = UITextField()

       textField.isSecureTextEntry = true

       textField.backgroundColor = .clear

       textField.isUserInteractionEnabled = false // Let all touches pass through to your OutSystems app

       // 3. Match the exact size of the device screen

       textField.frame = window.bounds

       textField.autoresizingMask = [.flexibleWidth, .flexibleHeight]

       // 4. Add the text field directly to the Window, behind the main app view

       window.insertSubview(textField, belowSubview: rootView)

       // Force the OS to render the internal secure layers immediately

       textField.layoutIfNeeded()

       // 5. Find the internal secure canvas

       guard let secureCanvasView = textField.subviews.first else { 

           textField.removeFromSuperview()

           return 

       }

       // Force the internal canvas to stretch across the whole screen.

       // This is CRITICAL to prevent the screenshot engine from bypassing the shield.

       secureCanvasView.frame = window.bounds

       secureCanvasView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

       // 6. THE GLOBAL HACK: 

       // We move the main layer of the *entire app* inside the privacy canvas.

       // OutSystems continues functioning normally in the Root View, but its visual output is routed through the shield.

       secureCanvasView.layer.addSublayer(rootView.layer)

       self.secureTextField = textField

   }

   private func removeSecureView() {

       // 1. Safely unwrap the Window and Root View again

       // (Ensuring no optional chaining errors here either)

       guard let textField = secureTextField, 

             let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first,

             let rootView = window.rootViewController?.view else { return }

       // 2. Safely restore the entire app's layer back to the global window

       window.layer.addSublayer(rootView.layer)

       // 3. Destroy the fake password field

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
