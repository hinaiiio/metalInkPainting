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
    var renderMeshState: MTLRenderPipelineState!
    var vertexBuffer: MTLBuffer!
    var texture: MTLTexture!
    
    var mesh: MTKMesh!
    var time: Float = 0
    var cameraWorldPosition = float3(0, 0, 2)
    var modelMatrix = matrix_identity_float4x4
    var viewMatrix = matrix_identity_float4x4
    var projectionMatrix = matrix_identity_float4x4
    
    var vertices: [Vertex] = [
        Vertex(position: float3(0,1,0), color: float4(0.5,0,0,1)),
        Vertex(position: float3(-1,-1,0), color: float4(0,1,0,1)),
        Vertex(position: float3(1,-1,0), color: float4(1,1,1,1))
    ]
    
    init(device: MTLDevice) {
        super.init()
        createCommandQueue(device: device)
//        createMesh(device: device)
        loadModel(device: device)
//        createPipelineState(device: device)
//        createBuffers(device: device)
        loadTexture(device: device)
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
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
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
        let url = URL(string:"file:///Users/hina/Desktop/IMG_9264.JPG")
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
            renderMeshState = try device.makeRenderPipelineState(descriptor: renderDescriptor)
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
        let url = URL(string:"file:///Users/hina/Desktop/bunny.obj")
        let allocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(url: url!, vertexDescriptor: modelDescriptor, bufferAllocator: allocator)
        
        mesh = try! MTKMesh.newMeshes(asset: asset, device: device).metalKitMeshes.first!

        let renderDescriptor = MTLRenderPipelineDescriptor()
        renderDescriptor.vertexDescriptor = mtlVertex
        
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
        //build depthstencilstate
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
        
        // Try to update the state of the renderPipeline
        do {
            renderMeshState = try device.makeRenderPipelineState(descriptor: renderDescriptor)
        } catch {
            print(error.localizedDescription)
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
        // Create a buffer from the commandQueue
        let commandBuffer = commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        commandEncoder?.setRenderPipelineState(renderMeshState)
        let viewProjectionMatrix = projectionMatrix * viewMatrix
        var vertexUnifroms = VertexUniforms(viewPorojectionMatrix: viewProjectionMatrix, modelMatrix: modelMatrix, normalMatrix: modelMatrix.normalMatrix)
        
        commandEncoder?.setVertexBytes(&vertexUnifroms, length: MemoryLayout<VertexUniforms>.size, index: 1)
        commandEncoder?.setCullMode(.front)
        commandEncoder?.setDepthStencilState(depthStencilState)
        commandEncoder?.setFragmentTexture(texture, index: 0)
        commandEncoder?.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)
        //draw input model
        commandEncoder?.drawIndexedPrimitives(type: mesh.submeshes[0].primitiveType,
                                              indexCount: mesh.submeshes[0].indexCount,
                                              indexType: mesh.submeshes[0].indexType,
                                              indexBuffer: mesh.submeshes[0].indexBuffer.buffer,
                                              indexBufferOffset: mesh.submeshes[0].indexBuffer.offset)
        //draw cube&sphere
//        commandEncoder?.drawIndexedPrimitives(type: mesh.submeshes[0].primitiveType,
//                                              indexCount: mesh.submeshes[0].indexCount,
//                                              indexType: mesh.submeshes[0].indexType,
//                                              indexBuffer: mesh.submeshes[0].indexBuffer.buffer,
//                                              indexBufferOffset: mesh.submeshes[0].indexBuffer.offset)
        
        //texture render
//        commandEncoder?.setRenderPipelineState(renderPipelineState)
//        // Pass in the vertexBuffer into index 0
//        commandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
//        commandEncoder?.setFragmentBytes(&time, length: MemoryLayout<TimeUniform>.size, index: 0)
//        commandEncoder?.setFragmentTexture(texture, index: 0)
        // Draw primitive at vertexStart 0
//        commandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        commandEncoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
    
    func update(_ view: MTKView) {
        let deltaTime = 1 / Float(view.preferredFramesPerSecond)
        time += deltaTime
//        if (time >= 1) {time = 0}
        
        cameraWorldPosition = float3(0, 0, 0.5)
        viewMatrix = float4x4(translationBy: -cameraWorldPosition) * float4x4(rotationAbout: float3(1, 0, 0), by: .pi / 6)
        
        let aspectRadio = Float(view.drawableSize.width / view.drawableSize.height)
        projectionMatrix = float4x4(perspectiveProjectionFov: Float.pi / 6, aspectRatio: aspectRadio, nearZ: 0.1, farZ: 100)
        
        let angle = -time
        modelMatrix = float4x4(rotationAbout: float3(0, 1, 0), by: angle)
    }
    
}
