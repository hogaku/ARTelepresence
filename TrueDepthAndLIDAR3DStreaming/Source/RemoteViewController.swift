//
//  RemoteViewController.swift
//  TrueDepthAndLIDAR3DStreaming
//
//  Created by KoheiOgawa on 2020/12/20.
//  Copyright © 2020 Itty Bitty Apps Pty Ltd. All rights reserved.
//

import UIKit
import CoreVideo
import MobileCoreServices
import Accelerate
import ARKit

@available(iOS 11.1, *)
class RemoteViewController: UIViewController, ARSCNViewDelegate,ARSessionDelegate,P2PSessionControllerDelegate{
    func P2PsessionControllerDidUpdateConnectivity(_ sessionController: P2PSessionController,sessionStatus:SessionStatus) {
        #if DEBUG
            print(NSStringFromClass(type(of: self)),"の",#function,"メソッド")
            print("Sender-isConnected.")
        #endif

        switch  sessionStatus {
        case .SUCCESS:
            connectionStatusIconView.backgroundColor = UIColor(hex: "69A982") // 緑
        case .FAILED:
            connectionStatusIconView.backgroundColor = UIColor(hex: "C91E57") // 赤
        case .RECONNECT:
            connectionStatusIconView.backgroundColor = UIColor(hex: "F0A254") // 緑
        default:
            connectionStatusIconView.backgroundColor = UIColor(hex: "C91E57") // 赤
        }
    }
    
    func P2PsessionControllerData(_ sessionController: P2PSessionController, didUpdate receivedData: Data) {
        #if DEBUG
            print("Not Used.")
        #endif
    }
    
    // MARK: - Propertiesd
    private var statusBarOrientation: UIInterfaceOrientation = .portrait // 縦向き
    @IBOutlet weak var cloudView: PointCloudMetalView!
    
    @IBOutlet weak var connectionLabel: UILabel!
    @IBOutlet weak var connectionStatusIconView: UIView!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var lastXYLabel: UILabel!
    @IBOutlet weak var lastScaleLabel: UILabel!
    @IBOutlet weak var lastRotateLabel: UILabel!
    private let lastXYLabelDiscription:String = "(x, y) = "
    private let lastScaleLabelDiscription:String = "Scale = "
    private let lastRotateLabelDiscription:String = "Rotate = "
    private var lastScale = Float(2.0)
    private var lastScaleDiff:Float = Float(0.0)
    private var lastZoom:Float = Float(0.0)
    private var gestureState:String = String.init()
    private var gestureControlData:GestureControlData = GestureControlData(gestureState: Int(0), pntXY: CGPoint(x: 0, y: 0), scale: Float(2.0), rotate: Float(0.0), reset: Int(0))!
        
    private var intimatrix:matrix_float3x3 = matrix_float3x3.init()
    private var imrdref:CGSize = CGSize.init()
    
    private var arSession:ARSession!
    private var p2pSessionController: P2PSessionController!
    
    enum cameraMode {
        case TrueDepth;
        case LIDARSensor;
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        print(NSStringFromClass(type(of: self)),"の",#function,"メソッド")
        // Do any additional setup after loading the view.
        self.p2pSessionController = P2PSessionController()
        self.p2pSessionController.delegate = self

        // ピンチジェスチャーのイベントハンドラーを定義
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        cloudView.addGestureRecognizer(pinchGesture)
        
        // ダブルタップジェスチャーのイベントハンドラーを定義
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTapGesture.numberOfTapsRequired = 2 // タップ数を指定、2はダブルタップ
        doubleTapGesture.numberOfTouchesRequired = 1 // 最低1タップ検出されないと機能しない
        cloudView.addGestureRecognizer(doubleTapGesture)
        
        // 回転ジェスチャーのイベントハンドラーを定義
        let rotateGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotate))
        cloudView.addGestureRecognizer(rotateGesture)
        
        // パン(移動)ジェスチャーのイベントハンドラーを定義
        let panOneFingerGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanOneFinger))
        panOneFingerGesture.maximumNumberOfTouches = 1 // ビューに触れて認識できる最大の指の数の指定
        panOneFingerGesture.minimumNumberOfTouches = 1 // ビューに触れて認識できる最小の指の数の指定
        cloudView.addGestureRecognizer(panOneFingerGesture)
    }
    
    // viewが表示される直前に呼ばれれるメソッド
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        
        let interfaceOrientation = UIApplication.shared.statusBarOrientation // ステータスバーの向き(アプリの向き)を取得
        statusBarOrientation = interfaceOrientation
        
        let initialThermalState = ProcessInfo.processInfo.thermalState // システムの熱状態を示すために使用される値
        if initialThermalState == .serious || initialThermalState == .critical {
            showThermalState(state: initialThermalState)
        }
        
        lastXYLabel.text = lastXYLabelDiscription + "(" + gestureControlData.pntX.description + ", " + gestureControlData.pntY.description + ")"
        lastScaleLabel.text = lastScaleLabelDiscription + gestureControlData.scale.description
        lastRotateLabel.text = lastRotateLabelDiscription + gestureControlData.rotate.description
    }
    
    // viewが表示されなくなるときに呼ばれる。レンダリングやセッションの停止処理を行う。
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewWillLayoutSubviews() {
        // デバイスサイズに応じてviewのサイズを変更
        let deviceBoundsSize: CGSize = UIScreen.main.bounds.size
        let headerH:CGFloat = 75
        cloudView.frame.size.width = deviceBoundsSize.width
        cloudView.frame.size.height = deviceBoundsSize.height
        
        backButton.frame.origin.x = 25
        backButton.frame.origin.y = headerH
        
        connectionStatusIconView.backgroundColor = UIColor(hex: "C91E57") // 赤
        connectionLabel.frame.origin.x = cloudView.frame.size.width - connectionLabel.frame.width*2 + connectionStatusIconView.frame.width
        connectionLabel.frame.origin.y = headerH
        connectionStatusIconView.frame.origin.x = connectionLabel.frame.origin.x + connectionLabel.frame.width + connectionStatusIconView.frame.width/2
        connectionStatusIconView.frame.origin.y = headerH
        
        connectionStatusIconView.layer.cornerRadius = connectionStatusIconView.frame.height / 2
    }
    
    @objc
    func didEnterBackground(notification: NSNotification) {
    }
    
    @objc
    func willEnterForground(notification: NSNotification) {
    }
    
    // You can use this opportunity to take corrective action to help cool the system down.
    @objc
    func thermalStateChanged(notification: NSNotification) {
        if let processInfo = notification.object as? ProcessInfo {
            showThermalState(state: processInfo.thermalState)
        }
    }
    
    // システムの熱状態を示すメソッド
    func showThermalState(state: ProcessInfo.ThermalState) {
        DispatchQueue.main.async {
            var thermalStateString = "UNKNOWN"
            if state == .nominal {
                thermalStateString = "NOMINAL"
            } else if state == .fair {
                thermalStateString = "FAIR"
            } else if state == .serious {
                thermalStateString = "SERIOUS"
            } else if state == .critical {
                thermalStateString = "CRITICAL"
            }
            
            let message = NSLocalizedString("Thermal state: \(thermalStateString)", comment: "Alert message when thermal state has changed")
            let alertController = UIAlertController(title: "TrueDepthStreamer", message: message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
            self.present(alertController, animated: true, completion: nil)
        }
    }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }
    
    // mtkviewサイズが変更されようとしているとき
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
    }
    
    // MARK: - KVO and Notifications
    
    private var sessionRunningContext = 0
    // 通知
    private func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForground),
                                               name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(thermalStateChanged),
                                               name: ProcessInfo.thermalStateDidChangeNotification,    object: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if context != &sessionRunningContext {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }


    @IBAction func backButton_TouchUp(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Point cloud view gestures
    // ピッチイベントハンドラ
    @IBAction private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        if gesture.numberOfTouches != 2 {
            return
        }
        if gesture.state == .began {
            gestureControlData.scale = 1
            gestureControlData.gestureState = gesture.state.rawValue
        } else if gesture.state == .changed {
            let scale = Float(gesture.scale)
            gestureControlData.gestureState = gesture.state.rawValue
            gestureControlData.scale = scale
            lastScaleLabel.text = lastScaleLabelDiscription + gestureControlData.scale.description
        } else if gesture.state == .ended {
            gestureControlData.gestureState = gesture.state.rawValue
        } else {
        }
        self.p2pSessionController.sendGesturesData(gestures: gestureControlData)
        gestureControlData.reset = 0
        
        #if DEBUG
            print("gestureControlData.gestureState:",gestureControlData.gestureState.description)
            print("gestureControlData.lastScale:",gestureControlData.scale.description)
        #endif
    }
    // パンイベントハンドラ
    @IBAction private func handlePanOneFinger(gesture: UIPanGestureRecognizer) {
        if gesture.numberOfTouches != 1 {
            return
        }
        
        if gesture.state == .began {
            let pnt: CGPoint = gesture.translation(in: cloudView)
            gestureControlData.pntX = Float(pnt.x)
            gestureControlData.pntY = Float(pnt.y)
            gestureControlData.gestureState = gesture.state.rawValue
        } else if (.failed != gesture.state) && (.cancelled != gesture.state) {
            let pnt: CGPoint = gesture.translation(in: cloudView)

            gestureControlData.pntX = Float(pnt.x)
            gestureControlData.pntY = Float(pnt.y)
            gestureControlData.gestureState = gesture.state.rawValue
            
        }
        self.p2pSessionController.sendGesturesData(gestures: gestureControlData)
        gestureControlData.reset = 0
        lastXYLabel.text = lastXYLabelDiscription + "(" + gestureControlData.pntX.description + ", " + gestureControlData.pntY.description + ")"
        
        #if DEBUG
            print("gestureControlData.gestureState:",gestureControlData.gestureState.description)
            print("gestureControlData.lastX:",gestureControlData.pntX.description)
            print("gestureControlData.lastY:",gestureControlData.pntY.description)
        #endif
    }
    // ダブルタップイベントハンドラ
    @IBAction private func handleDoubleTap(gesture: UITapGestureRecognizer) {
        gestureControlData.reset = 1
        self.p2pSessionController.sendGesturesData(gestures: gestureControlData)
        
        #if DEBUG
            print("gestureControlData.reset:",gestureControlData.reset)
        #endif
    }
    // 回転イベントハンドラ
    @IBAction private func handleRotate(gesture: UIRotationGestureRecognizer) {
        if gesture.numberOfTouches != 2 {
            return
        }
        
        if gesture.state == .changed {
            let rot = Float(gesture.rotation)
            gestureControlData.rotate = rot
            self.p2pSessionController.sendGesturesData(gestures: gestureControlData)
            lastRotateLabel.text = lastRotateLabelDiscription + gestureControlData.rotate.description
            gesture.rotation = 0
            gestureControlData.reset = 0
            gestureControlData.rotate = Float(gesture.rotation)
            gestureControlData.gestureState = gesture.state.rawValue
            
        }
        
        #if DEBUG
            print("gestureControlData.gestureState:",gestureControlData.gestureState.description)
            print("gestureControlData.rotate:",gestureControlData.rotate.description)
        #endif
    }
}
