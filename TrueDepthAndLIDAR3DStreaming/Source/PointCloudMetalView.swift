//
//  PointCloudMetalView.swift
//  Client
//
//  Created by KoheiOgawa on 2020/11/26.
//  Copyright © 2020 Itty Bitty Apps Pty Ltd. All rights reserved.
//

import MetalKit
import MetalPerformanceShaders
import Foundation
import simd
import CoreVideo
import AVFoundation

func matrix4_mul_vector3(m:simd_float4x4,v:SIMD3<Float>)->SIMD3<Float>{
    var temp:SIMD4<Float> = SIMD4<Float>(v.x, v.y, v.z, 0.0);
    temp = simd_mul(m,temp);
    return SIMD3<Float>(temp.x, temp.y, temp.z)
}

class PointCloudMetalView:MTKView{
    private let syncQueue = DispatchQueue(label: "PointCloudMetalView sync queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    private var renderPipelineState: MTLRenderPipelineState!
    private var depthStencilState: MTLDepthStencilState!
    private var commandQueue: MTLCommandQueue?
    private var depthTextureCache: CVMetalTextureCache?
    private var colorTextureCache: CVMetalTextureCache?
    
//    private var internalDepthFrame: AVDepthData?
    private var internalDepthFrame: CVPixelBuffer?
    private var internalColorTexture: CVPixelBuffer?
    
    private var intimatrix:matrix_float3x3 = matrix_float3x3.init()
    private var imrdref:CGSize = CGSize.init()
    private var _center:SIMD3<Float> = SIMD3<Float>.init()
    private var eye:SIMD3<Float> = SIMD3<Float>.init()
    private var up:SIMD3<Float> = SIMD3<Float>.init()
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        device = MTLCreateSystemDefaultDevice()
        
        configureMetal()
        createTextureCache()
        
        colorPixelFormat = .bgra8Unorm
//        colorPixelFormat = .rg32Uint
    }
    
    func configureMetal() {
        print("configureMetal")
        let defaultLibrary = device!.makeDefaultLibrary()!
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        pipelineDescriptor.vertexFunction = defaultLibrary.makeFunction(name: "vertexShaderPoints")
        pipelineDescriptor.fragmentFunction = defaultLibrary.makeFunction(name: "fragmentShaderPoints")
        
        let depthPipelineDescriptor = MTLDepthStencilDescriptor()
        depthPipelineDescriptor.isDepthWriteEnabled = true
        depthPipelineDescriptor.depthCompareFunction = .less
        
        do {
            renderPipelineState = try device!.makeRenderPipelineState(descriptor: pipelineDescriptor)
            depthStencilState = try device!.makeDepthStencilState(descriptor: depthPipelineDescriptor)
        } catch {
            fatalError("Unable to create preview Metal view pipeline state. (\(error))")
        }
        
        commandQueue = device!.makeCommandQueue()
    }
    
    
    func createTextureCache() {
        var newTextureCache: CVMetalTextureCache?
        if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device!, nil, &newTextureCache) == kCVReturnSuccess {
            depthTextureCache = newTextureCache
            colorTextureCache = newTextureCache
        } else {
            assertionFailure("Unable to allocate texture cache")
        }
    }
//    func toCVPixelBuffer(from image: CIImage) -> CVPixelBuffer? {
//        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
//        var pixelBuffer : CVPixelBuffer?
//        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.extent.width), Int(image.extent.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
//
//        guard (status == kCVReturnSuccess) else {
//            return nil
//        }
//
//        return pixelBuffer
//    }
    
    func setDepthFrame(depth:CVPixelBuffer, intimatrix:matrix_float3x3,imrdref:CGSize, withTexture unormTexture:CVPixelBuffer){
//        print("setDepthFrame")
        syncQueue.sync {
            self.intimatrix = intimatrix
            self.imrdref = imrdref
            self.internalDepthFrame = depth
            self.internalColorTexture = unormTexture
        }
        DispatchQueue.main.async(){
            self.setNeedsDisplay()
        }
    }
    
    override func draw(_ rect: CGRect) {
//        print("metal draw")
        var depthData:CVPixelBuffer!
        var colorFrame:CVPixelBuffer!
        
        syncQueue.sync {
            depthData = self.internalDepthFrame
            colorFrame = self.internalColorTexture
        }

        if (depthData == nil || colorFrame == nil){
            return
        }
        
//        let depthFrame:CVPixelBuffer = depthData.depthDataMap
        let depthFrame:CVPixelBuffer = depthData
        var cvDepthTexture:CVMetalTexture!

        if(kCVReturnSuccess != CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                  depthTextureCache!,
                                                  depthFrame,
                                                  nil,
//                                                  .r16Float,
                                                  .r32Float,
                                                  CVPixelBufferGetWidth(depthFrame),
                                                  CVPixelBufferGetHeight(depthFrame),
                                                  0,
                                                  &cvDepthTexture)){
            print("Failed to create depth texture");
            return
        }
        
        guard let depthTexture = CVMetalTextureGetTexture(cvDepthTexture) else {
            print("Failed to create depth texture ")
            
            CVMetalTextureCacheFlush(depthTextureCache!, 0)
            return
        }
        
        
        var cvColorTexture:CVMetalTexture!
        
        if(kCVReturnSuccess != CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                  colorTextureCache!,
                                                  colorFrame,
                                                  nil,
                                                  colorPixelFormat,
                                                  CVPixelBufferGetWidth(colorFrame),
                                                  CVPixelBufferGetHeight(colorFrame),
                                                  0,
                                                  &cvColorTexture)){
            print("Failed to create color texture");
            return
        }
        
        
        guard let colorTexture = CVMetalTextureGetTexture(cvColorTexture) else {
            print("Failed to create color texture ")
            
            CVMetalTextureCacheFlush(colorTextureCache!, 0)
            return
        }
        
//        var intrinsics:matrix_float3x3 = depthData.cameraCalibrationData!.intrinsicMatrix
//        let referenceDimensions:CGSize = depthData.cameraCalibrationData!.intrinsicMatrixReferenceDimensions
        var intrinsics:matrix_float3x3 = self.intimatrix
        let referenceDimensions:CGSize = self.imrdref
        
        let ratio:Float = Float(referenceDimensions.width) / Float(CVPixelBufferGetWidth(depthFrame))
        intrinsics.columns.0[0] /= ratio
        intrinsics.columns.1[1] /= ratio
        intrinsics.columns.2[0] /= ratio
        intrinsics.columns.2[1] /= ratio

        
        // Set up command buffer and encoder
        guard let commandQueue = commandQueue else {
            print("Failed to create Metal command queue")
            CVMetalTextureCacheFlush(depthTextureCache!, 0)
            CVMetalTextureCacheFlush(colorTextureCache!, 0)
            return
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("Failed to create Metal command buffer")
            CVMetalTextureCacheFlush(depthTextureCache!, 0)
            CVMetalTextureCacheFlush(colorTextureCache!, 0)
            return
        }
        
        guard let drawable = currentDrawable,
            let renderPassDescriptor = currentRenderPassDescriptor else {
                return
        }
        
        let depthTextureDescriptor:MTLTextureDescriptor = MTLTextureDescriptor.init()
        depthTextureDescriptor.width = Int(self.drawableSize.width)
        depthTextureDescriptor.height = Int(self.drawableSize.height)
        depthTextureDescriptor.pixelFormat = .depth32Float
        depthTextureDescriptor.usage = MTLTextureUsage.renderTarget
        
        let depthTestTexture:MTLTexture = device!.makeTexture(descriptor: depthTextureDescriptor)!
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.storeAction = .store
        renderPassDescriptor.depthAttachment.clearDepth = 1.0
        renderPassDescriptor.depthAttachment.texture = depthTestTexture
        
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            print("Failed to create Metal command encoder")
            CVMetalTextureCacheFlush(depthTextureCache!, 0)
            CVMetalTextureCacheFlush(colorTextureCache!, 0)
            return
        }
        renderEncoder.setDepthStencilState(depthStencilState)
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setVertexTexture(depthTexture, index: 0)
        
        var finalViewMatrix:simd_float4x4 = getFinalViewMatrix()
        renderEncoder.setVertexBytes(&finalViewMatrix, length:MemoryLayout.size(ofValue: finalViewMatrix), index: 0)
        renderEncoder.setVertexBytes(&intrinsics, length: MemoryLayout.size(ofValue: intrinsics), index: 1)
        renderEncoder.setFragmentTexture(colorTexture, index: 0)
        renderEncoder.drawPrimitives(type: MTLPrimitiveType.point, vertexStart: 0, vertexCount: CVPixelBufferGetWidth(depthFrame) * CVPixelBufferGetHeight(depthFrame))
        renderEncoder.endEncoding()
        
        commandBuffer.present(self.currentDrawable!)
        commandBuffer.commit()
    }
    
    func rollAroundCenter(angle:Float){
        syncQueue.sync {
            var viewDir:SIMD3<Float> = self._center - self.eye
            viewDir = simd_normalize(viewDir)
            let rotMat:simd_float4x4 = rotate(angle: angle, r: viewDir)
            self.up = matrix4_mul_vector3(m: rotMat, v: self.up)
        }
    }
    
    // rotate around Y axis
    func yawAroundCenter(angle:Float){
        syncQueue.sync {
            let rotMat:simd_float4x4 = rotate(angle: angle, r: self.up)
            
            self.eye = self.eye - self._center
            self.eye = matrix4_mul_vector3(m: rotMat, v: self.eye)
            self.eye = self.eye + self._center
            
            self.up = matrix4_mul_vector3(m: rotMat, v: self.up)
        }
    }
    
    // rotate around X axis
    func pitchAroundCenter(angle:Float){
//        print("pitchAroundCenter")
        syncQueue.sync {
            let viewDirection:SIMD3<Float> = simd_normalize(self._center - self.eye)
            let rightVector:SIMD3<Float> = simd_cross(self.up, viewDirection)
            
            let rotMat:simd_float4x4 = rotate(angle: angle, r: rightVector)
            
            self.eye = self.eye - self._center
            self.eye = matrix4_mul_vector3(m: rotMat, v: self.eye)
            self.eye = self.eye + self._center
            
            self.up = matrix4_mul_vector3(m: rotMat, v: self.up)
        }
    }
    
    func moveTowardCenter(scale:Float){
//        print("moveTowardCenter")
        var _scale:Float = scale
        syncQueue.sync {
            var direction:SIMD3<Float> = self._center - self.eye
            
            let distance = sqrt(simd_dot(direction, direction))
            if(_scale > distance){
                _scale = distance - 3.0
            }
            direction = simd_normalize(direction)
            direction = direction * _scale
            self.eye += direction
        }
    }
    
    func resetView(){
//        print("resetView")
        syncQueue.sync {
            self._center = SIMD3<Float>(0, 0, 500)
            self.eye = SIMD3<Float>(0, 0, 0)
            self.up = SIMD3<Float>(-1, 0, 0)
        }
    }
    func getFinalViewMatrix()->simd_float4x4{
        let aspect:Float = Float(self.drawableSize.width / self.drawableSize.height)
        
        // Use a magic number that simply looks good
        let vfov:Float = 70
        let appleProjectMat:simd_float4x4 = perspective_fov(fovy: vfov, aspect: aspect, near: 0.01, far: 30000)
        
        var eye:SIMD3<Float> = SIMD3<Float>.init()
        var center:SIMD3<Float> = SIMD3<Float>.init()
        var up:SIMD3<Float> = SIMD3<Float>.init()
        
        syncQueue.sync {
            eye = self.eye
            center = self._center
            up = self.up
        }
        
        let appleViewMat:simd_float4x4 = lookAt(eye: eye, center: center, up: up)
        
        return appleProjectMat * appleViewMat
    }
}
