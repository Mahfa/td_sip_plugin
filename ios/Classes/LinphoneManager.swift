//
//  LinphoneManager.swift
//  linphone-swift-demo
//
//  Created by Hamza Öztürk on 25.12.2019.
//  Copyright © 2019 Busoft. All rights reserved.
//

import Foundation
import AVFoundation

class LinphoneManager: NSObject {

    static let shared = LinphoneManager()
    
    private var linphoneCore: OpaquePointer?
    private var linphoneLoggingService: OpaquePointer?
    private var lastLinphoneRegistrationState: LinphoneRegistrationState?
    private var lastLinphoneCallState: LinphoneCallState?
    private var mCurrentAddress : String = ""
    private static var iterateTimer: Timer?

    private override init() {}

    private let registrationStateChanged: LinphoneCoreRegistrationStateChangedCb  = {
        (lc: Optional<OpaquePointer>, proxyConfig: Optional<OpaquePointer>, state: LinphoneRegistrationState, message: Optional<UnsafePointer<Int8>>) in
        
        LinphoneManager.shared.registrationStateChanged(lc: lc, proxyConfig: proxyConfig, state: state, message: message)
    } as LinphoneCoreRegistrationStateChangedCb
    
    private let callStateChanged: LinphoneCoreCallStateChangedCb = {
        (lc: Optional<OpaquePointer>, call: Optional<OpaquePointer>, state: LinphoneCallState,  message: Optional<UnsafePointer<Int8>>) in
        
        LinphoneManager.shared.callStateChanged(lc: lc, call: call, state: state, message: message)
    }
    
    private func registrationStateChanged(lc: Optional<OpaquePointer>, proxyConfig: Optional<OpaquePointer>, state: LinphoneRegistrationState, message: Optional<UnsafePointer<Int8>>) {
        lastLinphoneRegistrationState = state;
        var stateMessage = ""
        if let message = message {
            stateMessage = String(cString: message)
        }
        
        switch state{
        case LinphoneRegistrationNone:
            print("registrationStateChanged -> LinphoneRegistrationNone -> \(stateMessage)")
        case LinphoneRegistrationProgress:
            print("registrationStateChanged -> LinphoneRegistrationProgress -> \(stateMessage)")
        case LinphoneRegistrationOk:
            print("registrationStateChanged -> LinphoneRegistrationOk -> \(stateMessage)")
        case LinphoneRegistrationCleared:
            print("registrationStateChanged -> LinphoneRegistrationCleared -> \(stateMessage)")
        case LinphoneRegistrationFailed:
            print("registrationStateChanged -> LinphoneRegistrationFailed -> \(stateMessage)")
        default:
            return
        }
        
        TDSipPluginManager.shared.streamHandler?.eventSink!(["eventName": "loginStatus", "loginStatus": NSNumber(value: state.rawValue)])
    }
    
    private func callStateChanged(lc: Optional<OpaquePointer>, call: Optional<OpaquePointer>, state: LinphoneCallState,  message: Optional<UnsafePointer<Int8>>) {
        lastLinphoneCallState = state;
        var stateMessage = ""
        if let message = message {
            stateMessage = String(cString: message)
        }
        switch state {
        case LinphoneCallStateIdle:
            print("callStateChanged -> LinphoneCallStateIdle -> \(stateMessage)")
        case LinphoneCallStateIncomingReceived:
            print("callStateChanged -> LinphoneCallStateIncomingReceived -> \(stateMessage)")
            
            ms_usleep(3 * 1000 * 1000); // Wait 3 seconds to pickup
            linphone_call_accept(call)
        case LinphoneCallStateOutgoingInit:
            print("callStateChanged -> LinphoneCallStateOutgoingInit -> \(stateMessage)")
        case LinphoneCallStateOutgoingProgress:
            print("callStateChanged -> LinphoneCallStateOutgoingProgress -> \(stateMessage)")
        case LinphoneCallStateOutgoingRinging:
            print("callStateChanged -> LinphoneCallStateOutgoingRinging -> \(stateMessage)")
        case LinphoneCallStateOutgoingEarlyMedia:
            print("callStateChanged -> LinphoneCallStateOutgoingEarlyMedia -> \(stateMessage)")
        case LinphoneCallStateConnected:
            print("callStateChanged -> LinphoneCallStateConnected -> \(stateMessage)")
        case LinphoneCallStateStreamsRunning:
            print("callStateChanged -> LinphoneCallStateStreamsRunning -> \(stateMessage)")
        case LinphoneCallStatePausing:
            print("callStateChanged -> LinphoneCallStatePausing -> \(stateMessage)")
        case LinphoneCallStatePaused:
            print("callStateChanged -> LinphoneCallStatePaused -> \(stateMessage)")
        case LinphoneCallStateResuming:
            print("callStateChanged -> LinphoneCallStateResuming -> \(stateMessage)")
        case LinphoneCallStateReferred:
            print("callStateChanged -> LinphoneCallStateReferred -> \(stateMessage)")
        case LinphoneCallStateError:
            print("callStateChanged -> LinphoneCallStateError -> \(stateMessage)")
        case LinphoneCallStateEnd:
            print("callStateChanged -> LinphoneCallStateEnd -> \(stateMessage)")
        case LinphoneCallStatePausedByRemote:
            print("callStateChanged -> LinphoneCallStatePausedByRemote -> \(stateMessage)")
        case LinphoneCallStateUpdatedByRemote:
            print("callStateChanged -> LinphoneCallStateUpdatedByRemote -> \(stateMessage)")
        case LinphoneCallStateIncomingEarlyMedia:
            print("callStateChanged -> LinphoneCallStateIncomingEarlyMedia -> \(stateMessage)")
        case LinphoneCallStateUpdating:
            print("callStateChanged -> LinphoneCallStateUpdating -> \(stateMessage)")
        case LinphoneCallStateReleased:
            print("callStateChanged -> LinphoneCallStateReleased -> \(stateMessage)")
        case LinphoneCallStateEarlyUpdatedByRemote:
            print("callStateChanged -> LinphoneCallStateEarlyUpdatedByRemote -> \(stateMessage)")
        case LinphoneCallStateEarlyUpdating:
            print("callStateChanged -> LinphoneCallStateEarlyUpdating -> \(stateMessage)")
        default:
            return
        }
        
        if(mCurrentAddress.isEmpty){
            mCurrentAddress = String(cString:linphone_call_get_remote_address_as_string(call));
        }
        
        if (state == LinphoneCallStateIncomingReceived || state == LinphoneCallStateOutgoingEarlyMedia) {
            linphone_call_enable_camera(linphoneCore, 0)
            if (!mCurrentAddress.isEmpty && !(String(cString:linphone_call_get_remote_address_as_string(call)).caseInsensitiveCompare(mCurrentAddress) == .orderedSame)) {
                let errorInfo = linphone_call_get_error_info(linphoneCore)
                linphone_error_info_set_protocol(errorInfo, "SIP")
                linphone_error_info_set_reason(errorInfo, LinphoneReasonForbidden)
                linphone_error_info_set_protocol_code(errorInfo, 403)
                linphone_error_info_set_phrase(errorInfo, "Another call is in progress")
                linphone_call_decline_with_error_info(call, errorInfo)
                linphone_core_terminate_all_calls(linphoneCore)
                return;
            }
            TDSipPluginManager.shared.streamHandler?.eventSink?(["eventName": "didReceiveCallForID","sipID":String(cString:linphone_address_get_username(linphone_call_get_remote_address(call)))])
        } else if (state == LinphoneCallStateOutgoingProgress) {
            linphone_call_enable_camera(linphoneCore, 0)
            TDSipPluginManager.shared.streamHandler?.eventSink?(["eventName": "didCallOut","sipID":nil])
        } else if (state == LinphoneCallStateStreamsRunning) {
            openAmplification(open:true)
            TDSipPluginManager.shared.streamHandler?.eventSink?(["eventName": "streamsDidBeginRunning","sipID":nil])
        } else if (stateMessage.contains("Another") ||
                   stateMessage.contains("declined") ||
                   stateMessage.contains("Busy")) {
            if (!(String(cString:linphone_call_get_remote_address_as_string(call)).caseInsensitiveCompare(mCurrentAddress) == .orderedSame)) {
                return;
            }
            mCurrentAddress = "";
            TDSipPluginManager.shared.streamHandler?.eventSink?(["eventName": "callBusy","sipID":nil])
        } else if (state == LinphoneCallStateReleased) {
            if (!(String(cString:linphone_call_get_remote_address_as_string(call)).caseInsensitiveCompare(mCurrentAddress) == .orderedSame)) {
                return;
            }
            mCurrentAddress = "";
            TDSipPluginManager.shared.streamHandler?.eventSink?(["eventName": "didCallEnd","sipID":nil])
        }
        
    }
    
    func initialize() {

        linphoneLoggingService = linphone_logging_service_get()        
        linphone_logging_service_set_log_level(linphoneLoggingService, LinphoneLogLevelFatal)
        
        let configFileName = documentFile("linphonerc")
        let factoryConfigFileName = bundleFile("linphonerc-factory")

        let configFileNamePtr: UnsafePointer<Int8> = configFileName.cString(using: String.Encoding.utf8.rawValue)!
        let factoryConfigFilenamePtr = UnsafeMutablePointer<Int8>(mutating: (factoryConfigFileName! as NSString).utf8String)
        
        let config = linphone_config_new_with_factory(configFileNamePtr, factoryConfigFilenamePtr)
        
        if let ring = bundleFile("notes_of_the_optimistic", "caf") {
            let unsafePointer = UnsafeMutablePointer<Int8>(mutating: (ring as NSString).utf8String)

            linphone_config_set_string(config, "sound", "local_ring", unsafePointer)
        }
        
        let factory = linphone_factory_get()
        let callBacks = linphone_factory_create_core_cbs(factory)
        linphone_core_cbs_set_registration_state_changed(callBacks, registrationStateChanged)
        linphone_core_cbs_set_call_state_changed(callBacks, callStateChanged)
        
        linphoneCore = linphone_factory_create_core_with_config_3(factory, config, nil)
        linphone_core_add_callbacks(linphoneCore, callBacks)
        linphone_core_start(linphoneCore)

        linphone_core_cbs_unref(callBacks)
        linphone_config_unref(config)
    }
    
    fileprivate func bundleFile(_ name: String, _ ext: String? = nil) -> String? {
        return Bundle.main.path(forResource: name, ofType: ext)
    }
    
    fileprivate func documentFile(_ file: NSString) -> NSString {
        let paths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        
        let documentsPath: NSString = paths[0] as NSString
        return documentsPath.appendingPathComponent(file as String) as NSString
    }
    
    
    func makeCall(calleeAccount:String){
        linphone_core_invite(linphoneCore, calleeAccount)
    }

    func logout(){
        linphone_core_terminate_all_calls(linphoneCore)
        linphone_core_clear_proxy_config(linphoneCore)
        linphone_core_clear_all_auth_info(linphoneCore)
    }

    
    func setIdentify(sipID:String,
                     sipPassword:String,
                     sipDomain:String,
                     sipPort:String,
                     sipTransport:String,
                     iceEnable:Bool,
                     turnEnable:Bool,
                     turnServer:String,
                     turnUser:String,
                     turnPassword:String,
                     proxy:String) -> OpaquePointer? {
        
        let identity = "sip:" + sipID + "@" + sipPassword + ":" + sipPort
            
        guard let temp_address = linphone_address_new(identity) else {
            print("\(identity) not a valid sip uri, must be like sip:toto@sip.linphone.org")
            return nil
        }
        
        let address = linphone_address_new(nil)
        linphone_address_set_username(address, linphone_address_get_username(temp_address))
        linphone_address_set_domain(address, linphone_address_get_domain(temp_address))
        linphone_address_set_port(address, linphone_address_get_port(temp_address))
        linphone_address_set_transport(address, linphone_address_get_transport(temp_address))
        
        let config = linphone_core_create_proxy_config(linphoneCore)
        linphone_proxy_config_set_identity_address(config, address)
        linphone_proxy_config_set_route(config, "\(sipDomain):\(sipPort)")
        linphone_proxy_config_set_server_addr(config, "\(proxy)")
        linphone_proxy_config_enable_register(config, 0)
        linphone_proxy_config_enable_publish(config, 0)
                
        linphone_core_add_proxy_config(linphoneCore, config)
        linphone_core_set_default_proxy_config(linphoneCore, config)
        
        let info = linphone_auth_info_new(sipID, nil, sipPassword, nil, nil, nil)
        linphone_core_add_auth_info(linphoneCore, info)
        
        linphone_proxy_config_unref(config)
        linphone_auth_info_unref(info)
        linphone_address_unref(address)
        
        return config
    }
    
    func register(_ proxy_cfg: OpaquePointer){
        linphone_proxy_config_enable_register(proxy_cfg, 1); /* activate registration for this proxy config*/
    }
    
    func acceptSip(){
        if (linphoneCore == nil) {
                    return;
                }
        let currentCall = linphone_core_get_current_call(linphoneCore);
        if (currentCall != nil) {
            let params = linphone_core_create_call_params(linphoneCore, currentCall);
            linphone_core_accept_call_with_params(linphoneCore, currentCall, params);
        }
    }
    
    func hangup(){
        if (linphoneCore == nil) {
                    return;
                }
        linphone_core_terminate_all_calls(linphoneCore);
    }
    func switchMic(open:Bool){
        if (linphoneCore == nil) {
                    return;
                }
        linphone_core_enable_mic(linphoneCore, open ? 1 : 0)
    }
    
    func openAmplification(open:Bool){
        do{
            // Get the audio session instance
            let session = AVAudioSession.sharedInstance()

            // Override the output port to speaker
            try session.overrideOutputAudioPort(.speaker)

            // Activate the session
            try session.setActive(open)
        }catch{
            return;
        }

    }

    
    @objc private func iterate(){
        if let linphoneCore = linphoneCore {
            linphone_core_iterate(linphoneCore); /* first iterate initiates registration */
        }
    }
    
    public func getLinphoneRegistrationState() -> LinphoneRegistrationState? {
        return lastLinphoneRegistrationState;
    }
    
    public func getLinphoneCallState() -> LinphoneCallState? {
        return lastLinphoneCallState;
    }
    public func setVideoView(viewId: Int64){
        let intPointer = UnsafeMutablePointer<Int64>.allocate (capacity: 1)
        intPointer.pointee = viewId
        intPointer.withMemoryRebound (to: UInt8.self, capacity: MemoryLayout<Int64>.size) { (pointer: UnsafeMutablePointer<UInt8>) in linphone_core_set_native_video_window_id(linphoneCore,UnsafeMutableRawPointer(pointer))
            linphone_core_enable_video_display (linphoneCore, 1)}
        
    }
}
