//
//  VisionPhysicsApp.swift
//  VisionPhysics
//
//  Created by Jeff Meador on 2/4/24.
//

import SwiftUI
import RealityKit

// App

@main
struct VisionPhysicsApp: App {
   @StateObject var model = VisionPhysicsViewModel()

    var body: some SwiftUI.Scene {
        ImmersiveSpace {
            RealityView { content in
                content.add(model.setupContentEntity())
            }
            .task {
                await model.runSession()
            }
            .task {
                await model.processHandUpdates()
            }
            .task {
                await model.processReconstructionUpdates()
            }
            .gesture(SpatialTapGesture().targetedToAnyEntity().onEnded({ value in
                let location3D = value.convert(value.location3D, from: .global, to: .scene)
                model.addCube(tapLocation: location3D)
            }))
        }
    }
}
