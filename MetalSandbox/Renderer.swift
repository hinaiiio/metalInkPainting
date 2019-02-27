//
//  Renderer.swift
//  MetalSandbox
//
//  Created by Hina on 2018/08/05.
//  Copyright © 2018 Hina. All rights reserved.
//

import MetalKit

struct Vertex {
    var position: float3
    var color: float4
    var texcood: float2
} 

struct GBunfferVertexUniforms {
    var gBufferViewPorojectionMatrix: float4x4
    var gBufferModelMatrix: float4x4
    var gBufferNormalMatrix: float3x3
}

struct GBufferFragmentUniform {
    var gBuffercameraWorldPosition = float3(0,0,0)
}

struct VertexUniforms {
    var viewPorojectionMatrix: float4x4
    var modelMatrix: float4x4
    var normalMatrix: float3x3
}

struct FragmentUniform {
    var cameraWorldPosition = float3(0,0,0)
}

class Renderer: NSObject {
//    var time: TimeUniform = TimeUniform(time: 0, time2: 0.5)
    var commandQueue: MTLCommandQueue!
    var renderPipelineState: MTLRenderPipelineState!
    var depthStencilState: MTLDepthStencilState!
    var vertexBuffer: MTLBuffer!
    var texture: MTLTexture!
    
    var mesh: MTKMesh!
    var sphereMesh: MTKMesh!
    var bunnyMesh: MTKMesh!
    var time: Float = 0
    var cameraWorldPosition = float3(0, 0, 5)
    var modelMatrix = matrix_identity_float4x4
    var viewMatrix = matrix_identity_float4x4
    var projectionMatrix = matrix_identity_float4x4
    
    var gBufferAlbedoTexture: MTLTexture!
    var gBufferNormalTexture: MTLTexture!
    var gBufferPositionTexture: MTLTexture!
    var gBufferDepthStencilTexture: MTLTexture!
    var gBufferDepthTexture: MTLTexture!
    var gBufferidTexture: MTLTexture!
    var gBufferbwTexture: MTLTexture!
    var gBufferLambertTexture: MTLTexture!
    
    var gBufferDepthStencilState: MTLDepthStencilState!
    var gBufferRenderPassDescriptor: MTLRenderPassDescriptor!
    var gBufferRenderPipeline: MTLRenderPipelineState!
    
    var gBufferCameraWorldPosition = float3(0, 0, 0.5)
    var gBufferModelMatrix = matrix_identity_float4x4
    var gBufferViewMatrix = matrix_identity_float4x4
    var gBufferProjectionMatrix = matrix_identity_float4x4
    
    var filterPipeline:  MTLComputePipelineState!
    var dilationPipeline:  MTLComputePipelineState!
    var erosionPipeline:  MTLComputePipelineState!
    var outTexture: MTLTexture!
    var edgeOutTexture: MTLTexture!
    var edgeOutTexture2: MTLTexture!
    
    var vertices: [Vertex] = [
        Vertex(position: float3(1,-1,0),  color: float4(1,1,1,1), texcood: float2(0, 1)),
        Vertex(position: float3(-1,-1,0), color: float4(0,1,0,1), texcood: float2(1, 1)),
        Vertex(position: float3(-1,1,0),  color: float4(1,0,0,1), texcood: float2(1, 0)),
        
        Vertex(position: float3(1,-1,0),  color: float4(1,1,1,1), texcood: float2(0, 1)),
        Vertex(position: float3(-1,1,0),  color: float4(1,0,0,1), texcood: float2(1, 0)),
        Vertex(position: float3(1,1,0),   color: float4(0,0,1,1), texcood: float2(0, 0))
        ]
    
    init(device: MTLDevice) {
        super.init()
        loadModel(device: device)
        createGBuffers(device: device)
        createCommandQueue(device: device)
        createPipelineState(device: device)
        createBuffers(device: device)
        laplacianFilter(device: device)
        dilation(device: device)
        erosion(device: device)
        loadTexture(device: device)
        //        createMesh(device: device)
    }
    
    func createCommandQueue(device: MTLDevice) {
        commandQueue = device.makeCommandQueue()
    }
    
    func createPipelineState(device: MTLDevice) {
        // The device will make a library for us
        let library = device.makeDefaultLibrary()
        // Our vertex function name
        let vertexFunction = library?.makeFunction(name: "basic_vertex_function")
        // Our fragment function name
        let fragmentFunction = library?.makeFunction(name: "basic_fragment_function")
        // Create basic descriptor
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        // Attach the pixel format that is the same as the MetalView
        renderPipelineDescriptor.colorAttachments[0].pixelFormat                 = .bgra8Unorm
        renderPipelineDescriptor.colorAttachments[0].isBlendingEnabled           = true
        renderPipelineDescriptor.colorAttachments[0].rgbBlendOperation           = .add
        renderPipelineDescriptor.colorAttachments[0].alphaBlendOperation         = .add
        renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor        = .one
        renderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor      = .sourceAlpha
        renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor   = .oneMinusSourceAlpha
        renderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        // Attach the shader functions
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        // Try to update the state of the renderPipeline
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func createBuffers(device: MTLDevice) {
        vertexBuffer = device.makeBuffer(bytes: vertices,
                                         length: MemoryLayout<Vertex>.stride * vertices.count,
                                         options: [])
    }
    
    func loadTexture(device: MTLDevice) {
        let textureLoader = MTKTextureLoader(device: device)
        let url = URL(string:"file:///Users/hina/Desktop/nijimi2.png")
        texture = try! textureLoader.newTexture(URL: url!, options: [:])
//        print(texture.pixelFormat.rawValue)
    }
    
    func createMesh(device: MTLDevice) {
        //build depthstencilstate
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
        
        //create mesh
        let allocator = MTKMeshBufferAllocator(device: device)
        let mdlMesh = MDLMesh.newBox(withDimensions: vector_float3(1),
                                             segments: vector_uint3(2),
                                             geometryType: .triangles,
                                             inwardNormals: false,
                                             allocator: allocator)
//        let mdlMesh = MDLMesh.newEllipsoid(withRadii: vector_float3(1), radialSegments: 12, verticalSegments: 12, geometryType: .triangles, inwardNormals: false, hemisphere: false, allocator: allocator)
        //transform mesh
        mesh = try! MTKMesh(mesh: mdlMesh, device: device)
        //create MTLRenderPipeState
        let vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)
        let renderDescriptor = MTLRenderPipelineDescriptor()
        renderDescriptor.vertexDescriptor = vertexDescriptor
        
        let library = device.makeDefaultLibrary()
        // Our vertex function name
        let vertexFunction = library?.makeFunction(name: "lambertVertex")
        // Our fragment function name
        let fragmentFunction = library?.makeFunction(name: "lambertFragment")
        // Attach the pixel format that is the same as the MetalView
        renderDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        // Attach the shader functions
        renderDescriptor.vertexFunction = vertexFunction
        renderDescriptor.fragmentFunction = fragmentFunction
        
        renderDescriptor.depthAttachmentPixelFormat = MTLPixelFormat.depth32Float_stencil8
        renderDescriptor.stencilAttachmentPixelFormat = MTLPixelFormat.depth32Float_stencil8
        // Try to update the state of the renderPipeline
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: renderDescriptor)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func loadModel(device: MTLDevice) {
        //create vertex fromat
        let mtlVertex = MTLVertexDescriptor()
        mtlVertex.attributes[0].format = .float3
        mtlVertex.attributes[0].offset = 0
        mtlVertex.attributes[0].bufferIndex = 0
        mtlVertex.attributes[1].format = .float3
        mtlVertex.attributes[1].offset = 12
        mtlVertex.attributes[1].bufferIndex = 0
        mtlVertex.attributes[2].format = .float2
        mtlVertex.attributes[2].offset = 24
        mtlVertex.attributes[2].bufferIndex = 0
        mtlVertex.layouts[0].stride = 32
        mtlVertex.layouts[0].stepRate = 1
        
        let modelDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlVertex)
        (modelDescriptor.attributes[0] as! MDLVertexAttribute).name = MDLVertexAttributePosition
        (modelDescriptor.attributes[1] as! MDLVertexAttribute).name = MDLVertexAttributeNormal
        (modelDescriptor.attributes[2] as! MDLVertexAttribute).name = MDLVertexAttributeTextureCoordinate
        
        //load model
        let url = URL(string:"file:///Users/hina/Desktop/bunny_normal.obj")
//        let url = URL(string:"file:///Users/hina/Desktop/teapot.obj")
//        let url = URL(string:"file:///Users/hina/Desktop/box.obj")
        let allocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(url: url!, vertexDescriptor: modelDescriptor, bufferAllocator: allocator)
        
        bunnyMesh = try! MTKMesh.newMeshes(asset: asset, device: device).metalKitMeshes.first!
    }
    
    func createGBuffers (device: MTLDevice) {
        //To be used for the size of the render textures
        let drawableWidth = 480
        let drawableHeight = 480
        let library = device.makeDefaultLibrary()!
        
        // -- BEGIN GBUFFER PASS PREP -- //
        // Create GBuffer albedo texture
        let gBufferAlbedoTextureDescriptor: MTLTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: drawableWidth, height: drawableHeight, mipmapped: false)
        gBufferAlbedoTextureDescriptor.sampleCount = 1
        gBufferAlbedoTextureDescriptor.storageMode = .private
        gBufferAlbedoTextureDescriptor.textureType = .type2D
        gBufferAlbedoTextureDescriptor.usage = [.renderTarget, .shaderRead]
        gBufferAlbedoTexture = device.makeTexture(descriptor: gBufferAlbedoTextureDescriptor)
        
        // Create GBuffer normal texture
        let gBufferNormalTextureDescriptor: MTLTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: drawableWidth, height: drawableHeight, mipmapped: false)
        gBufferNormalTextureDescriptor.sampleCount = 1
        gBufferNormalTextureDescriptor.storageMode = .private
        gBufferNormalTextureDescriptor.textureType = .type2D
        gBufferNormalTextureDescriptor.usage = [.renderTarget, .shaderRead]
        gBufferNormalTexture = device.makeTexture(descriptor: gBufferNormalTextureDescriptor)
        
        // Create GBuffer position texture
        let gBufferPositionTextureDescriptor: MTLTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: drawableWidth, height: drawableHeight, mipmapped: false)
        gBufferPositionTextureDescriptor.sampleCount = 1
        gBufferPositionTextureDescriptor.storageMode = .private
        gBufferPositionTextureDescriptor.textureType = .type2D
        gBufferPositionTextureDescriptor.usage = [.renderTarget, .shaderRead]
        gBufferPositionTexture = device.makeTexture(descriptor: gBufferPositionTextureDescriptor)
        
        // Create GBuffer depth texture
        let gBufferDepthDescriptor: MTLTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: drawableWidth, height: drawableHeight, mipmapped: false)
        gBufferDepthDescriptor.sampleCount = 1
        gBufferDepthDescriptor.storageMode = .private
        gBufferDepthDescriptor.textureType = .type2D
        gBufferDepthDescriptor.usage = [.renderTarget, .shaderRead]
        gBufferDepthTexture = device.makeTexture(descriptor: gBufferDepthDescriptor)
        
        // Create GBuffer idmap texture
        let gBufferidDescriptor: MTLTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: drawableWidth, height: drawableHeight, mipmapped: false)
        gBufferidDescriptor.sampleCount = 1
        gBufferidDescriptor.storageMode = .private
        gBufferidDescriptor.textureType = .type2D
        gBufferidDescriptor.usage = [.renderTarget, .shaderRead]
        gBufferidTexture = device.makeTexture(descriptor: gBufferidDescriptor)
        
        // Create filtered texture
        let gBufferbwDescriptor: MTLTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: drawableWidth, height: drawableHeight, mipmapped: false)
        gBufferbwDescriptor.sampleCount = 1
        gBufferbwDescriptor.storageMode = .private
        gBufferbwDescriptor.textureType = .type2D
        gBufferbwDescriptor.usage = [.renderTarget, .shaderRead]
        gBufferbwTexture = device.makeTexture(descriptor: gBufferbwDescriptor)
        
        // Create lambert texture
        let gBufferLambertDescriptor: MTLTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: drawableWidth, height: drawableHeight, mipmapped: false)
        gBufferLambertDescriptor.sampleCount = 1
        gBufferLambertDescriptor.storageMode = .private
        gBufferLambertDescriptor.textureType = .type2D
        gBufferLambertDescriptor.usage = [.renderTarget, .shaderRead]
        gBufferLambertTexture = device.makeTexture(descriptor: gBufferLambertDescriptor)
        
        // Create GBuffer depth stencil texture
        let gBufferDepthStencilDesc: MTLTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: MTLPixelFormat.depth32Float_stencil8, width: drawableWidth, height: drawableHeight, mipmapped: false)
        gBufferDepthStencilDesc.sampleCount = 1
        gBufferDepthStencilDesc.storageMode = .private
        gBufferDepthStencilDesc.textureType = .type2D
        gBufferDepthStencilDesc.usage = [.renderTarget, .shaderRead]
        gBufferDepthStencilTexture = device.makeTexture(descriptor: gBufferDepthStencilDesc)
        
        
        // Build GBuffer depth/stencil state
        // Again we create a descriptor that describes the object we're about to create
        let gBufferDepthStencilStateDescriptor: MTLDepthStencilDescriptor = MTLDepthStencilDescriptor()
        gBufferDepthStencilStateDescriptor.isDepthWriteEnabled = true
        gBufferDepthStencilStateDescriptor.depthCompareFunction = .lessEqual
        gBufferDepthStencilStateDescriptor.frontFaceStencil = nil
        gBufferDepthStencilStateDescriptor.backFaceStencil = nil
        gBufferDepthStencilState = device.makeDepthStencilState(descriptor: gBufferDepthStencilStateDescriptor)

        
        // Create GBuffer render pass descriptor
        gBufferRenderPassDescriptor = MTLRenderPassDescriptor()
        // Specify the properties of the first color attachment (our albedo texture)
        gBufferRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0)
        gBufferRenderPassDescriptor.colorAttachments[0].texture = gBufferAlbedoTexture
        gBufferRenderPassDescriptor.colorAttachments[0].loadAction = .clear
        gBufferRenderPassDescriptor.colorAttachments[0].storeAction = .store
        // Specify the properties of the second color attachment (normal texture)
        gBufferRenderPassDescriptor.colorAttachments[1].clearColor = MTLClearColorMake(0, 0, 0, 1)
        gBufferRenderPassDescriptor.colorAttachments[1].texture = gBufferNormalTexture
        gBufferRenderPassDescriptor.colorAttachments[1].loadAction = .clear
        gBufferRenderPassDescriptor.colorAttachments[1].storeAction = .store
        // Specify the properties of the third color attachment (our position texture)
        gBufferRenderPassDescriptor.colorAttachments[2].clearColor = MTLClearColorMake(0, 0, 0, 1)
        gBufferRenderPassDescriptor.colorAttachments[2].texture = gBufferPositionTexture
        gBufferRenderPassDescriptor.colorAttachments[2].loadAction = .clear
        gBufferRenderPassDescriptor.colorAttachments[2].storeAction = .store
        // Specify the properties of the third color attachment (our depth texture)
        gBufferRenderPassDescriptor.colorAttachments[3].clearColor = MTLClearColorMake(0, 0, 0, 1)
        gBufferRenderPassDescriptor.colorAttachments[3].texture = gBufferDepthTexture
        gBufferRenderPassDescriptor.colorAttachments[3].loadAction = .clear
        gBufferRenderPassDescriptor.colorAttachments[3].storeAction = .store
        // Specify the properties of the third color attachment (our id texture)
        gBufferRenderPassDescriptor.colorAttachments[4].clearColor = MTLClearColorMake(0.98, 0.91, 0.73, 1.0)
        gBufferRenderPassDescriptor.colorAttachments[4].texture = gBufferidTexture
        gBufferRenderPassDescriptor.colorAttachments[4].loadAction = .clear
        gBufferRenderPassDescriptor.colorAttachments[4].storeAction = .store
        // Specify the properties of the third color attachment (our b/w id texture)
        gBufferRenderPassDescriptor.colorAttachments[5].clearColor = MTLClearColorMake(0, 0, 0, 1)
        gBufferRenderPassDescriptor.colorAttachments[5].texture = gBufferbwTexture
        gBufferRenderPassDescriptor.colorAttachments[5].loadAction = .clear
        gBufferRenderPassDescriptor.colorAttachments[5].storeAction = .store
        // Specify the properties of the third color attachment (our lambert texture)
        gBufferRenderPassDescriptor.colorAttachments[6].clearColor = MTLClearColorMake(0, 0, 0, 1)
        gBufferRenderPassDescriptor.colorAttachments[6].texture = gBufferLambertTexture
        gBufferRenderPassDescriptor.colorAttachments[6].loadAction = .clear
        gBufferRenderPassDescriptor.colorAttachments[6].storeAction = .store
        // Specify the properties of the depth attachment
        gBufferRenderPassDescriptor.depthAttachment.loadAction = .clear
        gBufferRenderPassDescriptor.depthAttachment.storeAction = .store
        gBufferRenderPassDescriptor.depthAttachment.texture = gBufferDepthStencilTexture
        gBufferRenderPassDescriptor.depthAttachment.clearDepth = 1.0
        // Specify the properties of the stencil attachment
        gBufferRenderPassDescriptor.stencilAttachment.loadAction = .clear
        gBufferRenderPassDescriptor.stencilAttachment.storeAction = .store
        gBufferRenderPassDescriptor.stencilAttachment.texture = gBufferDepthStencilTexture
        gBufferRenderPassDescriptor.stencilAttachment.clearStencil = 0
        
//        //create mesh
//        let allocator = MTKMeshBufferAllocator(device: device)
////        let mdlMesh = MDLMesh.newBox(withDimensions: vector_float3(1),
////                                     segments: vector_uint3(2),
////                                     geometryType: .triangles,
////                                     inwardNormals: false,
////                                     allocator: allocator)
//        let mdlMesh = MDLMesh.newEllipsoid(withRadii: vector_float3(1), radialSegments: 12, verticalSegments: 12, geometryType: .triangles, inwardNormals: false, hemisphere: false, allocator: allocator)
//        sphereMesh = try! MTKMesh(mesh: mdlMesh, device: device)
        
        // Create GBuffer renderpipeline
        let gBufferRenderPipelineDesc = MTLRenderPipelineDescriptor()
        let vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(bunnyMesh.vertexDescriptor)
        gBufferRenderPipelineDesc.vertexDescriptor = vertexDescriptor
        
        gBufferRenderPipelineDesc.colorAttachments[0].pixelFormat = .rgba16Float
        
        gBufferRenderPipelineDesc.colorAttachments[0].isBlendingEnabled = true
        gBufferRenderPipelineDesc.colorAttachments[0].rgbBlendOperation = .add
        gBufferRenderPipelineDesc.colorAttachments[0].sourceRGBBlendFactor = .one
        gBufferRenderPipelineDesc.colorAttachments[0].destinationRGBBlendFactor = .one
        gBufferRenderPipelineDesc.colorAttachments[0].alphaBlendOperation = .add
        gBufferRenderPipelineDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
        gBufferRenderPipelineDesc.colorAttachments[0].destinationAlphaBlendFactor = .one
        
        gBufferRenderPipelineDesc.colorAttachments[1].pixelFormat = .rgba16Float
        gBufferRenderPipelineDesc.colorAttachments[2].pixelFormat = .rgba16Float
        gBufferRenderPipelineDesc.colorAttachments[3].pixelFormat = .rgba16Float
        gBufferRenderPipelineDesc.colorAttachments[4].pixelFormat = .rgba16Float
        gBufferRenderPipelineDesc.colorAttachments[5].pixelFormat = .rgba16Float
        gBufferRenderPipelineDesc.colorAttachments[6].pixelFormat = .rgba16Float
        gBufferRenderPipelineDesc.depthAttachmentPixelFormat = MTLPixelFormat.depth32Float_stencil8
        gBufferRenderPipelineDesc.stencilAttachmentPixelFormat = MTLPixelFormat.depth32Float_stencil8
        gBufferRenderPipelineDesc.sampleCount = 1
        gBufferRenderPipelineDesc.label = "GBuffer Render"
        gBufferRenderPipelineDesc.vertexFunction = library.makeFunction(name: "gBufferVert")
        gBufferRenderPipelineDesc.fragmentFunction = library.makeFunction(name: "gBufferFrag")
        
        do {
            gBufferRenderPipeline = try device.makeRenderPipelineState(descriptor: gBufferRenderPipelineDesc)
        } catch let error {
            fatalError("Failed to create GBuffer pipeline state, error \(error)")
        }
    }
    
    func laplacianFilter(device: MTLDevice) {
        let library = device.makeDefaultLibrary()
        let function = library?.makeFunction(name: "kernel_laplacian_func")
        let outTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: Int(gBufferidTexture.width), height: Int(gBufferidTexture.height), mipmapped: false)
        outTextureDescriptor.usage = [.shaderRead, .shaderWrite]
        outTexture = device.makeTexture(descriptor: outTextureDescriptor)
        do {
            filterPipeline = try device.makeComputePipelineState(function: function!)
        } catch let error {
            fatalError("Failed to filter pipeline state, error \(error)")
        }
    }
    
    func dilation(device: MTLDevice) {
        let library = device.makeDefaultLibrary()
        let function = library?.makeFunction(name: "kernel_dilation_func")
        let outTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: Int(gBufferidTexture.width), height: Int(gBufferidTexture.height), mipmapped: false)
        outTextureDescriptor.usage = [.shaderRead, .shaderWrite]
        edgeOutTexture = device.makeTexture(descriptor: outTextureDescriptor)
        do {
            dilationPipeline = try device.makeComputePipelineState(function: function!)
        } catch let error {
            fatalError("Failed to filter pipeline state, error \(error)")
        }
    }
    
    func erosion(device: MTLDevice) {
        let library = device.makeDefaultLibrary()
        let function = library?.makeFunction(name: "kernel_erosion_func")
        let outTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: Int(gBufferidTexture.width), height: Int(gBufferidTexture.height), mipmapped: false)
        outTextureDescriptor.usage = [.shaderRead, .shaderWrite]
        edgeOutTexture2 = device.makeTexture(descriptor: outTextureDescriptor)
        do {
            erosionPipeline = try device.makeComputePipelineState(function: function!)
        } catch let error {
            fatalError("Failed to filter pipeline state, error \(error)")
        }
    }
}

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        update(view)

        // Get the current drawable and descriptor
        guard let drawable = view.currentDrawable,
        let renderPassDescriptor = view.currentRenderPassDescriptor else {return}
        let gBufferviewProjectionMatrix = gBufferProjectionMatrix * gBufferViewMatrix
//        let viewProjectionMatrix = projectionMatrix * viewMatrix
//        var vertexUnifroms = VertexUniforms(viewPorojectionMatrix: viewProjectionMatrix, modelMatrix: modelMatrix, normalMatrix: modelMatrix.normalMatrix)
        var gBufferVertexUnifroms = GBunfferVertexUniforms(gBufferViewPorojectionMatrix: gBufferviewProjectionMatrix, gBufferModelMatrix: gBufferModelMatrix, gBufferNormalMatrix: gBufferModelMatrix.normalMatrix)
         // ---- GBUFFER ---- //
        // Create a buffer from the commandQueue
        let gBufferCommandBuffer = commandQueue.makeCommandBuffer()
        let gBufferEncoder = gBufferCommandBuffer?.makeRenderCommandEncoder(descriptor: gBufferRenderPassDescriptor)
//        gBufferEncoder?.pushDebugGroup("GBuffer")
//        gBufferEncoder?.label = "GBuffer"
//        gBufferEncoder?.setFrontFacing(.counterClockwise)
        gBufferEncoder?.setRenderPipelineState(gBufferRenderPipeline)
        gBufferEncoder?.setVertexBytes(&gBufferVertexUnifroms, length: MemoryLayout<GBunfferVertexUniforms>.size, index: 1)
        gBufferEncoder?.setCullMode(.front)
        gBufferEncoder?.setDepthStencilState(gBufferDepthStencilState)
        gBufferEncoder?.setVertexBuffer(bunnyMesh.vertexBuffers[0].buffer, offset: 0, index: 0)
        gBufferEncoder?.drawIndexedPrimitives(type: bunnyMesh.submeshes[0].primitiveType,
                                       indexCount: bunnyMesh.submeshes[0].indexCount,
                                       indexType: bunnyMesh.submeshes[0].indexType,
                                       indexBuffer: bunnyMesh.submeshes[0].indexBuffer.buffer,
                                       indexBufferOffset: bunnyMesh.submeshes[0].indexBuffer.offset)
        gBufferEncoder?.endEncoding()
//        commandBuffer?.present(drawable)
        gBufferCommandBuffer?.commit()
        
         // ---- LAPLACIAN FILTER ---- //
        let filterCommandBuffer = commandQueue.makeCommandBuffer()!
        let filterEncoder = filterCommandBuffer.makeComputeCommandEncoder()!
        filterEncoder.setComputePipelineState(filterPipeline)
        filterEncoder.setTexture(gBufferDepthTexture, index: 0)
        filterEncoder.setTexture(gBufferNormalTexture, index: 1)
        filterEncoder.setTexture(gBufferidTexture, index: 2)
        filterEncoder.setTexture(outTexture, index: 3)
        let w = filterPipeline.threadExecutionWidth
        let h = filterPipeline.maxTotalThreadsPerThreadgroup / w
        let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
        let threadsPerGrid = MTLSize(width: gBufferidTexture.width,
                                     height: gBufferidTexture.height,
                                     depth: 1)
//        let threadgroupsPerGrid = MTLSize(width: (texture.width + w - 1) / w,
//                                          height: (texture.height + h - 1) / h,
//                                          depth: 1)
        filterEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        filterEncoder.endEncoding()
        filterCommandBuffer.commit()
        
         // ---- EDGE FILTER ---- //

//        let edgeFilterCommandBuffer = commandQueue.makeCommandBuffer()!
//        let edgeFilterEncoder = edgeFilterCommandBuffer.makeComputeCommandEncoder()!
//        edgeFilterEncoder.setComputePipelineState(dilationPipeline)
//        edgeFilterEncoder.setTexture(outTexture, index: 0)
//        edgeFilterEncoder.setTexture(edgeOutTexture, index: 1)
//        edgeFilterEncoder.setTexture(gBufferidTexture, index: 2)
//        edgeFilterEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
//        edgeFilterEncoder.endEncoding()
//        edgeFilterCommandBuffer.commit()
//
//        let edgeFilterCommandBuffer2 = commandQueue.makeCommandBuffer()!
//        let edgeFilterEncoder2 = edgeFilterCommandBuffer2.makeComputeCommandEncoder()!
//        edgeFilterEncoder2.setComputePipelineState(dilationPipeline)
//        edgeFilterEncoder2.setTexture(edgeOutTexture, index: 0)
//        edgeFilterEncoder2.setTexture(outTexture, index: 1)
//        edgeFilterEncoder2.setTexture(gBufferidTexture, index: 2)
//        edgeFilterEncoder2.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
//        edgeFilterEncoder2.endEncoding()
//        edgeFilterCommandBuffer2.commit()
//
//        let edgeFilterCommandBuffer4 = commandQueue.makeCommandBuffer()!
//        let edgeFilterEncoder4 = edgeFilterCommandBuffer4.makeComputeCommandEncoder()!
//        edgeFilterEncoder4.setComputePipelineState(erosionPipeline)
//        edgeFilterEncoder4.setTexture(edgeOutTexture, index: 0)
//        edgeFilterEncoder4.setTexture(edgeOutTexture2, index: 1)
//        edgeFilterEncoder4.setTexture(gBufferidTexture, index: 2)
//        edgeFilterEncoder4.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
//        edgeFilterEncoder4.endEncoding()
//        edgeFilterCommandBuffer4.commit()

        // ---- PLANE BUFFER ---- //
        let commandBuffer = commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
//        commandEncoder?.setRenderPipelineState(renderPipelineState)
////                commandEncoder?.setRenderPipelineState(gBufferRenderPipeline)
//        commandEncoder?.setVertexBytes(&vertexUnifroms, length: MemoryLayout<VertexUniforms>.size, index: 1)
//        commandEncoder?.setCullMode(.front)
//        commandEncoder?.setDepthStencilState(depthStencilState)
//        commandEncoder?.setFragmentTexture(gBufferidTexture, index: 0)
//        commandEncoder?.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)
//        //draw input model | draw cube&sphere
//        commandEncoder?.drawIndexedPrimitives(type: mesh.submeshes[0].primitiveType,
//                                              indexCount: mesh.submeshes[0].indexCount,
//                                              indexType: mesh.submeshes[0].indexType,
//                                              indexBuffer: mesh.submeshes[0].indexBuffer.buffer,
//                                              indexBufferOffset: mesh.submeshes[0].indexBuffer.offset)

        //texture render
        commandEncoder?.setRenderPipelineState(renderPipelineState)
        // Pass in the vertexBuffer into index 0
        commandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        // commandEncoder?.setFragmentBytes(&time, length: MemoryLayout<TimeUniform>.size, index: 0)
        commandEncoder?.setFragmentTexture(outTexture, index: 0)
        commandEncoder?.setFragmentTexture(gBufferidTexture, index: 1)
        commandEncoder?.setFragmentTexture(texture, index: 2)
        commandEncoder?.setFragmentTexture(gBufferbwTexture, index: 3)
        commandEncoder?.setFragmentTexture(gBufferLambertTexture, index: 4)
        // Draw primitive at vertexStart 0
        commandEncoder?.drawPrimitives(type: MTLPrimitiveType.triangle, vertexStart: 0, vertexCount: vertices.count)
//        commandEncoder?.drawPrimitives(type: MTLPrimitiveType.triangle, vertexStart: 1, vertexCount: 3)
        commandEncoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
        
    }
    
    func update(_ view: MTKView) {
        let deltaTime = 1 / Float(view.preferredFramesPerSecond)
        time += deltaTime
//        if (time >= 1) {time = 0}
         let aspectRadio = Float(view.drawableSize.width / view.drawableSize.height)
        let angle = -time
//        let angle = 0
        
        //gbuffer pass
        gBufferCameraWorldPosition = float3(0, 0.2, 0.5) //bunny0.8
//        gBufferCameraWorldPosition = float3(0, 0, 5) //teapot
//        gBufferCameraWorldPosition = float3(0, 0, 9) //box
        gBufferViewMatrix = float4x4(translationBy: -gBufferCameraWorldPosition) * float4x4(rotationAbout: float3(1, 0, 0), by: .pi / 6)
        gBufferProjectionMatrix = float4x4(perspectiveProjectionFov: Float.pi / 6, aspectRatio: aspectRadio, nearZ: 0.001, farZ: 100)
        gBufferModelMatrix = float4x4(rotationAbout: float3(0, 1, 0), by:Float(angle)) * float4x4(scaleBy: 2.4)
    
        //second pass
        cameraWorldPosition = float3(0, 0, 5)
        viewMatrix = float4x4(translationBy: -cameraWorldPosition) * float4x4(rotationAbout: float3(1, 0, 0), by: .pi / 6)
        projectionMatrix = float4x4(perspectiveProjectionFov: Float.pi / 6, aspectRatio: aspectRadio, nearZ: 0.001, farZ: 100)
        modelMatrix = float4x4(rotationAbout: float3(0, 1, 0), by: 0.0) * float4x4(scaleBy: 1.8)
    }
}

