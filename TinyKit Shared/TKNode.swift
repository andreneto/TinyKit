//
//  Node.swift
//  TinyKit
//
//  Created by André Carneiro on 03/10/19.
//  Copyright © 2019 André Carneiro. All rights reserved.
//

import Foundation
import MetalKit
import Metal

open class TKNode : TKResponder {
    
    public var name: String?
    public var position: TKPoint = CGPoint.zero {
        didSet {
            self.transformMatrix = self.getTransform()
        }
    }
    public var zPosition: CGFloat = 1.0
    var frame: CGRect = CGRect.zero
    
    internal var transformMatrix: simd_float4x4 = matrix_identity_float4x4
    
    var zRotation: CGFloat = 0
    var xScale: CGFloat = 1.0
    var yScale: CGFloat = 1.0
    
    public var scene: TKScene? {
        didSet {
            self.didMove(to: self.scene!)
        }
    }
    public var parent: TKNode?
    public var children: [TKNode] = []
    
    var alpha: CGFloat = 1.0
    var isHidden: Bool = false
    
    func getTransform() -> simd_float4x4 {
        return matrix_float4x4.init(columns:(vector_float4(1, 0, 0, 0),
        vector_float4(0, 1, 0, 0),
        vector_float4(0, 0, 1, 0),
        vector_float4(Float(self.position.x), Float(self.position.y), 0, 1)))
    }
    
    public func addChild(_ node: TKNode) {
        self.children.append(node)
        node.parent = self
    }
    
    public func removeChildren(in nodes: [TKNode]) {
        for node in nodes {
            for (index, child) in self.children.enumerated() {
                if child === node {
                    self.children.remove(at: index)
                }
            }
        }
    }
    
    public func didMove(to scene: TKScene) {
        
    }
}



