//
//  LinphoneManager.swift
//  linphone-swift-demo
//
//  Created by Hamza Öztürk on 25.12.2019.
//  Copyright © 2019 Busoft. All rights reserved.
//

import Foundation
import AVFoundation
import linphonesw

class LinphoneManager: NSObject {
    
    static let shared = LinphoneManager()
    
    var mCore: Core!
    
    var mRegistrationDelegate : CoreDelegate!
    
    var mCallStateDelegate : CoreDelegate!
    
    var loggedIn: Bool = false
    
    private var lastLinphoneRegistrationState: RegistrationState?
    private var lastLinphoneCallState: Call.State?
    private var mCurrentAddress : String = ""
    private static var iterateTimer: Timer?
    
    private override init() {
        
        
    }
    
    public func initialize(){
        LoggingService.Instance.logLevel = LogLevel.Debug
        
        try? mCore = Factory.Instance.createCore(configPath: "", factoryConfigPath: "", systemContext: nil)
        try? mCore.start()
        
        mRegistrationDelegate = CoreDelegateStub(onAccountRegistrationStateChanged: { (core: Core, account: Account, state: RegistrationState, message: String) in
            
            self.lastLinphoneRegistrationState = state;
            
            switch state{
            case RegistrationState.None:
                print("registrationStateChanged -> LinphoneRegistrationNone -> \(String(cString: message))")
            case RegistrationState.Progress:
                print("registrationStateChanged -> LinphoneRegistrationProgress -> \(String(cString: message))")
            case RegistrationState.Ok:
                print("registrationStateChanged -> LinphoneRegistrationOk -> \(String(cString: message))")
            case RegistrationState.Cleared:
                print("registrationStateChanged -> LinphoneRegistrationCleared -> \(String(cString: message))")
            case RegistrationState.Failed:
                print("registrationStateChanged -> LinphoneRegistrationFailed -> \(String(cString: message))")
            default:
                return
            }
            
            TdSipPlugin.eventSink!(["eventName": "loginStatus", "loginStatus": NSNumber(value: state.rawValue)])
            
        })
        
        mCallStateDelegate = CoreDelegateStub(onCallStateChanged: { (core:Core, call:Call, state:Call.State, message:String) in
            self.lastLinphoneCallState = state;
            
            
            print("callStateChanged -> \(state.rawValue) -> \(message)")
            
            if(self.mCurrentAddress.isEmpty){
                self.mCurrentAddress = String(cString:(call.remoteAddress?.asString())!);
            }
            
            if (state == Call.State.IncomingReceived || state == Call.State.OutgoingEarlyMedia) {
                call.cameraEnabled = false
                if (!self.mCurrentAddress.isEmpty && !(String(cString:call.remoteAddress!.asString()).caseInsensitiveCompare(self.mCurrentAddress) == .orderedSame)) {
                    call.errorInfo?.set(proto: "SIP", reason:Reason.Forbidden, code: 403, status: "Another call is in progress", warning: nil)
                    do{
                        try self.mCore.terminateAllCalls()
                    }catch{}
                    return;
                }
                TdSipPlugin.eventSink?(["eventName": "didReceiveCallForID","sipID":call.remoteAddress?.username])
            } else if (state == Call.State.OutgoingProgress) {
                call.cameraEnabled = false;
                TdSipPlugin.eventSink?(["eventName": "didCallOut","sipID":nil])
            } else if (state == Call.State.StreamsRunning) {
                self.openAmplification(open:true)
                TdSipPlugin.eventSink?(["eventName": "streamsDidBeginRunning","sipID":nil])
            } else if (message.contains("Another") ||
                       message.contains("declined") ||
                       message.contains("Busy")) {
                if (!(call.remoteAddressAsString.caseInsensitiveCompare(self.mCurrentAddress) == .orderedSame)) {
                    return;
                }
                self.mCurrentAddress = "";
                TdSipPlugin.eventSink?(["eventName": "callBusy","sipID":nil])
            } else if (state == Call.State.Released) {
                if (!(call.remoteAddressAsString.caseInsensitiveCompare(self.mCurrentAddress) == .orderedSame)) {
                    return;
                }
                self.mCurrentAddress = "";
                TdSipPlugin.eventSink?(["eventName": "didCallEnd","sipID":nil])
            }
            
        })
        
        
        mCore.addDelegate(delegate: mCallStateDelegate)
        mCore.addDelegate(delegate: mRegistrationDelegate)
        
    }
    
    
    func makeCall(calleeAccount:String){
        mCore.invite(url: calleeAccount)
    }
    
    func logout(){
        do{
            try mCore.terminateAllCalls()
            mCore.clearProxyConfig()
            mCore.clearAllAuthInfo()
        }catch{}
    }
    
    
    func register(sipID:String,
                  sipPassword:String,
                  sipDomain:String,
                  sipPort:String,
                  sipTransport:String,
                  iceEnable:Bool,
                  turnEnable:Bool,
                  turnServer:String,
                  turnUser:String,
                  turnPassword:String,
                  proxy:String) {
        
        
        do {
            
            var transport : TransportType = TransportType.Udp
            
            let authInfo = try Factory.Instance.createAuthInfo(username: sipID, userid: "", passwd: sipPassword, ha1: "", realm: "", domain: sipDomain)
            let accountParams = try mCore.createAccountParams()
            
            // A SIP account is identified by an identity address that we can construct from the username and domain
            let identity1 = try Factory.Instance.createAddress(addr: String("sip:" + sipID + "@" + sipDomain))
            try! accountParams.setIdentityaddress(newValue: identity1)
            
            // We also need to configure where the proxy server is located
            let address = try Factory.Instance.createAddress(addr: String("sip:" + proxy))
            
            // We use the Address object to easily set the transport protocol
            try address.setTransport(newValue: transport)
            try accountParams.setServeraddress(newValue: address)
            // And we ensure the account will start the registration process
            accountParams.registerEnabled = true
            
            // Now that our AccountParams is configured, we can create the Account object
            let account = try mCore.createAccount(params: accountParams)
            
            // Now let's add our objects to the Core
            mCore.addAuthInfo(info: authInfo)
            try mCore.addAccount(account: account)
            
            // Also set the newly added account as default
            mCore.defaultAccount = account
            
            
            
            let identity = "sip:" + sipID + "@" + sipPassword + ":" + sipPort
            
            guard let address = try? mCore.createAddress(address: identity) else {
                print("\(identity) not a valid sip uri, must be like sip:toto@sip.linphone.org")
                return
            }
            
            let config = try mCore.createProxyConfig()
            try config.setIdentityaddress(newValue: address)
            try config.setRoute(newValue: "\(sipDomain):\(sipPort)")
            try config.setServeraddr(newValue: "\(proxy)")
            config.registerEnabled = false
            config.publishEnabled = false
            
            // Now let's add our objects to the Core
            mCore.addAuthInfo(info: authInfo)
            try mCore.addAccount(account: account)
            
            // Also set the newly added account as default
            mCore.defaultAccount = account
            
            try mCore.addProxyConfig(config:config)
            mCore.defaultProxyConfig = config
            
        } catch { NSLog(error.localizedDescription) }
    }
    
    func acceptSip(){
        if (mCore == nil) {
            return;
        }
        do{
            let currentCall = mCore.currentCall;
            if (currentCall != nil) {
                let params = try mCore.createCallParams(call: currentCall)
                try currentCall?.acceptWithParams(params: params)
            }
        }catch{}
    }
    
    func hangup(){
        if (mCore == nil) {
            return;
        }
        do{
            try mCore.terminateAllCalls()
        }catch{}
    }
    func switchMic(open:Bool){
        if (mCore == nil) {
            return;
        }
        mCore.micEnabled = open
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
    
    
    public func getLinphoneRegistrationState() -> RegistrationState? {
        return lastLinphoneRegistrationState;
    }
    
    public func getLinphoneCallState() -> Call.State? {
        return lastLinphoneCallState;
    }
    public func setVideoView(view : UIView){
        mCore.nativeVideoWindow = view
        mCore.videoDisplayEnabled  = true
    }
    
    
    
    func unregister()
    {
        // Here we will disable the registration of our Account
        if let account = mCore.defaultAccount {
            
            let params = account.params
            // Returned params object is const, so to make changes we first need to clone it
            let clonedParams = params?.clone()
            
            // Now let's make our changes
            clonedParams?.registerEnabled = false
            
            // And apply them
            account.params = clonedParams
        }
    }
    func delete() {
        // To completely remove an Account
        if let account = mCore.defaultAccount {
            mCore.removeAccount(account: account)
            
            // To remove all accounts use
            mCore.clearAccounts()
            
            // Same for auth info
            mCore.clearAllAuthInfo()
        }
    }
    
}
