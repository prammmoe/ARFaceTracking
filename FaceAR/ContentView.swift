//
//  ContentView.swift
//  FaceAR
//
//  Created by Pramuditha Muhammad Ikhwan on 12/06/25.
//

import SwiftUI
import RealityKit
import ARKit

struct ContentView: View {
    var body: some View {
        FacePaintingViewContainer().edgesIgnoringSafeArea(.all)
    }
}

struct FacePaintingViewContainer: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Setup AR session config
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        arView.session.delegate = context.coordinator
        arView.session.run(configuration, options: [])

        context.coordinator.arView = arView

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    class Coordinator: NSObject, ARSessionDelegate {
        weak var arView: ARView?
        var faceAnchorEntity: AnchorEntity?

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            for anchor in anchors {
                guard let faceAnchor = anchor as? ARFaceAnchor else { continue }
                
                // Create anchor entity for this face
                let anchorEntity = AnchorEntity(anchor: faceAnchor)
                
                // Create mesh from face geometry
                let faceGeometry = faceAnchor.geometry
                let vertices = faceGeometry.vertices.map {
                    SIMD3<Float>($0.x, $0.y, $0.z)
                }
                let triangleIndices = Array(faceGeometry.triangleIndices).map { UInt32($0) }
                
                // Create mesh resource
                var meshDescriptor = MeshDescriptor(name: "FaceMesh")
                meshDescriptor.positions = MeshBuffers.Positions(vertices)
                meshDescriptor.primitives = .triangles(triangleIndices)
                
                do {
                    let meshResource = try MeshResource.generate(from: [meshDescriptor])
                    
                    // Create material with texture
                    var material = UnlitMaterial()
                    if let texture = try? TextureResource.load(named: "ButterflyWings") {
                        material.color = .init(texture: .init(texture))
                    } else {
                        // Fallback if texture not found
                        material.color = .init(tint: .white.withAlphaComponent(0.8))
                    }
                    
                    // Create model entity
                    let faceEntity = ModelEntity(mesh: meshResource, materials: [material])
                    anchorEntity.addChild(faceEntity)
                    
                    // Add to scene
                    arView?.scene.anchors.append(anchorEntity)
                    self.faceAnchorEntity = anchorEntity
                    
                } catch {
                    print("Failed to create mesh resource: \(error)")
                }
            }
        }

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            for anchor in anchors {
                guard let faceAnchor = anchor as? ARFaceAnchor,
                      let anchorEntity = self.faceAnchorEntity,
                      let faceEntity = anchorEntity.children.first as? ModelEntity else { continue }

                // Update mesh with new face geometry
                let faceGeometry = faceAnchor.geometry
                let vertices = faceGeometry.vertices.map {
                    SIMD3<Float>($0.x, $0.y, $0.z)
                }
                let triangleIndices = Array(faceGeometry.triangleIndices).map { UInt32($0) }
                
                var meshDescriptor = MeshDescriptor(name: "UpdatedFaceMesh")
                meshDescriptor.positions = MeshBuffers.Positions(vertices)
                meshDescriptor.primitives = .triangles(triangleIndices)
                
                do {
                    let updatedMeshResource = try MeshResource.generate(from: [meshDescriptor])
                    faceEntity.model?.mesh = updatedMeshResource
                } catch {
                    print("Failed to update mesh resource: \(error)")
                }
            }
        }
        
        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            for anchor in anchors {
                guard anchor is ARFaceAnchor else { continue }
                
                // Remove the anchor entity when face is lost
                if self.faceAnchorEntity != nil {
                    arView?.scene.anchors.removeAll()
                    self.faceAnchorEntity = nil
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
