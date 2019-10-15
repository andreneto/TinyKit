//
//  TextureManager.swift
//  TinyKit
//
//  Created by André Carneiro on 14/10/19.
//  Copyright © 2019 André Carneiro. All rights reserved.
//

import Foundation
import MetalKit

class TextureManager {
    
    class func loadTexture(device: MTLDevice,
                           textureName: String) throws -> MTLTexture {
        /// Load texture data with optimal parameters for sampling

        let textureLoader = MTKTextureLoader(device: device)

        let textureLoaderOptions = [
            MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.`private`.rawValue)
        ]
        let bundle = Bundle.main

        return try textureLoader.newTexture(name: textureName,
                                            scaleFactor: 1.0,
                                            bundle: bundle,
                                            options: textureLoaderOptions)

    }

}
