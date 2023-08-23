//
//  P2PSessionController.swift
//  TrueDepthAndLIDAR3DStreaming
//
//  Created by KoheiOgawa on 2020/12/22.
//  Copyright © 2020 Itty Bitty Apps Pty Ltd. All rights reserved.
//

import Foundation


public protocol P2PSessionControllerDelegate: class {
    func P2PsessionControllerDidUpdateConnectivity(_ sessionController: P2PSessionController, sessionStatus:SessionStatus)
    func P2PsessionControllerData(_ sessionController: P2PSessionController, didUpdate receivedData: Data)
}

public final class P2PSessionController: NSObject,P2PSessionCoreDelegate {

    
    public func connectedDevicesChanged(manager: P2PSessionCore, connectedDevices: [String],sessionStatus:SessionStatus) {
        #if DEBUG
            print(NSStringFromClass(type(of: self)),"の",#function,"メソッド")
        #endif
        DispatchQueue.main.async { [self] in
            self.delegate?.P2PsessionControllerDidUpdateConnectivity(self, sessionStatus: sessionStatus)
        }
    }
    
    public func gestureControlReceiving(_ client: P2PSessionCore, didReceive message: Data) {
        DispatchQueue.main.async {
            self.delegate?.P2PsessionControllerData(self, didUpdate: message)
        }
    }
    
    
    private var sessionStatusLabel:String = ""
    public weak var delegate: P2PSessionControllerDelegate?
    private let sessionCore = P2PSessionCore()
    public override init() {
        #if DEBUG
            print(NSStringFromClass(type(of: self)),"の",#function,"メソッド")
        #endif
        
        super.init()
        sessionCore.delegate = self
        
    }
    
    public func sendGesturesData(gestures:GestureControlData){
        #if DEBUG
            print("start sending...")
        #endif
        
        guard let gesturesValue = try? NSKeyedArchiver.archivedData(withRootObject: gestures, requiringSecureCoding: true)
        else { fatalError("can't encode anchor") }
        
        self.sessionCore.sendData(gesturesValue)
        
        #if DEBUG
            print("end sending.")
        #endif
    }
    
}
