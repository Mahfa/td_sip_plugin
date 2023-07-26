// TDSipPluginManager.swift

import Foundation
import Flutter

class TDSipPluginManager {
    static let shared = TDSipPluginManager()
    var streamHandler: TDSipPluginStreamHandler?
}

class TDSipPluginStreamHandler: NSObject, FlutterStreamHandler {
    var eventSink: FlutterEventSink?
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }
}

