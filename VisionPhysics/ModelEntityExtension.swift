//
//  ModelEntityExtension.swift
//  VisionPhysics
//
//  Created by Jeff Meador on 2/4/24.
//

import Foundation
import ARKit
import RealityKit

internal extension ModelEntity {
    class func createFingertip() -> ModelEntity {
        let entity = ModelEntity(mesh: .generateSphere(radius: 0.1), materials: [UnlitMaterial(color: .cyan)], collisionShape: .generateSphere(radius: 0.1), mass: 0.0)
        
        entity.components.set(PhysicsBodyComponent(mode: .kinematic))
        entity.components.set(OpacityComponent(opacity: 0.0))
        
        return entity
    }
}
