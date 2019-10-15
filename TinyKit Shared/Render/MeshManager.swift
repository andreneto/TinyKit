//
//  MeshManager.swift
//  TinyKit
//
//  Created by André Carneiro on 14/10/19.
//  Copyright © 2019 André Carneiro. All rights reserved.
//

import Foundation
import MetalKit

class MeshManager {
    var device : MTLDevice
    var meshes: [MTKMesh]
    
    init(device: MTLDevice) {
        self.device = device
        self.meshes = []
    }
}
