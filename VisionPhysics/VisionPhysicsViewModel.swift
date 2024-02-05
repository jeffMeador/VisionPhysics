//
//  VisionPhysicsViewModel.swift
//  VisionPhysics
//
//  Created by Jeff Meador on 2/4/24.
//

// View model

import RealityKit
import Foundation
import ARKit

@MainActor class VisionPhysicsViewModel: ObservableObject {
    private let session = ARKitSession()
    private let handTracking = HandTrackingProvider()
    private let sceneReconstruction = SceneReconstructionProvider()

    private var contentEntity = Entity()

    private var meshEntities = [UUID: ModelEntity]()

    private let fingerEntities: [HandAnchor.Chirality: ModelEntity] = [
        .left: .createFingertip(),
        .right: .createFingertip()
    ]

    func setupContentEntity() -> Entity {
        for entity in fingerEntities.values {
            contentEntity.addChild(entity)
        }
        
        return contentEntity
    }

    func runSession() async {
        
        let authorizationResult = await session.requestAuthorization(for: [.worldSensing, .handTracking])

       for (authorizationType, authorizationStatus) in authorizationResult {
           print("Authorization status for \(authorizationType): \(authorizationStatus)")

           // Do something for a real app
           switch authorizationStatus {
           case .allowed:
               continue
           case .denied:
               return
           case .notDetermined:
               return
           @unknown default:
               return
           }
       }
        
        do {
            try await session.run([sceneReconstruction, handTracking])
        } catch {
            print ("Failed to start session: \(error)")
        }
    }

    func processHandUpdates() async {
        for await update in handTracking.anchorUpdates {
            let handAnchor = update.anchor
            
            guard handAnchor.isTracked else { continue }
            
            // Changed these from fingers to hands basically
            guard let fingertip = handAnchor.handSkeleton?.joint(.middleFingerIntermediateBase) else { continue }
            
            guard fingertip.isTracked else { continue }
            
            let originFromWrist = handAnchor.originFromAnchorTransform
            let wristFromIndex = fingertip.anchorFromJointTransform
            let originFromIndex = originFromWrist * wristFromIndex
            
            fingerEntities[handAnchor.chirality]?.setTransformMatrix(originFromIndex, relativeTo: nil)
        }
    }
        
    func processReconstructionUpdates() async {
        for await update in sceneReconstruction.anchorUpdates {
            let meshAnchor = update.anchor
            
            guard let shape = try? await ShapeResource.generateStaticMesh(from: meshAnchor) else { continue }
            
            switch update.event {
            case .added:

                let entity = ModelEntity()
                entity.name = "Plane \(meshAnchor.id)"
                
                // Generate a mesh resource for occlusion
                var meshResource: MeshResource? = nil
                do {
                    let contents = MeshResource.Contents(meshGeometry: meshAnchor.geometry)
                    meshResource = try MeshResource.generate(from: contents)
                } catch {
                    print("Failed to create a mesh resource for a plane anchor: \(error).")
                    return
                }
                
                if let meshResource {
                    // Make this mesh occlude virtual objects behind it.
                    entity.components.set(ModelComponent(mesh: meshResource, materials: [OcclusionMaterial()]))
                }
                
                entity.transform = Transform(matrix: meshAnchor.originFromAnchorTransform)
                entity.collision = CollisionComponent(shapes: [shape], isStatic: true)
                entity.physicsBody = PhysicsBodyComponent()
                entity.components.set(InputTargetComponent())
                
                meshEntities[meshAnchor.id] = entity
                contentEntity.addChild(entity)
            case .updated:
                guard let entity = meshEntities[meshAnchor.id] else { fatalError("...") }
                entity.transform = Transform(matrix: meshAnchor.originFromAnchorTransform)
                entity.collision?.shapes = [shape]
            case .removed:
                meshEntities[meshAnchor.id]?.removeFromParent()
                meshEntities.removeValue(forKey: meshAnchor.id)
            }
        }
    }
        
    func addCube(tapLocation: SIMD3<Float>) {
        let placementLocation = tapLocation + SIMD3<Float>(0, 1, 0)

        let entity = ModelEntity(
            mesh: .generateSphere(radius: 0.1),
            materials: [SimpleMaterial(color: .gray, isMetallic: true)],
            collisionShape: .generateSphere(radius: 0.1),
            mass: 1.0)
        
        entity.setPosition(placementLocation, relativeTo: nil)
        entity.components.set(InputTargetComponent(allowedInputTypes: .indirect))
        
        let material = PhysicsMaterialResource.generate(friction: 0, restitution: 1)
        entity.components.set(PhysicsBodyComponent(shapes: entity.collision!.shapes,
                                                   mass: 0.01,
                                                   material: material,
                                                   mode: .dynamic))
        
        contentEntity.addChild(entity)
    }
}
