//
//  Renderer.swift
//  TinyKit
//
//  Created by André Carneiro on 04/10/19.
//  Copyright © 2019 André Carneiro. All rights reserved.
//

// Our platform independent renderer class

import Metal
import MetalKit
import simd

// The 256 byte aligned size of our uniform structure
let alignedUniformsSize = (MemoryLayout<Uniforms>.size + 0xFF) & -0x100

let maxBuffersInFlight = 3

enum RendererError: Error {
    case badVertexDescriptor
}

class Renderer: NSObject, MTKViewDelegate {
    
    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue
    
    var pipelineState: MTLRenderPipelineState
    var depthState: MTLDepthStencilState
    var samplerState: MTLSamplerState
    var vertexDescriptor: MTLVertexDescriptor
    var captureScope: MTLCaptureScope?
    
//    Reusable buffer
    var dynamicUniformBuffer: MTLBuffer
    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    var uniformBufferOffset = 0
    var uniformBufferIndex = 0
    var uniforms: UnsafeMutablePointer<Uniforms>
    
    
    var projectionMatrix: matrix_float4x4 = matrix_float4x4()
    
    init?(tkView: TKView) {
        
        self.device = tkView.device!
        self.commandQueue = self.device.makeCommandQueue()!
        
        let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight
        
        self.dynamicUniformBuffer = self.device.makeBuffer(length:uniformBufferSize,
                                                           options:[MTLResourceOptions.storageModeShared])!
        
        self.dynamicUniformBuffer.label = "UniformBuffer"
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:Uniforms.self, capacity:1)
        
        tkView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        tkView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        tkView.sampleCount = 1
        
        self.vertexDescriptor = Renderer.buildMetalVertexDescriptor()
        
        samplerState = Renderer.buildSamplerState(device: device)
        
        do {
            pipelineState = try Renderer.buildRenderPipelineWithDevice(device: device,
                                                                       metalKitView: tkView,
                                                                       mtlVertexDescriptor: self.vertexDescriptor)
        } catch {
            print("Unable to compile render pipeline state.  Error info: \(error)")
            return nil
        }
        
        let depthStateDesciptor = MTLDepthStencilDescriptor()
        depthStateDesciptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDesciptor.isDepthWriteEnabled = true
        self.depthState = device.makeDepthStencilState(descriptor:depthStateDesciptor)!
        
        super.init()
        
    }
    
    class func buildSamplerState(device: MTLDevice) -> MTLSamplerState {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.normalizedCoordinates = true
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .linear
        return device.makeSamplerState(descriptor: samplerDescriptor)!
    }
    
    class func buildMetalVertexDescriptor() -> MTLVertexDescriptor {
        // Creete a Metal vertex descriptor specifying how vertices will by laid out for input into our render
        //   pipeline and how we'll layout our Model IO vertices
        
        let mtlVertexDescriptor = MTLVertexDescriptor()
        
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].format = MTLVertexFormat.float3
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].bufferIndex = BufferIndex.meshPositions.rawValue
        
        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].format = MTLVertexFormat.float2
        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].bufferIndex = BufferIndex.meshGenerics.rawValue
        
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stride = 12
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepFunction = MTLVertexStepFunction.perVertex
        
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stride = 8
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepFunction = MTLVertexStepFunction.perVertex
        
        return mtlVertexDescriptor
    }
    
    class func buildRenderPipelineWithDevice(device: MTLDevice,
                                             metalKitView: MTKView,
                                             mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTLRenderPipelineState {
        /// Build a render state pipeline object
        let frameworkBundle = Bundle(for: Renderer.self)
        
        let library = try device.makeDefaultLibrary(bundle: frameworkBundle)
        
        let vertexFunction = library.makeFunction(name: "vertexShader")
        let fragmentFunction = library.makeFunction(name: "fragmentShader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "RenderPipeline"
        pipelineDescriptor.sampleCount = metalKitView.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    class func buildMesh(device: MTLDevice,
                         mtlVertexDescriptor: MTLVertexDescriptor, size: TKSize) throws -> MTKMesh {
        /// Create and condition mesh data to feed into a pipeline using the given vertex descriptor
        
        let metalAllocator = MTKMeshBufferAllocator(device: device)
        
        let mdlMesh = MDLMesh(planeWithExtent: simd_float3(Float(size.width),Float(size.height),0), segments: simd_uint2(2,2), geometryType: MDLGeometryType.triangles, allocator: metalAllocator)
        
        let mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlVertexDescriptor)
        
        guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else {
            throw RendererError.badVertexDescriptor
        }
        attributes[VertexAttribute.position.rawValue].name = MDLVertexAttributePosition
        attributes[VertexAttribute.texcoord.rawValue].name = MDLVertexAttributeTextureCoordinate
        
        mdlMesh.vertexDescriptor = mdlVertexDescriptor
        
        return try MTKMesh(mesh:mdlMesh, device:device)
    }
    
    
    class func loadTexture(device: MTLDevice,
                           textureName: String) throws -> MTLTexture {
        /// Load texture data with optimal parameters for sampling
        
        let textureLoader = MTKTextureLoader(device: device)
        
        let textureLoaderOptions = [
            MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.`private`.rawValue)
        ]
        //        let frameworkBundle = Bundle(for: Renderer.self)
        
        return try textureLoader.newTexture(name: textureName,
                                            scaleFactor: 1.0,
                                            bundle: Bundle.main,
                                            options: textureLoaderOptions)
        
    }
    
    private func updateDynamicBufferState() {
        /// Update the state of our uniform buffers before rendering
        
        uniformBufferIndex = (uniformBufferIndex + 1) % maxBuffersInFlight
        
        uniformBufferOffset = alignedUniformsSize * uniformBufferIndex
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to:Uniforms.self, capacity:1)
    }
    
    private func updateGameState(view: MTKView) {
        /// Update any game state before rendering
        
        let timestamp = Date().timeIntervalSinceReferenceDate
        (view as! TKView).scene?.update(timestamp)
        
        //
        
        //        let rotationAxis = simd_float3(0, 1, 0)
        //        let modelMatrix =  matrix4x4_translation(0, 0, 0) * matrix4x4_rotation(radians: 0, axis: rotationAxis)
        //        let viewMatrix = matrix4x4_translation(0, 0, 0) //* matrix4x4_rotation(radians: radians_from_degrees(45), axis: simd_float3(1,0,0)) * matrix4x4_rotation(radians: radians_from_degrees(45), axis: simd_float3(0,0,1))
        //        uniforms[0].modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
        //        print(self.view)
        
        //        let modelToScreen = uniforms[0].projectionMatrix * uniforms[0].modelViewMatrix
        
        //        let debugPoint = modelToScreen * simd_float4(150,150,0,1)
        //        print(modelToScreen)
        //        print("X value: \(debugPoint.x/debugPoint.w)\nY value: \(debugPoint.y/debugPoint.w)\nZ value: \(debugPoint.z/debugPoint.w)\nW value: \(debugPoint.w/debugPoint.w)\n")
        
        //        print(debugPoint)
        //        rotation += 0.01
    }
    
    func setFrameResolution(size: TKSize) {
        let left = -Float(size.width)/2
        let right = -left
        let bottom = -Float(size.height)/2
        let top = -bottom
        projectionMatrix = makeOrthographicMatrix(left: left, right: right, bottom: bottom, top: top, near: 0.1, far: 100.0)
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        /// Respond to drawable size or orientation changes here
        
        //            let aspect = Float(size.width) / Float(size.height)
        
        //            projectionMatrix = makeOrthographicMatrix(left: -400, right: 400, bottom: -300, top: 300, near: 0.1, far: 100.0)
        //            projectionMatrix = matrix_perspective_right_hand(fovyRadians: radians_from_degrees(90), aspectRatio:aspect, nearZ: 0.1, farZ: 100.0)
    }
    
    func draw(in view: MTKView) {
        /// Per frame updates hare
        
        captureScope?.begin()
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            let semaphore = inFlightSemaphore
            commandBuffer.addCompletedHandler { (_ commandBuffer)-> Swift.Void in
                semaphore.signal()
            }
            
            //self.updateDynamicBufferState()
            uniforms[0].projectionMatrix = projectionMatrix
            self.updateDynamicBufferState()
            self.updateGameState(view: view)
            
            /// Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
            ///   holding onto the drawable and blocking the display pipeline any longer than necessary
            let renderPassDescriptor = view.currentRenderPassDescriptor
            
            if let renderPassDescriptor = renderPassDescriptor {
                
                /// Final pass rendering code here
                if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                    renderEncoder.label = "Primary Render Encoder"
                    
                    renderEncoder.pushDebugGroup("Draw Box")
                    
                    //                    TODO: Fix plane normals
                    renderEncoder.setCullMode(.none)
                    
                    renderEncoder.setFrontFacing(.clockwise)
                    
                    renderEncoder.setRenderPipelineState(pipelineState)
                    
                    renderEncoder.setDepthStencilState(depthState)
                    
                    
                    renderEncoder.setVertexSamplerState(self.samplerState, index: 0)
                    renderEncoder.setFragmentSamplerState(self.samplerState, index: 0)
                    
                    
                    if let tkView = view as? TKView, let scene = tkView.scene {
                        drawNodeRecursive(scene, parentTransform: matrix_identity_float4x4, commandEncoder: renderEncoder)
                        
                    }
                    
                    renderEncoder.popDebugGroup()
                    
                    renderEncoder.endEncoding()
                    
                    if let drawable = view.currentDrawable {
                        commandBuffer.present(drawable)
                    }
                }
            }
            
            commandBuffer.commit()
            captureScope?.end()
        }
    }
    
    func drawNodeRecursive(_ node: TKNode, parentTransform: simd_float4x4, commandEncoder: MTLRenderCommandEncoder) {
        let modelMatrix = parentTransform * node.transformMatrix
        if let node = node as? TKSpriteNode {
//            print(node.transformMatrix)
            
            if let mesh = node.mesh, let texture = node.texture?.texture {
                
                var uniformsData = Uniforms(projectionMatrix: self.projectionMatrix, modelViewMatrix: modelMatrix)
                
//                uniforms[0].modelViewMatrix = modelMatrix
                commandEncoder.setVertexBytes(&uniformsData, length: MemoryLayout<Uniforms>.size, index: BufferIndex.uniforms.rawValue)
//                commandEncoder.setFragmentBytes(&uniformsData, length: MemoryLayout<Uniforms>.size, index: BufferIndex.uniforms.rawValue)
//                commandEncoder.setVertexBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
//                commandEncoder.setFragmentBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
                
                
                for (index, element) in mesh.vertexDescriptor.layouts.enumerated() {
                    guard let layout = element as? MDLVertexBufferLayout else {
                        return
                    }
                    
                    if layout.stride != 0 {
                        let buffer = mesh.vertexBuffers[index]
                        commandEncoder.setVertexBuffer(buffer.buffer, offset:buffer.offset, index: index)
                    }
                }
                
                commandEncoder.setFragmentTexture(texture, index: 0)
                
                for submesh in mesh.submeshes {
                    commandEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                         indexCount: submesh.indexCount,
                                                         indexType: submesh.indexType,
                                                         indexBuffer: submesh.indexBuffer.buffer,
                                                         indexBufferOffset: submesh.indexBuffer.offset)
                    
                }
            }
        }
        
        
        
        for child in node.children {
            drawNodeRecursive(child, parentTransform: modelMatrix, commandEncoder: commandEncoder)
        }
    }
    
}
