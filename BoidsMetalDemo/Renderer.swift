//
//  Renderer.swift
//  BoidsMetalDemo
//
//  Created by XiaoFei Shao on 2025/8/25.
//

import MetalKit

struct Vertex {
    var position: SIMD2<Float>
    var color: SIMD4<Float>
    var velocity: SIMD2<Float>
}

class Renderer: NSObject, MTKViewDelegate {
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState!
    var computationPipelineState: MTLComputePipelineState!
    var vertexBuffer: MTLBuffer!
    var numVertices: Int = 0

    override init() {
        super.init()
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device.makeCommandQueue()
        buildPipeline()
        buildComputePipeline()
        buildVertices()
    }

    private func buildPipeline() {
        let library = device.makeDefaultLibrary()
        let vertexFunction = library?.makeFunction(name: "vertex_main")
        let fragmentFunction = library?.makeFunction(name: "fragment_main")

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        pipelineState = try! device.makeRenderPipelineState(descriptor: descriptor)
    }

    private func buildComputePipeline() {
        let library = device.makeDefaultLibrary()
        let kernel = library?.makeFunction(name: "updateVertices")
        computationPipelineState = try! device.makeComputePipelineState(function: kernel!)
    }

    private func buildVertices() {
        numVertices = 1000
        var vertices: [Vertex] = []

        for _ in 0..<numVertices {
            let x = Float.random(in: -0.8...0.8)
            let y = Float.random(in: -0.8...0.8)
            let color = SIMD4<Float>(
                Float.random(in: 0.6...1.0),
                Float.random(in: 0.6...1.0),
                Float.random(in: 0.6...1.0),
                1.0
            )
            let speed: Float = Float.random(in: 0.002...0.006)
            let angle: Float = Float.random(in: 0..<2 * Float.pi)
            let vx = cos(angle) * speed
            let vy = sin(angle) * speed
            vertices.append(Vertex(position: SIMD2<Float>(x, y), color: color, velocity: SIMD2<Float>(vx, vy)))
        }

        vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<Vertex>.stride * vertices.count,
            options: .storageModeShared
        )
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
            let descriptor = view.currentRenderPassDescriptor,
            let commandBuffer = commandQueue.makeCommandBuffer()
        else { return }

        // 计算着色器
        if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
            computeEncoder.setComputePipelineState(computationPipelineState)
            computeEncoder.setBuffer(vertexBuffer, offset: 0, index: 0)

            let gridSize = MTLSize(width: numVertices, height: 1, depth: 1)
            let threadGroupSize = MTLSize(
                width: min(computationPipelineState.maxTotalThreadsPerThreadgroup, numVertices),
                height: 1,
                depth: 1
            )
            computeEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
            computeEncoder.endEncoding()
        }

        // 渲染着色器
        if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
            view.clearColor = MTLClearColorMake(0.02, 0.02, 0.05, 1.0)  // 更深的背景

            renderEncoder.setRenderPipelineState(pipelineState)
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: numVertices)
            renderEncoder.endEncoding()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
