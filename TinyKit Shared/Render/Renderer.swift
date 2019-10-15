//
//  Renderer.swift
//  TemporaryMetal
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

struct VertexUniforms {
    var viewProjectionMatrix: float4x4
    var modelMatrix: float4x4
    var normalMatrix: float3x3
}

struct FragmentUniforms {
    var cameraWorldPosition = simd_float3(0, 0, 0)
    var ambientLightColor = simd_float3(0, 0, 0)
    var specularColor = simd_float3(1, 1, 1)
    var specularPower = Float(1)
//    var light0 = Light()
//    var light1 = Light()
//    var light2 = Light()
}

class Renderer: NSObject, MTKViewDelegate {

    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue
    var dynamicUniformBuffer: MTLBuffer
    var pipelineState: MTLRenderPipelineState
    var depthState: MTLDepthStencilState
    var samplerState: MTLSamplerState
    var vertexDescriptor: MTLVertexDescriptor
    var captureScope: MTLCaptureScope?

    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)

    var uniformBufferOffset = 0

    var uniformBufferIndex = 0

    var uniforms: UnsafeMutablePointer<Uniforms>

    var projectionMatrix: matrix_float4x4 = matrix_float4x4()
    
//    var customDrawBuffer : MTLBuffer
//    var customDrawPtr : UnsafeMutablePointer<simd_float3>
//    var customPoints : [simd_float3]

    init?(metalKitView: MTKView) {

        self.device = metalKitView.device!
        self.commandQueue = self.device.makeCommandQueue()!

        let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight

        self.dynamicUniformBuffer = self.device.makeBuffer(length:uniformBufferSize,
                                                           options:[MTLResourceOptions.storageModeShared])!
        
//        let points = [simd_float3(-150,-150,0),
//                      simd_float3(-150,150,0),
//                      simd_float3(150,-150,0),
//                      simd_float3(150,150,0),]
        
//        let pointsBufferSize = (MemoryLayout<Float>.size * 3) * points.count

//        #if os(iOS) || os(tvOS) || os(watchOS)
//        self.customDrawBuffer = self.device.makeBuffer(length: pointsBufferSize, options: [MTLResourceOptions.storageModeShared])!
//        #elseif os(OSX)
//        self.customDrawBuffer = self.device.makeBuffer(length: pointsBufferSize, options: [MTLResourceOptions.storageModeManaged])!
//        #endif
        
        
//        self.customDrawPtr = UnsafeMutableRawPointer(customDrawBuffer.contents()).bindMemory(to: simd_float3.self, capacity: points.count)
        
//        let float3Buffer = UnsafeBufferPointer(start: customDrawPtr, count: points.count)
        
//        self.customPoints = Array(float3Buffer)
        
//        withUnsafePointer(to: &customPoints) {
//            print(" the customPoints has address: \($0)")
//        }
        
//        self.customPoints = points
        
//        withUnsafePointer(to: &points) {
//            print(" the points has address: \($0)")
//        }
//
//        withUnsafePointer(to: &customPoints) {
//            print(" the customPoints has address: \($0)")
//        }
//
//        print(customPoints)
        
        self.dynamicUniformBuffer.label = "UniformBuffer"

        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:Uniforms.self, capacity:1)

        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metalKitView.sampleCount = 1

         self.vertexDescriptor = Renderer.buildMetalVertexDescriptor()
        
        samplerState = Renderer.buildSamplerState(device: device)

        do {
            pipelineState = try Renderer.buildRenderPipelineWithDevice(device: device,
                                                                       metalKitView: metalKitView,
                                                                       mtlVertexDescriptor: self.vertexDescriptor)
        } catch {
            print("Unable to compile render pipeline state.  Error info: \(error)")
            return nil
        }

        let depthStateDesciptor = MTLDepthStencilDescriptor()
        depthStateDesciptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDesciptor.isDepthWriteEnabled = true
        self.depthState = device.makeDepthStencilState(descriptor:depthStateDesciptor)!

//        do {
////            mesh = try Renderer.buildMesh(device: device, mtlVertexDescriptor: self.vertexDescriptor)
//            mesh = try Renderer.buildCustomMesh(device: device, mtlVertexDescriptor: self.vertexDescriptor, size: CGSize(width: 300, height: 300))
//
////            let ptr = UnsafeMutableRawPointer(mesh.vertexBuffers[0].buffer.contents()).bindMemory(to: Float.self, capacity: mesh.vertexCount*3)
////
////            let buff = UnsafeBufferPointer(start: ptr, count: mesh.vertexCount*3)
////
////            let arr = Array(buff)
////
////
////
////            let indexPtr = UnsafeMutableRawPointer(mesh.submeshes[0].indexBuffer.buffer.contents()).bindMemory(to: uint16.self, capacity: mesh.submeshes[0].indexCount)
////
////            let indexBuff = UnsafeBufferPointer(start: indexPtr, count: mesh.submeshes[0].indexCount)
////
////            print(arr)
////            print(mesh)
//        } catch {
//            print("Unable to build MetalKit Mesh. Error info: \(error)")
//            return nil
//        }

//        do {
//            colorMap = try Renderer.loadTexture(device: device, textureName: "ColorMap")
//        } catch {
//            print("Unable to load texture. Error info: \(error)")
//            return nil
//        }

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
    
    class func buildCustomMesh(device: MTLDevice, mtlVertexDescriptor: MTLVertexDescriptor, size: CGSize) throws -> MTKMesh {
        
        let metalAllocator = MTKMeshBufferAllocator(device: device)
        
        
        
        let mdlMesh = MDLMesh(planeWithExtent: simd_float3(Float(size.width),Float(size.height),0), segments: simd_uint2(1,1), geometryType: MDLGeometryType.triangles, allocator: metalAllocator)
        let mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlVertexDescriptor)

        guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else {
            throw RendererError.badVertexDescriptor
        }
        attributes[VertexAttribute.position.rawValue].name = MDLVertexAttributePosition
        attributes[VertexAttribute.texcoord.rawValue].name = MDLVertexAttributeTextureCoordinate

        mdlMesh.vertexDescriptor = mdlVertexDescriptor

        return try MTKMesh(mesh:mdlMesh, device:device)
    }

    class func buildMesh(device: MTLDevice,
                         mtlVertexDescriptor: MTLVertexDescriptor, size: TKSize) throws -> MTKMesh {
        /// Create and condition mesh data to feed into a pipeline using the given vertex descriptor

        let metalAllocator = MTKMeshBufferAllocator(device: device)
        
        let mdlMesh = MDLMesh(planeWithExtent: simd_float3(Float(size.width),Float(size.height),0), segments: simd_uint2(2,2), geometryType: MDLGeometryType.triangles, allocator: metalAllocator)
//        let mdlMesh = MDLMesh(boxWithExtent: simd_float3(300, 300, 0), segments: simd_uint3(1,1,1), inwardNormals: false, geometryType: MDLGeometryType.triangles, allocator: metalAllocator)

//        let mdlMesh = MDLMesh.newPlane(withDimensions: simd_float2(300,300), segments: simd_uint2(1,1), geometryType: MDLGeometryType.triangles, allocator: metalAllocator)
//        let mdlMesh = MDLMesh.newBox(withDimensions: SIMD3<Float>(300, 300, 0),
//                                     segments: SIMD3<UInt32>(1, 1, 1),
//                                     geometryType: MDLGeometryType.triangles,
//                                     inwardNormals:false,
//                                     allocator: metalAllocator)

        let mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlVertexDescriptor)

        guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else {
            throw RendererError.badVertexDescriptor
        }
        attributes[VertexAttribute.position.rawValue].name = MDLVertexAttributePosition
        attributes[VertexAttribute.texcoord.rawValue].name = MDLVertexAttributeTextureCoordinate

        mdlMesh.vertexDescriptor = mdlVertexDescriptor

        return try MTKMesh(mesh:mdlMesh, device:device)
    }
    
//    class func buildPlane(device: MTLDevice, mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTKMesh {
//
//        let allocator = MTKMeshBufferAllocator(device: device)
//
//        let mesh = MDLMesh.newPlane(withDimensions: simd_float2(2,2), segments: simd_uint2(1,1), geometryType: MDLGeometryType.triangles, allocator: allocator)
//
//        let mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlVertexDescriptor)
//
//        guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else {
//            throw RendererError.badVertexDescriptor
//        }
//        attributes[VertexAttribute.position.rawValue].name = MDLVertexAttributePosition
//        attributes[VertexAttribute.texcoord.rawValue].name = MDLVertexAttributeTextureCoordinate
//
//        mesh.vertexDescriptor = mdlVertexDescriptor
//
//        return try MTKMesh(mesh:mesh, device:device)
//
//    }

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

    //        let aspect = Float(size.width) / Float(size.height)
        
//            print(size)
            
            
            
//            projectionMatrix = makeOrthographicMatrix(left: -400, right: 400, bottom: -300, top: 300, near: 0.1, far: 100.0)
    //        projectionMatrix = matrix_perspective_right_hand(fovyRadians: radians_from_degrees(90), aspectRatio:aspect, nearZ: 0.1, farZ: 100.0)
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
                    
                    renderEncoder.setVertexBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
                    renderEncoder.setFragmentBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
                    
                    if let tkView = view as? TKView, let scene = tkView.scene {
                        drawNodeRecursive(scene, parentTransform: matrix_identity_float4x4, commandEncoder: renderEncoder)

                    }
                    
                    
//                    for (index, element) in mesh.vertexDescriptor.layouts.enumerated() {
//                        guard let layout = element as? MDLVertexBufferLayout else {
//                            return
//                        }
//
//                        if layout.stride != 0 {
//                            let buffer = mesh.vertexBuffers[index]
//                            renderEncoder.setVertexBuffer(buffer.buffer, offset:buffer.offset, index: index)
//                        }
//                    }
//
//                    renderEncoder.setFragmentTexture(colorMap, index: TextureIndex.color.rawValue)
//
//                    for submesh in mesh.submeshes {
//                        renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
//                                                            indexCount: submesh.indexCount,
//                                                            indexType: submesh.indexType,
//                                                            indexBuffer: submesh.indexBuffer.buffer,
//                                                            indexBufferOffset: submesh.indexBuffer.offset)
//
//                    }
                    
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

            if let mesh = node.mesh, let texture = node.texture?.texture {
//                        let viewProjectionMatrix = projectionMatrix * viewMatrix
//                        var vertexUniforms = VertexUniforms(viewProjectionMatrix: viewProjectionMatrix,
//                                                            modelMatrix: modelMatrix,
//                                                            normalMatrix: modelMatrix.normalMatrix)
//                        commandEncoder.setVertexBytes(&vertexUniforms, length: MemoryLayout<VertexUniforms>.size, index: 1)
            //            cameraWorldPosition = float3(cameraWorldPosition.x+1, 0, cameraWorldPosition.z+1)
//                        var fragmentUniforms = FragmentUniforms(cameraWorldPosition: cameraWorldPosition,
//                                                                ambientLightColor: scene.ambientLightColor,
//                                                                specularColor: node.material.specularColor,
//                                                                specularPower: node.material.specularPower)
//                                                                light0: scene.lights[0],
//                                                                light1: scene.lights[1],
//                                                                light2: scene.lights[2])
//                        commandEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<FragmentUniforms>.size, index: 0)
                
                
                uniforms[0].modelViewMatrix = modelMatrix
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

//                        let vertexBuffer = mesh.vertexBuffers.first!
//                        commandEncoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: 0)

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
    let ys = 1 / tanf(fovy * 0.5)
    let xs = ys / aspectRatio
    let zs = farZ / (nearZ - farZ)
    //
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
    
    //
    
    
    
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
  let fan = (far + near)
  let fsn = (far - near)
  
  return simd_float4x4(columns: (simd_float4(2.0 / rsl, 0.0, 0.0, 0.0),
                                 simd_float4(0.0, 2.0 / tsb, 0.0, 0.0),
                                 simd_float4(0.0, 0.0, -1 / fsn, 0.0),
                                 simd_float4(-ral / rsl, -tab / tsb, near / fsn, 1.0)))
}

func radians_from_degrees(_ degrees: Float) -> Float {
    return (degrees / 180) * .pi
}
