//
//  TKScene.swift
//  TinyKit
//
//  Created by André Carneiro on 12/10/19.
//  Copyright © 2019 André Carneiro. All rights reserved.
//

import Foundation

open class TKScene : TKNode {
    
//    var camera: TKCameraNode
    
//    var rootNode = Node2D(name: "Root")
//    var ambientLightColor = simd_float3(0, 0, 0)
//    var lights = [Light]()
    var size: TKSize
    var view: TKView?
    
    public init(size: TKSize) {
        self.size = size
        super.init()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func addChild(_ node: TKNode) {
        super.children.append(node)
        node.scene = self
    }
    
    
    
    open func update(_ currentTime: TimeInterval) {
        
    }
    
//    func nodeNamed(_ name: String) -> TKNode? {
//        if rootNode.name == name {
//            return rootNode
//        } else {
//            return rootNode.nodeNamedRecursive(name)
//        }
//    }
}
