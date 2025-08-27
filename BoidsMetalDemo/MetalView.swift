//
//  MetalView.swift
//  BoidsMetalDemo
//
//  Created by XiaoFei Shao on 2025/8/25.
//

import MetalKit
import SwiftUI

struct MetalView: NSViewRepresentable {
    func makeCoordinator() -> Renderer {
        Renderer()
    }

    func makeNSView(context: Context) -> some NSView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        
        mtkView.preferredFramesPerSecond = 60  // 设置为60fps
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        
        return mtkView
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {

    }
}
