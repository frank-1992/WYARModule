//
//  ARView.swift
//  XYARKit
//
//  Created by user on 4/6/22.
//

import UIKit
import ARKit

@available(iOS 13.0, *)
public class ARView: ARSCNView {

    // MARK: Position Testing
    func virtualObject(at point: CGPoint) -> VirtualObject? {
        let hitTestOptions: [SCNHitTestOption: Any] = [.boundingBoxOnly: true]
        let hitTestResults = hitTest(point, options: hitTestOptions)
        
        return hitTestResults.lazy.compactMap { result in
            return VirtualObject.existingObjectContainingNode(result.node)
        }.first
    }
    
    // - MARK: Object anchors
    func addOrUpdateAnchor(for object: VirtualObject) {
        if let anchor = object.anchor {
            session.remove(anchor: anchor)
        }
        
        let newAnchor = ARAnchor(transform: object.simdWorldTransform)
        object.anchor = newAnchor
        session.add(anchor: newAnchor)
    }
}

// MARK: - ARSCNView extensions
@available(iOS 13.0, *)
extension ARSCNView {
    
    func smartHitTest(_ point: CGPoint) -> ARHitTestResult? {
        
        // Perform the hit test.
        let results = hitTest(point, types: [.existingPlaneUsingGeometry])
        
        // 1. Check for a result on an existing plane using geometry.
        if let existingPlaneUsingGeometryResult = results.first(where: { $0.type == .existingPlaneUsingGeometry }) {
            return existingPlaneUsingGeometryResult
        }
        
        // 2. Check for a result on an existing plane, assuming its dimensions are infinite.
        let infinitePlaneResults = hitTest(point, types: .existingPlaneUsingExtent)
        
        if let infinitePlaneResult = infinitePlaneResults.first {
            return infinitePlaneResult
        }
        
        // 3. As a final fallback, check for a result on estimated planes.
        return results.first(where: { $0.type == .estimatedHorizontalPlane })
    }
}

// MARK: - ARSCNView extensions
@available(iOS 13.0, *)
extension ARSCNView {

    func unprojectPoint(_ point: SIMD3<Float>) -> SIMD3<Float> {
        return SIMD3<Float>(unprojectPoint(SCNVector3(point)))
    }
    
    // CastRayForFocusSquarePosition
    func castRay(for query: ARRaycastQuery) -> [ARRaycastResult] {
        return session.raycast(query)
    }

    // GetRaycastQuery
    func getRaycastQuery(for alignment: ARRaycastQuery.TargetAlignment = .any) -> ARRaycastQuery? {
        return raycastQuery(from: screenCenter, allowing: .estimatedPlane, alignment: alignment)
    }
    
    var screenCenter: CGPoint {
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    private func anyPlaneFrom(location: CGPoint) -> (SCNNode, SCNVector3)? {
        let results = hitTest(location, types: ARHitTestResult.ResultType.existingPlaneUsingExtent)
        
        guard !results.isEmpty,
              let anchor = results[0].anchor,
              let node = node(for: anchor) else { return nil }
        
        return (node, SCNVector3.positionFromTransform(results[0].worldTransform))
    }
}

