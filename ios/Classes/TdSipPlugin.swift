import Flutter
import linphonesw

public class TdSipPlugin: NSObject, FlutterPlugin ,FlutterStreamHandler{
    public static var eventSink: FlutterEventSink?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = TdSipPlugin()
        let eventChannel = FlutterEventChannel(name: "com.mz.td_sip_plugin/streams", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)
        
        let channel = FlutterMethodChannel(name: "com.mz.td_sip_plugin/actions", binaryMessenger: registrar.messenger())
        
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        registrar.register(TDDisplayViewFactory(messenger: registrar.messenger()), withId: "TDDisplayView")
        
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
            LinphoneManager.shared.register(sipID:sipID,
                                            sipPassword:sipPassword,
                                            sipDomain:sipDomain,
                                            sipPort:sipPort,
                                            sipTransport:sipTransport,
                                            iceEnable:iceEnable,
                                            turnEnable:turnEnable,
                                            turnServer:turnServer,
                                            turnUser:turnUser,
                                            turnPassword:turnPassword,
                                            proxy:proxy)
        case "logout":
            LinphoneManager.shared.logout()
        case "getLoginStatus":
            result(NSNumber(value: LinphoneManager.shared.getLinphoneRegistrationState()?.rawValue ?? RegistrationState.None.rawValue))
        case "call":
            guard let args = call.arguments as? [String: Any],
                  let sipID = args["sipID"] as? String else {
                result(FlutterError(code: "invalid_arguments", message: "Invalid arguments for call", details: nil))
                return
            }
            LinphoneManager.shared.makeCall(calleeAccount: sipID)
        case "answer":
            if(LinphoneManager.shared.getLinphoneRegistrationState() == RegistrationState.Ok){
                LinphoneManager.shared.acceptSip();
            }
        case "hangup":
            if(LinphoneManager.shared.getLinphoneRegistrationState() == RegistrationState.Ok){
                LinphoneManager.shared.hangup();
            }
        case "routeAudioToEarpiece":
            LinphoneManager.shared.routeAudioToEarpiece()
        case "routeAudioToSpeaker":
            LinphoneManager.shared.routeAudioToSpeaker()
        case "routeAudioToBluetooth":
            LinphoneManager.shared.routeAudioToBluetooth()
        case "routeAudioToHeadset":
            LinphoneManager.shared.routeAudioToHeadset()
        case "micOFF":
            LinphoneManager.shared.switchMic(open: false)
        case "micON":
            LinphoneManager.shared.switchMic(open: true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        TdSipPlugin.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }
}
