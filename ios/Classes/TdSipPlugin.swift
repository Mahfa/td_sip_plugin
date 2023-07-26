import Flutter
import linphone

public class TdSipPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "td_sip_plugin", binaryMessenger: registrar.messenger())
        let instance = TdSipPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        registrar.register(TDDisplayViewFactory(messenger: registrar.messenger()), withId: "TDDisplayView")
        
        let eventChannel = FlutterEventChannel(name: "td_sip_plugin_stream", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(TDSipPluginManager.shared.streamHandler)
        
        LinphoneManager.shared.initialize()
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "login":
            guard let args = call.arguments as? [String: Any],
                  let sipID = args["sipID"] as? String,
                  let sipPassword = args["sipPassword"] as? String,
                  let sipDomain = args["sipDomain"] as? String,
                  let sipPort = args["sipPort"] as? String,
                  let sipTransport = args["sipTransport"] as? String,
                  let iceEnable = args["iceEnable"] as? Bool,
                  let turnEnable = args["turnEnable"] as? Bool,
                  let turnServer = args["turnServer"] as? String,
                  let turnUser = args["turnUser"] as? String,
                  let turnPassword = args["turnPassword"] as? String,
                  let proxy = args["proxy"] as? String
            else {
                result(FlutterError(code: "invalid_arguments", message: "Invalid arguments for login", details: nil))
                return
            }
            guard let proxyConfig = LinphoneManager.shared.setIdentify(sipID:sipID,
                                                                       sipPassword:sipPassword,
                                                                       sipDomain:sipDomain,
                                                                       sipPort:sipPort,
                                                                       sipTransport:sipTransport,
                                                                       iceEnable:iceEnable,
                                                                       turnEnable:turnEnable,
                                                                       turnServer:turnServer,
                                                                       turnUser:turnUser,
                                                                       turnPassword:turnPassword,
                                                                       proxy:proxy) else {
                print("no identity")
                return;
            }
            LinphoneManager.shared.register(proxyConfig)
        case "logout":
            LinphoneManager.shared.logout()
        case "getLoginStatus":
            result(NSNumber(value: LinphoneManager.shared.getLinphoneRegistrationState()?.rawValue ?? LinphoneRegistrationNone.rawValue))
        case "call":
            guard let args = call.arguments as? [String: Any],
                  let sipID = args["sipID"] as? String else {
                result(FlutterError(code: "invalid_arguments", message: "Invalid arguments for call", details: nil))
                return
            }
            LinphoneManager.shared.makeCall(calleeAccount: sipID)
        case "answer":
            if(LinphoneManager.shared.getLinphoneRegistrationState() == LinphoneRegistrationOk){
                LinphoneManager.shared.acceptSip();
            }
        case "hangup":
            if(LinphoneManager.shared.getLinphoneRegistrationState() == LinphoneRegistrationOk){
                LinphoneManager.shared.hangup();
            }
        case "switchToLoudspeaker":
            LinphoneManager.shared.openAmplification(open: true)
        case "switchToEarphone":
            LinphoneManager.shared.openAmplification(open: false)
        case "micOFF":
            LinphoneManager.shared.switchMic(open: false)
        case "micON":
            LinphoneManager.shared.switchMic(open: true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
