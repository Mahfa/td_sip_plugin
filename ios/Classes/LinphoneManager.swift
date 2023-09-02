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
    
    public static var mCore: Core!
    
    var mRegistrationDelegate : CoreDelegate!
    
    var mCallStateDelegate : CoreDelegate!
    
    var loggedIn: Bool = false
    
    private var lastLinphoneRegistrationState: RegistrationState?
    private var mCurrentAddress : String = ""
    private static var iterateTimer: Timer?
    
    private override init() {
        
        
    }
    
    public func initialize(){
        LoggingService.Instance.logLevel = LogLevel.Debug
        
        try? LinphoneManager.mCore = Factory.Instance.createCore(configPath: "", factoryConfigPath: "", systemContext: nil)
        AudioRouteUtils.core = LinphoneManager.mCore
        try? LinphoneManager.mCore.start()
        
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
            
            
            print("callStateChanged -> \(state.rawValue) -> \(message)")
            
            if(self.mCurrentAddress.isEmpty){
                self.mCurrentAddress = ((call.remoteAddress?.asString()) ?? "");
            }
            
            if (state == Call.State.IncomingReceived || state == Call.State.OutgoingEarlyMedia) {
                call.cameraEnabled = false
                if (!self.mCurrentAddress.isEmpty && !(String(cString:call.remoteAddress!.asString()).caseInsensitiveCompare(self.mCurrentAddress) == .orderedSame)) {
                    call.errorInfo?.set(proto: "SIP", reason:Reason.Forbidden, code: 403, status: "Another call is in progress", warning: nil)
                    do{
                        try LinphoneManager.mCore.terminateAllCalls()
                    }catch{}
                    return;
                }
                TdSipPlugin.eventSink?(["eventName": "didReceiveCallForID","sipID":call.remoteAddress?.username,"phoneNumber" : call.remoteAddressAsString.split(separator: " ")[0].replacingOccurrences(of: "\"", with:"")])
            } else if (state == Call.State.OutgoingProgress) {
                TdSipPlugin.eventSink?(["eventName": "didCallOut","sipID":nil])
            } else if (state == Call.State.StreamsRunning) {
                TdSipPlugin.eventSink?(["eventName": "streamsDidBeginRunning","sipID":nil])
            } else if (message.contains("Another") ||
                       message.contains("declined") ||
                       message.contains("Busy")) {
                if (!(((call.remoteAddress?.asString()) ?? "").caseInsensitiveCompare(self.mCurrentAddress) == .orderedSame)) {
                    return;
                }
                self.mCurrentAddress = "";
                TdSipPlugin.eventSink?(["eventName": "callBusy","sipID":nil])
            } else if (state == Call.State.Released) {
                if (!(((call.remoteAddress?.asString()) ?? "").caseInsensitiveCompare(self.mCurrentAddress) == .orderedSame)) {
                    return;
                }
                self.mCurrentAddress = "";
                TdSipPlugin.eventSink?(["eventName": "didCallEnd","sipID":nil])
            }
            
        })
        
        
        LinphoneManager.mCore.addDelegate(delegate: mCallStateDelegate)
        LinphoneManager.mCore.addDelegate(delegate: mRegistrationDelegate)
        
    }
    
    
    func makeCall(calleeAccount:String){
        if(LinphoneManager.mCore != nil){
            LinphoneManager.mCore?.invite(url: calleeAccount)
        }
        
    }
    
    func logout(){
        unregister()
        delete()
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
            if(LinphoneManager.mCore.accountList.count > 0 && LinphoneManager.mCore.authInfoList[0].username == sipID){
                LinphoneManager.mCore.refreshRegisters();
                LinphoneManager.mCore.iterate();
            }else{
                for account in LinphoneManager.mCore.accountList{
                    LinphoneManager.mCore.removeAccount(account: account);
                }
                for info in LinphoneManager.mCore.authInfoList{
                    LinphoneManager.mCore.removeAuthInfo(info: info);
                }
                let authInfo = try Factory.Instance.createAuthInfo(username: sipID, userid: "", passwd: sipPassword, ha1: "", realm: "", domain: sipDomain)
                let accountParams = try LinphoneManager.mCore.createAccountParams()
                let identity = try Factory.Instance.createAddress(addr: String("sip:" + sipID + "@" + sipDomain))
                try! accountParams.setIdentityaddress(newValue: identity)
                let address = try Factory.Instance.createAddress(addr: String("sip:" + proxy))
                try address.setTransport(newValue: TransportType.Udp)
                try accountParams.setServeraddress(newValue: address)
                accountParams.registerEnabled = true
                accountParams.expires = 120
                let account = try LinphoneManager.mCore.createAccount(params: accountParams)
                LinphoneManager.mCore.addAuthInfo(info: authInfo)
                try LinphoneManager.mCore.addAccount(account: account)
                LinphoneManager.mCore.defaultAccount = account
            }
        } catch { NSLog(error.localizedDescription) }
        
    }
    
    func acceptSip(){
        if (LinphoneManager.mCore == nil) {
            return;
        }
        do{
            let currentCall = LinphoneManager.mCore.currentCall;
            if (currentCall != nil) {
                let params = try LinphoneManager.mCore.createCallParams(call: currentCall)
                try currentCall?.acceptWithParams(params: params)
            }
        }catch{}
    }
    
    func hangup(){
        if (LinphoneManager.mCore == nil) {
            return;
        }
        do{
            try LinphoneManager.mCore.terminateAllCalls()
        }catch{}
    }
    func switchMic(open:Bool){
        if (LinphoneManager.mCore == nil) {
            return;
        }
        LinphoneManager.mCore.micEnabled = open
    }
    
    public func routeAudioToEarpiece(){
        if (LinphoneManager.mCore == nil || LinphoneManager.mCore.currentCall == nil) {
            return;
        }
        AudioRouteUtils.routeAudioToEarpiece(call:LinphoneManager.mCore.currentCall)
    }
    public func routeAudioToSpeaker(){
        if (LinphoneManager.mCore == nil || LinphoneManager.mCore.currentCall == nil) {
            return;
        }
        AudioRouteUtils.routeAudioToSpeaker(call:LinphoneManager.mCore.currentCall)
    }
    public func routeAudioToBluetooth(){
        if (LinphoneManager.mCore == nil || LinphoneManager.mCore.currentCall == nil) {
            return;
        }
        AudioRouteUtils.routeAudioToBluetooth(call:LinphoneManager.mCore.currentCall)
    }
    public func routeAudioToHeadset(){
        if (LinphoneManager.mCore == nil || LinphoneManager.mCore.currentCall == nil) {
            return;
        }
        AudioRouteUtils.routeAudioToHeadset(call:LinphoneManager.mCore.currentCall)
    }
    
    
    public func getLinphoneRegistrationState() -> RegistrationState? {
        return lastLinphoneRegistrationState;
    }
    
    public func setVideoView(view : UIView){
        if (LinphoneManager.mCore == nil) {
            return;
        }
        LinphoneManager.mCore.nativeVideoWindow = view
        LinphoneManager.mCore.videoDisplayEnabled  = true
    }
    
    
    
    func unregister()
    {
        // Here we will disable the registration of our Account
        if let account = LinphoneManager.mCore.defaultAccount {
            
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
        if let account = LinphoneManager.mCore.defaultAccount {
            LinphoneManager.mCore.removeAccount(account: account)
            
            // To remove all accounts use
            LinphoneManager.mCore.clearAccounts()
            
            // Same for auth info
            LinphoneManager.mCore.clearAllAuthInfo()
        }
    }
    
}
