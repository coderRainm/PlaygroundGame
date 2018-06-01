//  SceneViewController.swift
//  YellowMen
//
//  Created by CXY on 2017/10/27.
//  Copyright © 2017年 CXY. All rights reserved.
//

import UIKit
import SceneKit



struct Displacement<T> {
    let from: T
    let to: T

    //        var reversed: Displacement<T> {
    //            return Displacement(from: to, to: from)
    //        }
}

enum Action {
    // MARK: Types

    enum Movement: Int {
        case walk, jump, teleport
    }

    /// Displace from a position to a new position with the appropriate `Movement` type.
    case move(Displacement<SCNVector3>, type: Movement)

    /// Rotate between two angles specifying the direction with `clockwise`.
    /// The angle must be specified in radians.
    case turn(Displacement<SCNFloat>, clockwise: Bool)


    /// Run a specific `EventGroup`.
    /// Providing a variation index will use a specific index if possible, falling back to random.
    case run(EventGroup, variation: Int?)


}

extension Action {

    func event(from dis: Displacement<SCNVector3>, type: Action.Movement) -> EventGroup {
        let fromY = dis.from.y
        let toY = dis.to.y

        switch type {
        case .walk:
            if fromY.isClose(to: toY, epiValue: WorldConfiguration.heightTolerance) {
                return .walk
            }
            return fromY < toY ? .walkUpStairs : .walkDownStairs

        case .jump:
            if fromY.isClose(to: toY, epiValue: WorldConfiguration.heightTolerance) {
                return .jumpForward
            }
            return fromY > toY ? .jumpDown : .jumpUp

        case .teleport:
            return .teleport
        }
    }

    /// Provides a mapping of the command to an `EventGroup`.
    var event: EventGroup? {
        switch self {
        case let .move(dis, type):
            return event(from: dis, type: type)

        case .turn(_, let clockwise):
            return clockwise ? .turnRight : .turnLeft

        case let .run(anim, _):
            return anim
            
        }

    }



    /// Returns a random index for one of the possible variations.
    /// Note: `.run(_:variation:)` is special cased to allow specific events to be requested.
    var variationIndex: Int {
        if case let .run(_, index) = self, let variation = index {
            return variation
        }

        if let event = self.event {
            let possibleVariations = EventGroup.allIdentifiersByType[event]
            return possibleVariations?.randomIndex ?? 0
        }

        return 0
    }
}


class SceneViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let sceneName = "3.2"
        let path = Asset.Directory.scenes.path + sceneName

        
        // retrieve the SCNView
        let scnView = self.view as! SCNView
        
        // set the scene to the view
        let scene = SCNScene(named: "WorldResources.scnassets/_Scenes/3.2.scn")!
//        scene.rootNode.addChildNode(baseGridNode)
        
        
        let node = scene.rootNode
        // Set up the camera.
        let cameraNode = node.childNode(withName: "camera", recursively: true)!
        let boundingNode = node.childNode(withName: "Scenery", recursively: true)
        
        var (_, sceneWidth) = (boundingNode?.boundingSphere)!
        // Expand so we make sure to get the whole thing with a bit of overlap.
        sceneWidth *= 2
        
        let dominateDimension = Float(5)
        sceneWidth = max(dominateDimension * 2.5, sceneWidth)
        guard sceneWidth.isFinite && sceneWidth > 0 else { return }
        
        let cameraDistance = Double(cameraNode.position.z)
        let halfSceneWidth = Double(sceneWidth / 2.0)
        let distanceToEdge = sqrt(cameraDistance * cameraDistance + halfSceneWidth * halfSceneWidth)
        let cos = cameraDistance / distanceToEdge
        let sin = halfSceneWidth / distanceToEdge
        let halfAngle = atan2(sin, cos)
        
        cameraNode.camera?.yFov = 2.0 * halfAngle * 180.0 / .pi
    
        
        
        guard let lightNode = node.childNode(withName: DirectionalLightName, recursively: true) else { return }
        
        var light: SCNLight?
        lightNode.enumerateHierarchy { node, stop in
            if let directional = node.light {
                light = directional
                stop.initialize(to: true)
            }
        }
        
        light?.orthographicScale = 10
        light?.shadowMapSize = CGSize(width:  2048, height:  2048)
        
        
        
        let actorScene = SCNScene(named: "Characters.scnassets/Byte/NeutralPose.scn")!

        let scnNode = actorScene.rootNode
        scnNode.name = "Actor"
        
        node.addChildNode(scnNode)
        
        
        scnNode.opacity = 1.0
        scnNode.scale = SCNVector3(x: 1, y: 1, z: 1)
        
        // create and add a camera to the scene
//        let actorCamera = SCNNode()
//        actorCamera.position = SCNVector3Make(0, 0.785, 3.25)
//        actorCamera.eulerAngles.x = -0.1530727
//        actorCamera.camera = SCNCamera()
//        actorCamera.name = "actorCamera"
//        scene.rootNode.addChildNode(actorCamera)
        

        
//        // create and add an ambient light to the scene
//        let ambientLightNode = SCNNode()
//        ambientLightNode.light = SCNLight()
//        ambientLightNode.light!.type = .ambient
//        ambientLightNode.light!.color = UIColor.darkGray
//        scene.rootNode.addChildNode(ambientLightNode)
        
        
        scnView.scene = scene
        
        // allows the user to manipulate the camera
        scnView.allowsCameraControl = true
        
        // show statistics such as fps and timing information
//        scnView.showsStatistics = true
        
        // configure the view
//        scnView.backgroundColor = UIColor.black
        
        // add a tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(moveForward))
        scnView.addGestureRecognizer(tapGesture)
    }
    
    @objc func jump() {
        let scnView = self.view as! SCNView
        let scene = scnView.scene
        // retrieve the ship node
        let ship = scene?.rootNode.childNode(withName: "Actor", recursively: true)!

        // animate the 3d object

        let action = SCNAction.moveBy(x: 0, y: 1, z: 0, duration: 1)
        action.timingMode = .easeOut
        ship?.runAction(action, completionHandler: {
            let out = SCNAction.moveBy(x: 0, y: -1, z: 0, duration: 1)
            out.timingMode = .easeIn
            ship?.runAction(out)
        })
    }

    /// Manually calculate the rotation to ensure `w` component is correctly calculated.
    var rotation: SCNFloat {
        get {
//            return scnNode.rotation.y * scnNode.rotation.w
            return 1
        }
//        set {
//            scnNode.rotation = SCNVector4(0, 1, 0, newValue)
//        }
    }

    var position: SCNVector3 {
        get {
//            return scnNode.position
            return SCNVector3Make(0, 0, 0)
        }
//        set {
//            scnNode.position = newValue
//        }
    }

    var nextCoordinateInCurrentDirection: Coordinate {
        return coordinateInCurrentDirection(displacement: 1)
    }

    func coordinateInCurrentDirection(displacement: Int) -> Coordinate {
        let heading = Direction(radians: rotation)
        let coordinate = Coordinate(position)

        return coordinate.advanced(by: displacement, inDirection: heading)
    }


    @objc func moveForward() {
    let nextCoordinate = nextCoordinateInCurrentDirection

    // Check for stairs.
    let yDisplacement = position.y + 2
    let point = nextCoordinate.position

    let destination = SCNVector3Make(point.x, yDisplacement, point.z)
    let displacement = Displacement(from: position, to: destination)

    let action: Action = .move(displacement, type: .walk)


    // Not all commands apply to the actor, return immediately if there is no action.
    guard let event = action.event else {
        fatalError("The actor has been asked to perform \(action), but there is no valid event associated with this action.")
    }

//    let componentResult = component.perform(event: event, variation: index)



    // MARK: ActorComponent


    let animation: CAAnimation?

    // Look for a faster variation of the requested action to play at speeds above `WorldConfiguration.Actor.walkRunSpeed`.

    let speed = WorldConfiguration.Actor.idleSpeed

    let animationCache: AssetCache = AssetCache.cache(forType: .byte)

        let index = 0

//    if speed >= WorldConfiguration.Actor.walkRunSpeed,
//    let fastVariation = event.fastVariation,
//    let fastAnimation = animationCache.animation(for: fastVariation, index: animationStepIndex) {
//
//    animation = fastAnimation
//    animation?.speed = max(speed - WorldConfiguration.Actor.walkRunSpeed, 1)
//    animationStepIndex = animationStepIndex == 0 ? 1 : 0
//    }
//    else {
    animation = animationCache.animation(for: event, index: index)
    animation?.speed = speed
//    }

    guard let readyAnimation = animation?.copy() as? CAAnimation else { return }
    readyAnimation.setDefaultAnimationValues(isStationary: event.isStationary)

    readyAnimation.stopCompletionBlock = { [weak self] isFinished in
        guard isFinished else { return }
    }
    // Move the character after the animation completes.
//    self?.completeCurrentCommand()


    // Remove any lingering animations that may still be attached to the node.
        let scnView = self.view as! SCNView
        let scene = scnView.scene
        // retrieve the ship node
        let animationNode = scene?.rootNode.childNode(withName: "Actor", recursively: true)!
        animationNode?.addAnimation(readyAnimation, forKey: event.rawValue)

    // Set the current animation duration.
//    currentAnimationDuration = readyAnimation.duration / Double(readyAnimation.speed)

    }

    @objc func turn() {
        let scnView = self.view as! SCNView
        let scene = scnView.scene
        // retrieve the ship node
        let ship = scene?.rootNode.childNode(withName: "Actor", recursively: true)!

        // animate the 3d object
        ship?.runAction(SCNAction.rotateBy(x: 0, y: 1, z: 0, duration: 1))
    }

    @objc func handleTap(_ gestureRecognize: UIGestureRecognizer) {
        // retrieve the SCNView
        let scnView = self.view as! SCNView

        // check what nodes are tapped
        let p = gestureRecognize.location(in: scnView)
        let hitResults = scnView.hitTest(p, options: [:])
        // check that we clicked on at least one object
        if hitResults.count > 0 {
            // retrieved the first clicked object
            let result = hitResults[0]

            // get its material
            let material = result.node.geometry!.firstMaterial!

            // highlight it
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5

            // on completion - unhighlight
            SCNTransaction.completionBlock = {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.5

                material.emission.contents = UIColor.black

                SCNTransaction.commit()
            }

            material.emission.contents = UIColor.red

            SCNTransaction.commit()
        }
    }

}
