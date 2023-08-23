//
//  AAPLTransforms.swift
//  Client
//
//  Created by KoheiOgawa on 2020/11/27.
//  Copyright © 2020 Itty Bitty Apps Pty Ltd. All rights reserved.
//
import simd
// MARK: - Private Constants

let  kPi_f:Float      = .pi
let  k1Div180_f:Float = 1.0 / 180.0
let  kRadians:Float   = k1Div180_f * kPi_f

// MARK: - Private Utilities
func radians(degrees:Float)->Float{
    return kRadians * degrees
}


// MARK: - Public Transformations - Scale
func scale(x:Float, y:Float, z:Float)->simd_float4x4{
    let v:SIMD4<Float> = SIMD4<Float>(x,y,z,1.0)
    return simd_float4x4(diagonal: v)
}

func scale(s:SIMD3<Float>)->simd_float4x4{
    let v:SIMD4<Float> = SIMD4<Float>(s.x,s.y,s.z,1.0)
    return simd_float4x4(diagonal: v)
}

// MARK: - Public Transformations - Translate
func translate(t:SIMD3<Float>)->simd_float4x4{
    var M:simd_float4x4 = matrix_identity_float4x4
    M.columns.3.x = t.x
    M.columns.3.y = t.y
    M.columns.3.z = t.z
    
    return M
}

func translate(x:Float, y:Float, z:Float)->simd_float4x4{
    return translate(t: SIMD3<Float>(x,y,z))
}

// MARK: - Public Transformations - Rotate
func AAPLRadiansOverPi(degrees:Float)->Float{
    return degrees * k1Div180_f
}

func rotate(angle:Float, r:SIMD3<Float>)->simd_float4x4{
    let a:Float = AAPLRadiansOverPi(degrees: angle)
    var c:Float = 0.0
    var s:Float = 0.0
    
    // Computes the sine and cosine of pi times angle (measured in radians)
    // faster and gives exact results for angle = 90, 180, 270, etc.
    __sincospif(a,&s,&c)
    let k = 1.0 - c
    let u:SIMD3<Float> = simd_normalize(r)
    let v:SIMD3<Float> = s * u
    let w:SIMD3<Float> = k * u
    
    var P:SIMD4<Float> = SIMD4<Float>.init()
    var Q:SIMD4<Float> = SIMD4<Float>.init()
    var R:SIMD4<Float> = SIMD4<Float>.init()
    var S:SIMD4<Float> = SIMD4<Float>.init()
    
    P.x = w.x * u.x + c
    P.y = w.x * u.y + v.z
    P.z = w.x * u.z - v.y
    P.w = 0.0
    
    Q.x = w.x * u.y - v.z
    Q.y = w.y * u.y + c
    Q.z = w.y * u.z + v.x
    Q.w = 0.0
    
    R.x = w.x * u.z + v.y
    R.y = w.y * u.z - v.x
    R.z = w.z * u.z + c
    R.w = 0.0
    
    S.x = 0.0
    S.y = 0.0
    S.z = 0.0
    S.w = 1.0
    
    return simd_float4x4(P,Q,R,S)
}

func rotate(angle:Float, x:Float, y:Float, z:Float)->simd_float4x4{
    let r:SIMD3<Float> = SIMD3<Float>(x,y,z)
    return rotate(angle: angle, r: r)
}

// MARK: - Public Transformations - Perspective
func perspective(width:Float, height:Float, near:Float, far:Float)->simd_float4x4{
    let zNear:Float = 2.0 * near
    let zFar:Float = far / (far - near)
    
    var P:SIMD4<Float> = SIMD4<Float>.init()
    var Q:SIMD4<Float> = SIMD4<Float>.init()
    var R:SIMD4<Float> = SIMD4<Float>.init()
    var S:SIMD4<Float> = SIMD4<Float>.init()
    
    P.x = zNear / width;
    P.y = 0.0
    P.z = 0.0
    P.w = 0.0
    
    Q.x = 0.0;
    Q.y = zNear / height
    Q.z = 0.0
    Q.w = 0.0
    
    R.x = 0.0
    R.y = 0.0
    R.z = zFar
    R.w = 1.0
    
    S.x =  0.0
    S.y =  0.0
    S.z = -near * zFar
    S.w =  0.0
    
    return simd_float4x4(P,Q,R,S)
}

func perspective_fov(fovy:Float, aspect:Float, near:Float, far:Float)->simd_float4x4{
    let angle:Float = radians(degrees: 0.5 * fovy)
    let yScale:Float = 1.0 / tan(angle)
    let xScale:Float = yScale / aspect
    let zScale:Float = far / (far - near)
    
    var P:SIMD4<Float> = SIMD4<Float>.init()
    var Q:SIMD4<Float> = SIMD4<Float>.init()
    var R:SIMD4<Float> = SIMD4<Float>.init()
    var S:SIMD4<Float> = SIMD4<Float>.init()
    
    P.x = xScale
    P.y = 0.0
    P.z = 0.0
    P.w = 0.0
    
    Q.x = 0.0
    Q.y = yScale
    Q.z = 0.0
    Q.w = 0.0
    
    R.x = 0.0
    R.y = 0.0
    R.z = zScale
    R.w = 1.0
    
    S.x =  0.0
    S.y =  0.0
    S.z = -near * zScale
    S.w =  0.0
    
    return simd_float4x4(P,Q,R,S)
}

func perspective_fov(fovy:Float, width:Float, height:Float, near:Float, far:Float)->simd_float4x4{
    let aspect:Float = width / height
    return perspective_fov(fovy: fovy, aspect: aspect, near: near, far: far)
}

// MARK: - Public Transformations - LookAt
func lookAt(eye:SIMD3<Float>, center:SIMD3<Float>,up:SIMD3<Float>)->simd_float4x4{
    let zAxis:SIMD3<Float> = simd_normalize(center - eye)
    let xAxis:SIMD3<Float> = simd_normalize(simd_cross(up, zAxis))
    let yAxis:SIMD3<Float> = simd_cross(zAxis, xAxis)
    
    var P:SIMD4<Float> = SIMD4<Float>.init()
    var Q:SIMD4<Float> = SIMD4<Float>.init()
    var R:SIMD4<Float> = SIMD4<Float>.init()
    var S:SIMD4<Float> = SIMD4<Float>.init()
    
    P.x = xAxis.x
    P.y = yAxis.x
    P.z = zAxis.x
    P.w = 0.0;
    
    Q.x = xAxis.y
    Q.y = yAxis.y
    Q.z = zAxis.y
    Q.w = 0.0;
    
    R.x = xAxis.z
    R.y = yAxis.z
    R.z = zAxis.z
    R.w = 0.0;
    
    S.x = -simd_dot(xAxis, eye)
    S.y = -simd_dot(yAxis, eye)
    S.z = -simd_dot(zAxis, eye)
    S.w =  1.0;
    
    return simd_float4x4(P,Q,R,S)
    
}

func lookAt(pEye:SIMD3<Float>, pCenter:SIMD3<Float>,pUp:SIMD3<Float>)->simd_float4x4{
    let eye:SIMD3<Float> = SIMD3<Float>(pEye[0],pEye[1],pEye[2])
    let center:SIMD3<Float> = SIMD3<Float>(pCenter[0],pCenter[1],pCenter[2])
    let up:SIMD3<Float> = SIMD3<Float>(pUp[0],pUp[1],pUp[2])
    
    return lookAt(eye: eye, center: center, up: up)
}

// MARK: - Public Transformations - Orthographic
func ortho2d(left:Float, right:Float, bottom:Float, top:Float, near:Float, far:Float)->simd_float4x4{
    let sLength:Float = 1.0 / (right - left)
    let sHeight:Float = 1.0 / (top - bottom)
    let sDepth:Float = 1.0 / (far - near)
    
    var P:SIMD4<Float> = SIMD4<Float>.init()
    var Q:SIMD4<Float> = SIMD4<Float>.init()
    var R:SIMD4<Float> = SIMD4<Float>.init()
    var S:SIMD4<Float> = SIMD4<Float>.init()
    
    P.x = 2.0 * sLength
    P.y = 0.0
    P.z = 0.0
    P.w = 0.0
    
    Q.x = 0.0
    Q.y = 2.0 * sHeight
    Q.z = 0.0
    Q.w = 0.0
    
    R.x = 0.0
    R.y = 0.0
    R.z = sDepth
    R.w = 0.0
    
    S.x =  0.0
    S.y =  0.0
    S.z = -near  * sDepth
    S.w =  1.0
    
    return simd_float4x4(P,Q,R,S)
}

func ortho2d_oc(origin:SIMD3<Float>, size:SIMD3<Float>)->simd_float4x4{
    return ortho2d(left: origin.x, right: origin.y, bottom: origin.z, top: size.x, near: size.y, far: size.z)
}


// MARK: - Public Transformations - frustum
func frustum(fovH:Float, fovV:Float, near:Float, far:Float)->simd_float4x4{
    let width:Float = 1.0 / tan(radians(degrees: 0.5 * fovH))
    let height:Float = 1.0 / tan(radians(degrees: 0.5 * fovV))
    let sDepth:Float = far / (far - near)
    
    var P:SIMD4<Float> = SIMD4<Float>.init()
    var Q:SIMD4<Float> = SIMD4<Float>.init()
    var R:SIMD4<Float> = SIMD4<Float>.init()
    var S:SIMD4<Float> = SIMD4<Float>.init()
    
    P.x = width
    P.y = 0.0
    P.z = 0.0
    P.w = 0.0
    
    Q.x = 0.0
    Q.y = height
    Q.z = 0.0
    Q.w = 0.0
    
    R.x = 0.0
    R.y = 0.0
    R.z = sDepth
    R.w = 1.0
    
    S.x =  0.0
    S.y =  0.0
    S.z = -sDepth * near
    S.w =  0.0
    
    return simd_float4x4(P,Q,R,S)
}

func frustum(left:Float, right:Float, bottom:Float, top:Float, near:Float, far:Float)->simd_float4x4{
    let width:Float = right - left
    let height:Float = top - bottom
    let depth:Float = far - near
    let sDepth:Float = far / depth
    
    var P:SIMD4<Float> = SIMD4<Float>.init()
    var Q:SIMD4<Float> = SIMD4<Float>.init()
    var R:SIMD4<Float> = SIMD4<Float>.init()
    var S:SIMD4<Float> = SIMD4<Float>.init()
    
    P.x = width
    P.y = 0.0
    P.z = 0.0
    P.w = 0.0
    
    Q.x = 0.0
    Q.y = height
    Q.z = 0.0
    Q.w = 0.0
    
    R.x = 0.0
    R.y = 0.0
    R.z = sDepth
    R.w = 1.0
    
    S.x =  0.0
    S.y =  0.0
    S.z = -sDepth * near
    S.w =  0.0
    
    return simd_float4x4(P,Q,R,S)
}

func frustum_oc(left:Float, right:Float, bottom:Float, top:Float, near:Float, far:Float)->simd_float4x4{
    let sWidth:Float = 1.0 / (right - left)
    let sHeight:Float = 1.0 / (top - bottom)
    let sDepth:Float = far / (far - near)
    let dNear:Float = 2.0 * near
    
    var P:SIMD4<Float> = SIMD4<Float>.init()
    var Q:SIMD4<Float> = SIMD4<Float>.init()
    var R:SIMD4<Float> = SIMD4<Float>.init()
    var S:SIMD4<Float> = SIMD4<Float>.init()
    
    P.x = dNear * sWidth
    P.y = 0.0
    P.z = 0.0
    P.w = 0.0
    
    Q.x = 0.0
    Q.y = dNear * sHeight
    Q.z = 0.0
    Q.w = 0.0
    
    R.x = -sWidth  * (right + left)
    R.y = -sHeight * (top   + bottom)
    R.z =  sDepth
    R.w =  1.0
    
    S.x =  0.0
    S.y =  0.0
    S.z = -sDepth * near
    S.w =  0.0
    
    return simd_float4x4(P,Q,R,S)
}
