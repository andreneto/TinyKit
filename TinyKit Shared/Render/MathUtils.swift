//
//  MathUtils.swift
//  TinyKit
//
//  Created by André Carneiro on 03/10/19.
//  Copyright © 2019 André Carneiro. All rights reserved.
//

import Foundation
import simd

extension simd_float4 {
    var xyz: simd_float3 {
        return simd_float3(x, y, z)
    }
}

extension simd_float4x4 {
    init(scaleBy s: Float) {
        self.init(simd_float4(s, 0, 0, 0),
                  simd_float4(0, s, 0, 0),
                  simd_float4(0, 0, s, 0),
                  simd_float4(0, 0, 0, 1))
    }
    
    init(rotationAbout axis: simd_float3, by angleRadians: Float) {
        let a = normalize(axis)
        let x = a.x, y = a.y, z = a.z
        let c = cosf(angleRadians)
        let s = sinf(angleRadians)
        let t = 1 - c
        self.init(simd_float4( t * x * x + c,     t * x * y + z * s, t * x * z - y * s, 0),
                  simd_float4( t * x * y - z * s, t * y * y + c,     t * y * z + x * s, 0),
                  simd_float4( t * x * z + y * s, t * y * z - x * s,     t * z * z + c, 0),
                  simd_float4(                 0,                 0,                 0, 1))
    }
    
    init(translationBy t: simd_float3) {
        self.init(simd_float4(   1,    0,    0, 0),
                  simd_float4(   0,    1,    0, 0),
                  simd_float4(   0,    0,    1, 0),
                  simd_float4(t[0], t[1], t[2], 1))
    }
    
    init(perspectiveProjectionFov fovRadians: Float, aspectRatio aspect: Float, nearZ: Float, farZ: Float) {
        let yScale = 1 / tan(fovRadians * 0.5)
        let xScale = yScale / aspect
        let zRange = farZ - nearZ
        let zScale = -(farZ + nearZ) / zRange
        let wzScale = -2 * farZ * nearZ / zRange
        
        let xx = xScale
        let yy = yScale
        let zz = zScale
        let zw = Float(-1)
        let wz = wzScale
        
        self.init(simd_float4(xx,  0,  0,  0),
                  simd_float4( 0, yy,  0,  0),
                  simd_float4( 0,  0, zz, zw),
                  simd_float4( 0,  0, wz,  1))
    }
    
    var normalMatrix: float3x3 {
        let upperLeft = float3x3(self[0].xyz, self[1].xyz, self[2].xyz)
        return upperLeft.transpose.inverse
    }
}

// Generic matrix math utility functions
func matrix4x4_rotation(radians: Float, axis: SIMD3<Float>) -> matrix_float4x4 {
    let unitAxis = normalize(axis)
    let ct = cosf(radians)
    let st = sinf(radians)
    let ci = 1 - ct
    let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z
    return matrix_float4x4.init(columns:(vector_float4(    ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
                                         vector_float4(x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0),
                                         vector_float4(x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0),
                                         vector_float4(                  0,                   0,                   0, 1)))
}

func matrix4x4_translation(_ translationX: Float, _ translationY: Float, _ translationZ: Float) -> matrix_float4x4 {
    return matrix_float4x4.init(columns:(vector_float4(1, 0, 0, 0),
                                         vector_float4(0, 1, 0, 0),
                                         vector_float4(0, 0, 1, 0),
                                         vector_float4(translationX, translationY, translationZ, 1)))
}

func matrix_perspective_right_hand(fovyRadians fovy: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    //    let ys = 1 / tanf(fovy * 0.5)
    //    let xs = ys / aspectRatio
    //    let zs = farZ / (nearZ - farZ)
    
    let yScale = 1 / tan(fovy * 0.5)
    let xScale = yScale / aspectRatio
    
    let zRange = farZ - nearZ
    let zScale = -(farZ + nearZ) / zRange
    let wzScale = -2 * farZ * nearZ / zRange
    
    let xx = xScale
    let yy = yScale
    let zz = zScale
    let zw = Float(-1)
    let wz = wzScale
    
    return matrix_float4x4.init(simd_float4(xx,  0,  0,  0),
                                simd_float4( 0, yy,  0,  0),
                                simd_float4( 0,  0, zz, zw),
                                simd_float4( 0,  0, wz,  0))
    
    
    //    return matrix_float4x4.init(columns:(vector_float4(xs,  0, 0,   0),
    //                                         vector_float4( 0, ys, 0,   0),
    //                                         vector_float4( 0,  0, zs, -1),
    //                                         vector_float4( 0,  0, zs * nearZ, 0)))
}

func makeOrthographicMatrix(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> float4x4 {
    let ral = (right + left)
    let rsl = (right - left)
    let tab = (top + bottom)
    let tsb = (top - bottom)
//    let fan = (far + near)
    let fsn = (far - near)
    
    return simd_float4x4(columns: (simd_float4(2.0 / rsl, 0.0, 0.0, 0.0),
                                   simd_float4(0.0, 2.0 / tsb, 0.0, 0.0),
                                   simd_float4(0.0, 0.0, -1 / fsn, 0.0),
                                   simd_float4(-ral / rsl, -tab / tsb, near / fsn, 1.0)))
}

func radians_from_degrees(_ degrees: Float) -> Float {
    return (degrees / 180) * .pi
}

