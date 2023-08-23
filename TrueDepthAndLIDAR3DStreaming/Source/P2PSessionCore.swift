//
//  P2PSessionCore.swift
//  
//
//  Created by KoheiOgawa on 2020/12/20.
//

//import Core
import Foundation
import MultipeerConnectivity

public enum SessionStatus{
    case SUCCESS;
    case FAILED;
    case RECONNECT;
}

public protocol P2PSessionCoreDelegate {
    func connectedDevicesChanged(manager : P2PSessionCore, connectedDevices: [String],sessionStatus:SessionStatus)
    func gestureControlReceiving(_ client: P2PSessionCore, didReceive message: Data)
}

public class P2PSessionCore : NSObject {

    // Service type must be a unique string, at most 15 characters long
    // and can contain only ASCII lowercase letters, numbers and hyphens.
    private let serviceType = "oga-oga"

    private let myPeerId = MCPeerID(displayName: UIDevice.current.name)
    private let serviceAdvertiser : MCNearbyServiceAdvertiser
    private let serviceBrowser : MCNearbyServiceBrowser

    public var delegate : P2PSessionCoreDelegate?
    private var sessionStatus:SessionStatus?
    
    lazy var session : MCSession = {
        let session = MCSession(peer: self.myPeerId, securityIdentity: nil, encryptionPreference: .optional)
        session.delegate = self
        return session
    }()

    public override init() {
        print(NSStringFromClass(type(of: self)),"の",#function,"メソッド")
        self.serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: serviceType)
        self.serviceBrowser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)

        super.init()

        self.serviceAdvertiser.delegate = self
        self.serviceAdvertiser.startAdvertisingPeer()

        self.serviceBrowser.delegate = self
        self.serviceBrowser.startBrowsingForPeers()
        sessionStatus = .FAILED
    }

    deinit {
        self.serviceAdvertiser.stopAdvertisingPeer()
        self.serviceBrowser.stopBrowsingForPeers()
    }
    

    public func sendData(_ data: Data, reliably: Bool = true) {
        NSLog("%@", "\(session.connectedPeers.count) peers")
    
        if session.connectedPeers.count > 0 {
            do{
                try self.session.send(data, toPeers: session.connectedPeers, with: .reliable)
                print("Send Data:", data)
            } catch let error {
                assertionFailure("Data failed to send: \(error.localizedDescription)")
            }
        }else{
            print("Not Connected...")
        }
    }

}

extension P2PSessionCore : MCNearbyServiceAdvertiserDelegate {

    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        NSLog("%@", "didNotStartAdvertisingPeer: \(error)")
    }

    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        NSLog("%@", "didReceiveInvitationFromPeer \(peerID)")
        invitationHandler(true, self.session)
    }

}

extension P2PSessionCore : MCNearbyServiceBrowserDelegate {

    public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        NSLog("%@", "didNotStartBrowsingForPeers: \(error)")
    }

    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        NSLog("%@", "foundPeer: \(peerID)")
        NSLog("%@", "invitePeer: \(peerID)")
        browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10)
    }

    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        NSLog("%@", "lostPeer: \(peerID)")
    }

}

extension P2PSessionCore : MCSessionDelegate {

    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        NSLog("%@", "peer \(peerID) didChangeState: \(state.rawValue)")
        print(NSStringFromClass(type(of: self)),"の",#function,"メソッド")
        if session.connectedPeers.count > 0 {
            sessionStatus = .SUCCESS
            self.delegate?.connectedDevicesChanged(manager: self, connectedDevices:
                                                    session.connectedPeers.map{$0.displayName},sessionStatus: sessionStatus!)
            print(session.connectedPeers.map{$0.displayName})
        }else{
            sessionStatus = .FAILED
        }
    }

    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        #if DEBUG
            print("%@", "didReceiveData: \(data)")
        #endif
        self.delegate?.gestureControlReceiving(self, didReceive: data)
    }

    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        NSLog("%@", "didReceiveStream")
    }

    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        NSLog("%@", "didStartReceivingResourceWithName")
    }

    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        NSLog("%@", "didFinishReceivingResourceWithName")
    }
    public func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        print("Not in connected state, so giving up for対策")
        sessionStatus = .RECONNECT
        certificateHandler(true)
    }
    

}
