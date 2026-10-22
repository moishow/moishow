import Flutter
import UIKit
import GoogleSignIn

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MoishowIdentity") else { return }
    let channel = FlutterMethodChannel(name: "com.moishow/identity", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "googleSignIn" else { result(FlutterMethodNotImplemented); return }
      guard let args = call.arguments as? [String: String],
            let clientID = args["clientId"], !clientID.isEmpty,
            let serverID = args["serverClientId"], !serverID.isEmpty,
            let nonce = args["nonce"], !nonce.isEmpty,
            let presenter = self.window?.rootViewController else {
        result(FlutterError(code: "GOOGLE_CONFIGURATION_MISSING", message: "iOS client ID, server ID, nonce and presenter are required", details: nil))
        return
      }
      GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID, serverClientID: serverID)
      GIDSignIn.sharedInstance.signIn(withPresenting: presenter, hint: nil, additionalScopes: nil, nonce: nonce) { response, error in
        if let error = error {
          result(FlutterError(code: "GOOGLE_AUTH_FAILED", message: error.localizedDescription, details: nil))
        } else if let token = response?.user.idToken?.tokenString {
          result(token)
        } else {
          result(FlutterError(code: "GOOGLE_TOKEN_MISSING", message: "Google ID token missing", details: nil))
        }
      }
    }
  }
}
