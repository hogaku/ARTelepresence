/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Contains view controller code for previewing live-captured content.
*/

import UIKit
import CoreVideo
import MobileCoreServices
import Accelerate
import ARKit
//import Foundation


@available(iOS 11.1, *)
class CameraViewController: UIViewController, ARSCNViewDelegate,ARSessionDelegate,P2PSessionControllerDelegate{
    func P2PsessionControllerDidUpdateConnectivity(_ sessionController: P2PSessionController,sessionStatus:SessionStatus) {
        #if DEBUG
            print(NSStringFromClass(type(of: self)),"の",#function,"メソッド")
            print("Receiver-isConnected")
        #endif
    }
    
    func P2PsessionControllerData(_ sessionController: P2PSessionController, didUpdate receivedData: Data) {
        #if DEBUG
            print(NSStringFromClass(type(of: self)),"の",#function,"メソッド")
        #endif
        do {
            if let receivedGestures = try NSKeyedUnarchiver.unarchivedObject(ofClass: GestureControlData.self, from: receivedData) {
                receivedGestureState = receivedGestures.gestureState
                receivedLastXY = CGPoint.init(x: CGFloat(receivedGestures.pntX), y: CGFloat(receivedGestures.pntY))
                receivedScale = receivedGestures.scale
                receivedRotate = receivedGestures.rotate
                receivedReset = receivedGestures.reset
                
                #if DEBUG
                    print("　　receivedGestureState:",receivedGestureState)
                    print("　　receivedLastX:",receivedLastXY.x)
                    print("　　receivedLastY:",receivedLastXY.y)
                    print("　　receivedScale:",receivedScale)
                    print("　　receivedRotate:",receivedRotate)
                    print("　　receivedReset:",receivedReset)
                #endif
                
                if receivedGestureState == 1{ // 1:began
                    print(receivedGestureState,":receivedGestureState")
                    print("!!!!!!!!!!!!!")
                    let pnt: CGPoint = receivedLastXY
                    lastXY = pnt
                }else if (receivedGestureState != 5) && (receivedGestureState != 4){ // 5:failed, 4:cancelled
                    let pnt: CGPoint = receivedLastXY
                    cloudView.yawAroundCenter(angle: Float((pnt.x - lastXY.x) * 0.1))
                    cloudView.pitchAroundCenter(angle: Float((pnt.y - lastXY.y) * 0.1))
                    lastXY = pnt
                }
                
                if receivedGestureState == 2 { // 2:changed
                    // Scale処理
                    let scale:Float = receivedScale
                    let diff: Float = scale - lastScale
                    let factor: Float = 1e3
                    if scale < lastScale {
                        lastZoom = diff * factor
                    } else {
                        lastZoom = diff * factor
                    }
                    cloudView.moveTowardCenter(scale: lastZoom)
                    lastScale = scale
                    
                    // Rotate処理
                    let rot = receivedRotate
                    cloudView.rollAroundCenter(angle: rot * 60)
                    receivedRotate = 0
                    
                }else if receivedGestureState == 3 { // 3:ended
                    // 何もしない
                }
                
                // Reset処理
                if receivedReset == 1 {
                    cloudView.resetView()
                }
            }
            else {
                print("Receiver-unknown data recieved from peer")
            }
        } catch {
            print("Receiver-can't decode data recieved from peer")
        }
    }


    // MARK: - Propertiesd
    private var statusBarOrientation: UIInterfaceOrientation = .portrait // 縦向き
    
    @IBOutlet weak var cameraModeControl: UISegmentedControl!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var cloudView: PointCloudMetalView!
    
    private var lastScale = Float(2.0)
    private var lastScaleDiff = Float(0.0)
    private var lastZoom = Float(0.0)
    private var lastXY = CGPoint(x: 0, y: 0)
    
    private var intimatrix:matrix_float3x3 = matrix_float3x3.init()
    private var imrdref:CGSize = CGSize.init()
    var arSession:ARSession!
    
    // 通信部分に関する変数
    private var p2pSessionController:P2PSessionController!
    public var receivedGestureState:Int = Int(0)
    public var receivedLastXY:CGPoint = CGPoint.init(x: 0.0, y: 0.0)
    public var receivedScale:Float = Float.init()
    public var receivedRotate:Float = Float.init()
    public var receivedReset:Int = Int(0)
    
    enum cameraMode {
        case TrueDepth;
        case LIDARSensor;
    }
    private var camMode:cameraMode = .TrueDepth
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
        
        cloudView.resetView() // viewの位置を初期値(0,0,0)に戻す(metalで並列で処理.詳細は、PointCloudMetalView.swift)
        
    }

    // viewが表示される直前に呼ばれれるメソッド
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // ARSessionの設定
        arSession = ARSession()
        arSession.delegate = self
        cameraModeControl.selectedSegmentIndex = 0
        switch camMode{
            case .TrueDepth:
                #if DEBUG
                    print("TrueDepthセンサーを使用.")
                #endif
                arSession.run(.makeTrueDepthConfiguration())
            case .LIDARSensor:
                #if DEBUG
                    print("LIDARセンサーを使用.")
                #endif
                arSession.run(.makeLIDARConfiguration())
        }
        let interfaceOrientation = UIApplication.shared.statusBarOrientation // ステータスバーの向き(アプリの向き)を取得
        statusBarOrientation = interfaceOrientation
        
        let initialThermalState = ProcessInfo.processInfo.thermalState // システムの熱状態を示すために使用される値
        if initialThermalState == .serious || initialThermalState == .critical {
            showThermalState(state: initialThermalState)
        }
    }
    
    override func viewWillLayoutSubviews() {
        // デバイスサイズに応じてviewのサイズを変更
        let deviceBoundsSize: CGSize = UIScreen.main.bounds.size
        
        cloudView.frame.size.width = deviceBoundsSize.width
        cloudView.frame.size.height = deviceBoundsSize.height
        
        backButton.frame.origin.x = 25
        backButton.frame.origin.y = 75
        
        cameraModeControl.frame.origin.x = cloudView.frame.size.width/2 - cameraModeControl.frame.width/2
        cameraModeControl.frame.origin.y = 75
    }
    // viewが表示されなくなるときに呼ばれる。レンダリングやセッションの停止処理を行う。
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arSession.pause()
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
                                               name: ProcessInfo.thermalStateDidChangeNotification,	object: nil)
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
            lastScale = 1
        } else if gesture.state == .changed {
            let scale = Float(gesture.scale)    
            let diff: Float = scale - lastScale
            let factor: Float = 1e3
            if scale < lastScale {
                lastZoom = diff * factor
            } else {
                lastZoom = diff * factor
            }
            cloudView.moveTowardCenter(scale: lastZoom)
            lastScale = scale
        } else if gesture.state == .ended {
        } else {
        }
    }
    // パンイベントハンドラ
    @IBAction private func handlePanOneFinger(gesture: UIPanGestureRecognizer) {
        if gesture.numberOfTouches != 1 {
            return
        }
        
        if gesture.state == .began{
            let pnt: CGPoint = gesture.translation(in: cloudView)
            lastXY = pnt
        } else if (.failed != gesture.state) && (.cancelled != gesture.state) {
            let pnt: CGPoint = gesture.translation(in: cloudView)
            cloudView.yawAroundCenter(angle: Float((pnt.x - lastXY.x) * 0.1))
            cloudView.pitchAroundCenter(angle: Float((pnt.y - lastXY.y) * 0.1))
            lastXY = pnt
        }
    }
    // ダブルタップイベントハンドラ
    @IBAction private func handleDoubleTap(gesture: UITapGestureRecognizer) {
        cloudView.resetView() // viewの位置を初期値(0,0,0)に戻す(metalで並列で処理.詳細は、PointCloudMetalView.swift)
    }
    // 回転イベントハンドラ
    @IBAction private func handleRotate(gesture: UIRotationGestureRecognizer) {
        if gesture.numberOfTouches != 2 {
            return
        }
        
        if gesture.state == .changed {
            let rot = Float(gesture.rotation)
            cloudView.rollAroundCenter(angle: rot * 60)
            gesture.rotation = 0
        }
    }

    
    @IBAction func cameraModeChange(_ sender: Any) {
        print("cameraModeControl.selectedSegmentIndex:",cameraModeControl.selectedSegmentIndex)
        if cameraModeControl.selectedSegmentIndex == 0 { // 0: TrueDepth
            camMode = .TrueDepth
        }else {
            camMode = .LIDARSensor
        }
        switch camMode{
            case .TrueDepth:
                #if DEBUG
                    print("TrueDepthセンサーを使用.")
                #endif
                
                arSession.run(.makeTrueDepthConfiguration())
            case .LIDARSensor:
                #if DEBUG
                    print("LIDARセンサーを使用.")
                #endif
                
                arSession.run(.makeLIDARConfiguration())
        }

    }
    
    // UIImageからCVPixelBufferに変換
    func buffer(from image: UIImage, pixelFormat: OSType) -> CVPixelBuffer? {
      let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
      var pixelBuffer : CVPixelBuffer?
      let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.size.width), Int(image.size.height), pixelFormat, attrs, &pixelBuffer)
        
      guard (status == kCVReturnSuccess) else {
        return nil
      }

      CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
      let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)

      let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
      let context = CGContext(data: pixelData, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

      context?.translateBy(x: 0, y: image.size.height)
      context?.scaleBy(x: 1.0, y: -1.0)

      UIGraphicsPushContext(context!)
      image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
      UIGraphicsPopContext()
      CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

      return pixelBuffer
    }
    public func CVPixelBuffer2UIImage(pixelBuffer: CVPixelBuffer)->UIImage{
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let w = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let h = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let rect:CGRect = CGRect.init(x: 0, y: 0, width: w, height: h)
        let context = CIContext.init()
        guard let cgImage = context.createCGImage(ciImage, from: rect) else { return UIImage.init() }
        
        return UIImage.init(cgImage: cgImage)
        
    }
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Depth画像とColor画像の生値を取得
        let depthData = frame.capturedDepthData
        let colorData = try! frame.capturedImage

        if colorData == nil {
            return
        }
        let bgra32ColorData = try!colorData.toBGRA()?.copyToMetalCompatible()
        
        // 変換前と変換後のピクセルフォーマットの内容の確認
        #if DEBUG
            print("生のカラー画像:",CVPixelBufferGetPixelFormatType(colorData)) //CV420YpCbCr8BiPlanarFullRange
            print("変換後のカラー画像:",CVPixelBufferGetPixelFormatType(bgra32ColorData!)) //CV32BGRA
        #endif
        
        // TrueDepthの場合
        // 取得フレームレートが異なるため、タイミングがあったときのみ処理
        if camMode == .TrueDepth && depthData == nil{
            #if DEBUG
                print("camMode:",camMode)
                print("depthData:",depthData)
            #endif
            return
        }else if depthData != nil{
            #if DEBUG
                print("camMode:",camMode)
                print("depthData:",depthData)
                print("生の深度画像:",CVPixelBufferGetPixelFormatType(depthData!.depthDataMap))
            #endif
            
            intimatrix = (depthData?.cameraCalibrationData!.intrinsicMatrix)!
            imrdref = (depthData?.cameraCalibrationData!.intrinsicMatrixReferenceDimensions)!
            cloudView?.setDepthFrame(depth: depthData!.depthDataMap, intimatrix:intimatrix, imrdref: imrdref, withTexture: bgra32ColorData!)
        }
        if #available(iOS 14.0, *){// cameraModeがLIDARのときのみ取得可能
            let arDepthData = frame.sceneDepth
            if camMode == .LIDARSensor && arDepthData == nil{
                return
            }
            else if arDepthData != nil{
                #if DEBUG
                    print("生のAR深度画像:",CVPixelBufferGetPixelFormatType(arDepthData!.depthMap))
                #endif
                cloudView?.setDepthFrame(depth: arDepthData!.depthMap, intimatrix:intimatrix, imrdref: imrdref, withTexture: bgra32ColorData!)
                
            }
            
        } else {
            // Fallback on earlier versions
            print("iosのバージョンを14.0以上にしてください.")
        }
    }


}

extension CVPixelBuffer {
    public func toBGRA() throws -> CVPixelBuffer? {
        let pixelBuffer = self

        /// Check format
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        guard pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange else { return pixelBuffer }

        /// Split plane
        let yImage = pixelBuffer.with({ VImage(pixelBuffer: $0, plane: 0) })!
        let cbcrImage = pixelBuffer.with({ VImage(pixelBuffer: $0, plane: 1) })!

        /// Create output pixelBuffer
        let outPixelBuffer = CVPixelBuffer.make(width: yImage.width, height: yImage.height, format: kCVPixelFormatType_32BGRA)!

        /// Convert yuv to argb
        var argbImage = outPixelBuffer.with({ VImage(pixelBuffer: $0) })!
        try argbImage.draw(yBuffer: yImage.buffer, cbcrBuffer: cbcrImage.buffer)
        /// Convert argb to bgra
        argbImage.permute(channelMap: [3, 2, 1, 0])

        return outPixelBuffer
    }
    func with<T>(_ closure: ((_ pixelBuffer: CVPixelBuffer) -> T)) -> T {
        CVPixelBufferLockBaseAddress(self, .readOnly)
        let result = closure(self)
        CVPixelBufferUnlockBaseAddress(self, .readOnly)
        return result
    }

    static func make(width: Int, height: Int, format: OSType) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer? = nil
        CVPixelBufferCreate(kCFAllocatorDefault,
                            width,
                            height,
                            format,
                            nil,
                            &pixelBuffer)
        return pixelBuffer
    }
    
    func copyToMetalCompatible() -> CVPixelBuffer? {

      let attributes: [String: Any] = [
        String(kCVPixelBufferMetalCompatibilityKey): true,
      ]
      return deepCopy(withAttributes: attributes)
    }
    func deepCopy(withAttributes attributes: [String: Any] = [:]) -> CVPixelBuffer? {
       let srcPixelBuffer = self
       let srcFlags: CVPixelBufferLockFlags = .readOnly
       guard kCVReturnSuccess == CVPixelBufferLockBaseAddress(srcPixelBuffer, srcFlags) else {
         return nil
       }
       defer { CVPixelBufferUnlockBaseAddress(srcPixelBuffer, srcFlags) }

       var combinedAttributes: [String: Any] = [:]

       // Copy attachment attributes.
       if let attachments = CVBufferGetAttachments(srcPixelBuffer, .shouldPropagate) as? [String: Any] {
         for (key, value) in attachments {
           combinedAttributes[key] = value
         }
       }

       // Add user attributes.
       combinedAttributes = combinedAttributes.merging(attributes) { $1 }

       var maybePixelBuffer: CVPixelBuffer?
       let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                        CVPixelBufferGetWidth(srcPixelBuffer),
                                        CVPixelBufferGetHeight(srcPixelBuffer),
                                        CVPixelBufferGetPixelFormatType(srcPixelBuffer),
                                        combinedAttributes as CFDictionary,
                                        &maybePixelBuffer)

       guard status == kCVReturnSuccess, let dstPixelBuffer = maybePixelBuffer else {
         return nil
       }

       let dstFlags = CVPixelBufferLockFlags(rawValue: 0)
       guard kCVReturnSuccess == CVPixelBufferLockBaseAddress(dstPixelBuffer, dstFlags) else {
         return nil
       }
       defer { CVPixelBufferUnlockBaseAddress(dstPixelBuffer, dstFlags) }

       for plane in 0...max(0, CVPixelBufferGetPlaneCount(srcPixelBuffer) - 1) {
         if let srcAddr = CVPixelBufferGetBaseAddressOfPlane(srcPixelBuffer, plane),
            let dstAddr = CVPixelBufferGetBaseAddressOfPlane(dstPixelBuffer, plane) {
           let srcBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(srcPixelBuffer, plane)
           let dstBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(dstPixelBuffer, plane)

           for h in 0..<CVPixelBufferGetHeightOfPlane(srcPixelBuffer, plane) {
             let srcPtr = srcAddr.advanced(by: h*srcBytesPerRow)
             let dstPtr = dstAddr.advanced(by: h*dstBytesPerRow)
             dstPtr.copyMemory(from: srcPtr, byteCount: srcBytesPerRow)
           }
         }
       }
       return dstPixelBuffer
     }
}

struct VImage {
    let width: Int
    let height: Int
    let bytesPerRow: Int
    var buffer: vImage_Buffer

    init?(pixelBuffer: CVPixelBuffer, plane: Int) {
        guard let rawBuffer = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, plane) else { return nil }
        self.width = CVPixelBufferGetWidthOfPlane(pixelBuffer, plane)
        self.height = CVPixelBufferGetHeightOfPlane(pixelBuffer, plane)
        self.bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, plane)
        self.buffer = vImage_Buffer(
            data: UnsafeMutableRawPointer(mutating: rawBuffer),
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: bytesPerRow
        )
    }

    init?(pixelBuffer: CVPixelBuffer) {
        guard let rawBuffer = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        self.width = CVPixelBufferGetWidth(pixelBuffer)
        self.height = CVPixelBufferGetHeight(pixelBuffer)
        self.bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        self.buffer = vImage_Buffer(
            data: UnsafeMutableRawPointer(mutating: rawBuffer),
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: bytesPerRow
        )
    }

    mutating func draw(yBuffer: vImage_Buffer, cbcrBuffer: vImage_Buffer) throws {
        try buffer.draw(yBuffer: yBuffer, cbcrBuffer: cbcrBuffer)
    }

    mutating func permute(channelMap: [UInt8]) {
        buffer.permute(channelMap: channelMap)
    }
}

extension vImage_Buffer {
    mutating func draw(yBuffer: vImage_Buffer, cbcrBuffer: vImage_Buffer) throws {
        var yBuffer = yBuffer
        var cbcrBuffer = cbcrBuffer
        var conversionMatrix: vImage_YpCbCrToARGB = {
            var pixelRange = vImage_YpCbCrPixelRange(Yp_bias: 0, CbCr_bias: 128, YpRangeMax: 255, CbCrRangeMax: 255, YpMax: 255, YpMin: 1, CbCrMax: 255, CbCrMin: 0)
            var matrix = vImage_YpCbCrToARGB()
            vImageConvert_YpCbCrToARGB_GenerateConversion(kvImage_YpCbCrToARGBMatrix_ITU_R_709_2, &pixelRange, &matrix, kvImage420Yp8_CbCr8, kvImageARGB8888, UInt32(kvImageNoFlags))
            return matrix
        }()
        let error = vImageConvert_420Yp8_CbCr8ToARGB8888(&yBuffer, &cbcrBuffer, &self, &conversionMatrix, nil, 255, UInt32(kvImageNoFlags))
        if error != kvImageNoError {
            fatalError()
        }
    }

    mutating func permute(channelMap: [UInt8]) {
        vImagePermuteChannels_ARGB8888(&self, &self, channelMap, 0)
    }
}

private extension ARConfiguration {

    static func makeTrueDepthConfiguration() -> ARConfiguration {
        let configuration = ARFaceTrackingConfiguration()

        if ARFaceTrackingConfiguration.supportsFrameSemantics(.personSegmentation) {
            configuration.frameSemantics.insert(.personSegmentation)
        } else {
            print("この端末/OSではピープルオクルージョンを利用できません")
        }
        
        if type(of: configuration).supportsFrameSemantics(.personSegmentationWithDepth){
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        }else{
            print("この端末では、personSegmentationWithDepthを利用できません")
        }

        // Configuration ve cihazınızın .sceneDepth özelliğini desteklediğini kontrol edin
        if #available(iOS 14.0, *) {
            if type(of: configuration).supportsFrameSemantics(.sceneDepth) {
                configuration.frameSemantics.insert(.sceneDepth)
            }else{
                print("この端末では、sceneDepthを利用できません")
            }
        } else {
            // Fallback on earlier versions
        }

        return configuration
    }
    
    static func makeLIDARConfiguration() -> ARConfiguration {
        let configuration = ARWorldTrackingConfiguration()

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentation) {

            configuration.frameSemantics.insert(.personSegmentation)
        } else {
            print("この端末/OSではピープルオクルージョンを利用できません")
        }
        
        if type(of: configuration).supportsFrameSemantics(.personSegmentationWithDepth){
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        }else{
            print("この端末では、personSegmentationWithDepthを利用できません")
        }

        // Configuration ve cihazınızın .sceneDepth özelliğini desteklediğini kontrol edin
        if #available(iOS 14.0, *) {
            if type(of: configuration).supportsFrameSemantics(.sceneDepth) {
                configuration.frameSemantics.insert(.sceneDepth)
            }else{
                print("この端末では、sceneDepthを利用できません")
            }
        } else {
            // Fallback on earlier versions
        }

        return configuration
    }

}


// MARK: - Private extensions
extension UIColor {
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        let v = Int("000000" + hex, radix: 16) ?? 0
        let r = CGFloat(v / Int(powf(256, 2)) % 256) / 255
        let g = CGFloat(v / Int(powf(256, 1)) % 256) / 255
        let b = CGFloat(v / Int(powf(256, 0)) % 256) / 255
        self.init(red: r, green: g, blue: b, alpha: min(max(alpha, 0), 1))
    }
}


import VideoToolbox
extension UIImage {
    public convenience init?(pixelBuffer: CVPixelBuffer) {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        guard let cgImages = cgImage else {
            print("CVPixelBufferからCGImageへの変換で失敗.")
            return nil
        }
        self.init(cgImage: cgImages)
    }
    
}

