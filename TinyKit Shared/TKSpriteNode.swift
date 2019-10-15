//
//  TKSpriteNode.swift
//  TinyKit
//
//  Created by André Carneiro on 12/10/19.
//  Copyright © 2019 André Carneiro. All rights reserved.
//

import Foundation
import MetalKit

open class TKSpriteNode : TKNode {
    var imageName: String
    public var size: TKSize = TKSize.zero
    public var anchorPoint: TKPoint = TKPoint.zero
    public var color: TKColor = TKColor.clear
    var texture: TKTexture?
    var mesh: MTKMesh?
    
    public init?(imageNamed: String) {
        self.imageName = imageNamed
        self.texture = TKTexture(imageNamed: self.imageName, mipmaped: false)
//        self.texture = TKTexture()
        super.init()
    }
    
    public func allocate() {
        if let view = self.scene?.view {
            
            do {
//                self.texture!.texture = try Renderer.loadTexture(device: view.device!, textureName: self.imageName)
                self.texture!.loadTexture(view: view, flip: false)
                if self.size == TKSize.zero {
//                    self.size = TKSize(width: self.texture!.width, height: self.texture!.height)
                }
                
                self.mesh = try Renderer.buildMesh(device: view.device!, mtlVertexDescriptor: view.renderer!.vertexDescriptor, size: self.size)
            } catch {
                print("Unable to find texture.  Error info: \(error)")
            }
        }
    }
    
    public override func didMove(to scene: TKScene) {
        
        self.allocate()
        
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
