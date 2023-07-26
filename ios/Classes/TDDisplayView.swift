// TDDisplayView.swift

import Foundation
import Flutter
#import "UIImageView+WebCache.h";

class TDDisplayView: NSObject, FlutterPlatformView {
    private var displayView: UIImageView?
    private var frame: CGRect

    init(frame: CGRect, viewId: Int64, args: Any?, binaryMessenger messenger: FlutterBinaryMessenger) {
        self.frame = frame
        super.init()
        self.displayView = UIImageView(frame: frame)
        self.displayView?.backgroundColor = UIColor.black
        LinphoneManager.shared.setVideoView(displayView:self.displayView!)
    }

    func view() -> UIView {
        return self.displayView ?? UIView()
    }
}

class TDDisplayViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return TDDisplayView(frame: frame, viewId: viewId, args: args, binaryMessenger: messenger)
    }

    func createArgsCodec() -> FlutterMessageCodec {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
