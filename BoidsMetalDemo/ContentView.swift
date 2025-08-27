//
//  ContentView.swift
//  BoidsMetalDemo
//
//  Created by XiaoFei Shao on 2025/8/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            List {
                Text("Boids Metal Demo")
            }
            .navigationSplitViewColumnWidth(ideal: 300, max: 300)
        } detail: {
            MetalView()
                .ignoresSafeArea(edges: .top)
        }
        .background(Color.black)
    }
}

#Preview {
    ContentView()
}
