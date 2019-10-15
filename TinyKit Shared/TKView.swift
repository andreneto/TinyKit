//
//  TKView.swift
//  TinyKit
//
//  Created by André Carneiro on 05/10/19.
//  Copyright © 2019 André Carneiro. All rights reserved.
//

import Foundation
import MetalKit

public class TKView: MTKView {
    var renderer: Renderer!
    public var scene: TKScene?
    
    public var ignoresSiblingOrder : Bool = false
    public var showsFPS : Bool = true
    public var showsNodeCount : Bool = true
    
    override public init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }
        
        self.device = defaultDevice

        guard let newRenderer = Renderer(metalKitView: self) else {
            print("Renderer cannot be initialized")
            return
        }

        renderer = newRenderer

        renderer.mtkView(self, drawableSizeWillChange: self.drawableSize)

        self.delegate = renderer
        
    }
    
    required public init(coder: NSCoder) {
        super.init(coder: coder)
        
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }
        
        self.device = defaultDevice

        guard let newRenderer = Renderer(metalKitView: self) else {
            print("Renderer cannot be initialized")
            return
        }

        renderer = newRenderer

        renderer.mtkView(self, drawableSizeWillChange: self.drawableSize)

        self.delegate = renderer
        
    }
    
    public func presentScene(_ scene: TKScene) {
        self.scene = scene
        self.renderer!.setFrameResolution(size: self.scene!.size)
        scene.view = self
    }
    
    public func setDebugCapture(scope: MTLCaptureScope) {
        self.renderer?.captureScope = scope
    }
}
