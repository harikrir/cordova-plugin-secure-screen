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

       // 1. Create the secure text field container

       let textField = UITextField()

       textField.isSecureTextEntry = true

       textField.backgroundColor = .clear

       textField.isUserInteractionEnabled = false // We don't want the text field to steal your touches

       // 2. Insert it into the view hierarchy

       parent.insertSubview(textField, belowSubview: webView)

       // 3. CRITICAL: Force the text field to fill the screen using constraints.

       // If we don't do this, the text field is 0x0, which causes the "White Screen" bug

       // because your webView layer will be forced into a 0 pixel box.

       textField.translatesAutoresizingMaskIntoConstraints = false

       NSLayoutConstraint.activate([

           textField.topAnchor.constraint(equalTo: parent.topAnchor),

           textField.bottomAnchor.constraint(equalTo: parent.bottomAnchor),

           textField.leadingAnchor.constraint(equalTo: parent.leadingAnchor),

           textField.trailingAnchor.constraint(equalTo: parent.trailingAnchor)

       ])

       // Force iOS to build the internal layers immediately so we can access them

       textField.setNeedsLayout()

       textField.layoutIfNeeded()

       // Find the actual secure canvas layer (iOS 15+)

       guard let secureCanvasView = textField.subviews.first else { 

           print("SecureScreen: Could not find secure canvas")

           textField.removeFromSuperview()

           return 

       }

       // 4. THE LAYER HACK: 

       // We move ONLY the layer, not the view (`addSublayer` instead of `addSubview`).

       // Why? WKWebView runs in a separate process. Using `addSublayer` forces the hardware 

       // to mask it, while leaving the view in the main hierarchy so touches don't freeze!

       secureCanvasView.layer.addSublayer(webView.layer)

       webView.layer.frame = secureCanvasView.bounds

       self.secureTextField = textField

   }

   private func removeSecureView() {

       guard let textField = secureTextField, let webView = self.webView, let originalParent = textField.superview else { return }

       // 1. Restore the layer back to the original Web View

       // The easiest way to force UIKit to repair a detached layer is to just re-add the view to the parent.

       webView.removeFromSuperview()

       originalParent.addSubview(webView)

       // 2. Ensure the web view stays full screen

       webView.translatesAutoresizingMaskIntoConstraints = false

       NSLayoutConstraint.activate([

           webView.topAnchor.constraint(equalTo: originalParent.topAnchor),

           webView.bottomAnchor.constraint(equalTo: originalParent.bottomAnchor),

           webView.leadingAnchor.constraint(equalTo: originalParent.leadingAnchor),

           webView.trailingAnchor.constraint(equalTo: originalParent.trailingAnchor)

       ])

       // 3. Clean up the fake password field

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
