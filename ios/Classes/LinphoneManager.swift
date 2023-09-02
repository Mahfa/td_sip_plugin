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
    private var mCurrentAddress : String = ""
    private static var iterateTimer: Timer?
    
    private override init() {
        
        
    }
    
    public func initialize(){
        LoggingService.Instance.logLevel = LogLevel.Debug
        
        try? mCore = Factory.Instance.createCore(configPath: "", factoryConfigPath: "", systemContext: nil)
        AudioRouteUtils.core = mCore
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
            
            
            print("callStateChanged -> \(state.rawValue) -> \(message)")
            
            if(self.mCurrentAddress.isEmpty){
                self.mCurrentAddress = ((call.remoteAddress?.asString()) ?? "");
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
            if(mCore.accountList.count > 0 && mCore.authInfoList[0].username == sipID){
                mCore.refreshRegisters();
                mCore.iterate();
            }else{
                for account in mCore.accountList{
                    mCore.removeAccount(account: account);
                }
                for info in mCore.authInfoList{
                    mCore.removeAuthInfo(info: info);
                }
                let authInfo = try Factory.Instance.createAuthInfo(username: sipID, userid: "", passwd: sipPassword, ha1: "", realm: "", domain: sipDomain)
                let accountParams = try mCore.createAccountParams()
                let identity = try Factory.Instance.createAddress(addr: String("sip:" + sipID + "@" + sipDomain))
                try! accountParams.setIdentityaddress(newValue: identity)
                let address = try Factory.Instance.createAddress(addr: String("sip:" + proxy))
                try address.setTransport(newValue: TransportType.Udp)
                try accountParams.setServeraddress(newValue: address)
                accountParams.registerEnabled = true
                accountParams.expires = 120
                let account = try mCore.createAccount(params: accountParams)
                mCore.addAuthInfo(info: authInfo)
                try mCore.addAccount(account: account)
                mCore.defaultAccount = account
            }
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
    
    public func routeAudioToEarpiece(){
        if (mCore == nil || mCore.currentCall == nil) {
            return;
        }
        AudioRouteUtils.routeAudioToEarpiece(call:mCore.currentCall)
    }
    public func routeAudioToSpeaker(){
        if (mCore == nil || mCore.currentCall == nil) {
            return;
        }
        AudioRouteUtils.routeAudioToSpeaker(call:mCore.currentCall)
    }
    public func routeAudioToBluetooth(){
        if (mCore == nil || mCore.currentCall == nil) {
            return;
        }
        AudioRouteUtils.routeAudioToBluetooth(call:mCore.currentCall)
    }
    public func routeAudioToHeadset(){
        if (mCore == nil || mCore.currentCall == nil) {
            return;
        }
        AudioRouteUtils.routeAudioToHeadset(call:mCore.currentCall)
    }
    
    
    public func getLinphoneRegistrationState() -> RegistrationState? {
        return lastLinphoneRegistrationState;
    }
    
    public func setVideoView(view : UIView){
        if (mCore == nil) {
            return;
        }
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
