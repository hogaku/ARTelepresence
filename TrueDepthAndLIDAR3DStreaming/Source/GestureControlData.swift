//
//  gestureControlData.swift
//  TrueDepthAndLIDAR3DStreaming
//
//  Created by KoheiOgawa on 2020/12/21.
//  Copyright © 2020 Itty Bitty Apps Pty Ltd. All rights reserved.
//


import Foundation
import CoreGraphics

public class GestureControlData:NSObject,NSSecureCoding{
    public static var supportsSecureCoding: Bool = true
    
    private var gestureStateKey = "gstkey"
    private var gestureXKey = "gxkey"
    private var gestureYKey = "gykey"
    private var gestureScaleKey = "gskey"
    private var gestureRotateKey = "grkey"
    private var gestureResetKey = "grtkey"
    
    public var gestureState:Int = 0
    public var pntX:Float = 0
    public var pntY:Float = 0
    public var scale:Float = Float(2.0)
    public var rotate = Float(0)
    public var reset = Int(0)
    
    
    public init?(gestureState:Int,pntXY:CGPoint, scale:Float, rotate:Float,reset:Int){
        self.gestureState = gestureState
        self.pntX = Float(pntXY.x)
        self.pntY = Float(pntXY.y)
        self.scale = scale
        self.rotate = rotate
        self.reset = reset
    }
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(gestureState,forKey: gestureStateKey)
        aCoder.encode(pntX, forKey: gestureXKey)
        aCoder.encode(pntY, forKey: gestureYKey)
        aCoder.encode(scale, forKey: gestureScaleKey)
        aCoder.encode(rotate, forKey: gestureRotateKey)
        aCoder.encode(reset, forKey: gestureResetKey)
    
    }
    required public init?(coder aDecoder: NSCoder) {
        let isNilGestureState = aDecoder.decodeInteger(forKey: gestureStateKey)
        let isNilPntX = aDecoder.decodeFloat(forKey: gestureXKey)
        let isNilPntY = aDecoder.decodeFloat(forKey: gestureYKey)
        let isNilScale = aDecoder.decodeFloat(forKey: gestureScaleKey)
        let isNilRotate = aDecoder.decodeFloat(forKey: gestureRotateKey)
        let isNilReset = aDecoder.decodeInteger(forKey: gestureResetKey)

        if(isNilGestureState != nil){
            self.gestureState = aDecoder.decodeInteger(forKey: gestureStateKey)
            print("self.gestureState:",self.gestureState)
        }else{
            print("Failed to Decode(gestureState).")
        }
        
        if(isNilPntX != nil && isNilPntY != nil && isNilScale != nil && isNilRotate != nil){
            
            self.pntX = aDecoder.decodeFloat(forKey: gestureXKey)
            self.pntY = aDecoder.decodeFloat(forKey: gestureYKey)
            self.scale = aDecoder.decodeFloat(forKey: gestureScaleKey)
            self.rotate = aDecoder.decodeFloat(forKey: gestureRotateKey)
            #if DEBUG
                print("self.pntX:",self.pntX)
                print("self.pntY:",self.pntY)
                print("self.scale:",self.scale)
                print("self.rotate:",self.rotate)
            #endif
        }else{
            print("Failed to Decode(gesture).")
        }
        if(isNilReset != nil){
            self.reset = aDecoder.decodeInteger(forKey: gestureResetKey)
            #if DEBUG
                print("self.reset:",self.reset)
            #endif
        }else{
            print("Failed to Decode(reset).")
        }
    }
}
