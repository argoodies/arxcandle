import ARKit
import Foundation
import SceneKit
import UIKit
import SwiftUI
import Photos
import Mixpanel
import AudioToolbox

let sysPeekId:SystemSoundID = 1519

struct CollisionCategory: OptionSet {
    let rawValue: Int
    static let bullets  = CollisionCategory(rawValue: 1 << 0) // 00...01
    static let ship = CollisionCategory(rawValue: 1 << 1) // 00..10
}

class MainViewController: UIViewController, UITextFieldDelegate {

	var dragOnInfinitePlanesEnabled = true
	var currentGesture: Gesture?

	var use3DOFTrackingFallback = false
	var screenCenter: CGPoint?

	let session = ARSession()
	var sessionConfig: ARConfiguration = ARWorldTrackingConfiguration()

	var trackingFallbackTimer: Timer?

	// Use average of recent virtual object distances to avoid rapid changes in object scale.
	var recentVirtualObjectDistances = [CGFloat]()

	let DEFAULT_DISTANCE_CAMERA_TO_OBJECTS = Float(10)
    
    var candle_count = 0
    
    var isDashBoardShow = false
    var isColorShow = false
    
    var textValue = ""

	override func viewDidLoad() {
        super.viewDidLoad()

        Mixpanel.initialize(token: "30df6c53544348b6c2d80cd39e7a718f")

        Mixpanel.mainInstance().track(event: "launch")
    
        Setting.registerDefaults()
        setupScene()
        setupDebug()
        setupUIControls()
		setupFocusSquare()
		updateSettings()
		resetVirtualObject()
        hideAdd() // debug
        
        sceneView.scene.physicsWorld.contactDelegate = self as? SCNPhysicsContactDelegate
        sceneView.scene.physicsWorld.gravity = SCNVector3(x: 0.0, y: 0.0, z: 0.0)
    }

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

        self.configureSession()
		UIApplication.shared.isIdleTimerDisabled = true
		restartPlaneDetection()
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		session.pause()
	}

    // MARK: - ARKit / ARSCNView
    var use3DOFTracking = false {
		didSet {
			if use3DOFTracking {
				sessionConfig = ARWorldTrackingConfiguration()
			}
			sessionConfig.isLightEstimationEnabled = true
			session.run(sessionConfig)
		}
	}
	@IBOutlet var sceneView: ARSCNView!

    // MARK: - Ambient Light Estimation
	func toggleAmbientLightEstimation(_ enabled: Bool) {
        if enabled {
			if !sessionConfig.isLightEstimationEnabled {
				sessionConfig.isLightEstimationEnabled = true
				session.run(sessionConfig)
			}
        } else {
			if sessionConfig.isLightEstimationEnabled {
				sessionConfig.isLightEstimationEnabled = false
				session.run(sessionConfig)
			}
        }
    }

    // MARK: - Virtual Object Loading
	var isLoadingObject: Bool = false {
		didSet {
			DispatchQueue.main.async {
				self.settingsButton.isEnabled = !self.isLoadingObject
				self.addObjectButton.isEnabled = !self.isLoadingObject
			}
		}
	}

 
	@IBOutlet weak var addObjectButton: UIButton!
    
	@IBAction func chooseObject(_ button: UIButton) {
		// Abort if we are about to load another object to avoid concurrent modifications of the scene.
		if isLoadingObject { return }

		textManager.cancelScheduledMessage(forType: .contentPlacement)

		let rowHeight = 49
		let popoverSize = CGSize(width: 250, height: rowHeight * VirtualObjectSelectionViewController.COUNT_OBJECTS)

		let objectViewController = VirtualObjectSelectionViewController(size: popoverSize)
        
        VirtualObjectsManager.shared.setAVirtualObjectPlaced()
        
		objectViewController.delegate = self
		objectViewController.modalPresentationStyle = .popover
		objectViewController.popoverPresentationController?.delegate = self
		self.present(objectViewController, animated: true, completion: nil)

		objectViewController.popoverPresentationController?.sourceView = button
		objectViewController.popoverPresentationController?.sourceRect = button.bounds
    }

    // MARK: - Planes
    var planeStatus = 0;

	var planes = [ARPlaneAnchor: Plane]()

    func addPlane(node: SCNNode, anchor: ARPlaneAnchor) {

        showAdd();

        _ = SCNVector3.positionFromTransform(anchor.transform)

		let plane = Plane(anchor, showDebugVisuals)

		planes[anchor] = plane
		node.addChildNode(plane)
        
        let addButtonImage = UIImage.composeButtonImage(from: UIImage(imageLiteralResourceName: "add"), alpha: 0.8)
        self.addObjectButton.setImage(addButtonImage, for: [])

		textManager.cancelScheduledMessage(forType: .planeEstimation)
        Mixpanel.mainInstance().track(event: "add-plane")
		if !VirtualObjectsManager.shared.isAVirtualObjectPlaced() {
            planeStatus = 1;
		}
	}

	func restartPlaneDetection() {
        //
	}

    // MARK: - Focus Square
    var focusSquare: FocusSquare?

    func setupFocusSquare() {
		focusSquare?.isHidden = true
		focusSquare?.removeFromParentNode()
		focusSquare = FocusSquare()
		sceneView.scene.rootNode.addChildNode(focusSquare!)

		textManager.scheduleMessage("请尝试左右移动摄像机画面", inSeconds: 5.0, messageType: .focusSquare)
    }

	func updateFocusSquare() {
		guard let screenCenter = screenCenter else { return }
		
		let virtualObject = VirtualObjectsManager.shared.getVirtualObjectSelected()
		if virtualObject != nil && sceneView.isNode(virtualObject!, insideFrustumOf: sceneView.pointOfView!) {
			focusSquare?.hide()
		} else {
			focusSquare?.unhide()
		}
		let (worldPos, planeAnchor, _) = worldPositionFromScreenPosition(screenCenter, objectPos: focusSquare?.position)
		if let worldPos = worldPos {
			focusSquare?.update(for: worldPos, planeAnchor: planeAnchor, camera: self.session.currentFrame?.camera)
			textManager.cancelScheduledMessage(forType: .focusSquare)
		}
	}

	// MARK: - Hit Test Visualization

	var hitTestVisualization: HitTestVisualization?

	var showHitTestAPIVisualization = UserDefaults.standard.bool(for: .showHitTestAPI) {
		didSet {
			UserDefaults.standard.set(showHitTestAPIVisualization, for: .showHitTestAPI)
			if showHitTestAPIVisualization {
				hitTestVisualization = HitTestVisualization(sceneView: sceneView)
			} else {
				hitTestVisualization = nil
			}
		}
	}

    // MARK: - Debug Visualizations

	@IBOutlet var featurePointCountLabel: UILabel!

	func refreshFeaturePoints() {
		guard showDebugVisuals else {
			return
		}

		guard let cloud = session.currentFrame?.rawFeaturePoints else {
			return
		}

		DispatchQueue.main.async {
			self.featurePointCountLabel.text = "Features: \(cloud.__count)".uppercased()
		}
	}

    var showDebugVisuals: Bool = UserDefaults.standard.bool(for: .debugMode) {
        didSet {
			featurePointCountLabel.isHidden = !showDebugVisuals
			debugMessageLabel.isHidden = !showDebugVisuals
			messagePanel.isHidden = !showDebugVisuals
			planes.values.forEach { $0.showDebugVisualization(showDebugVisuals) }
			sceneView.debugOptions = []
			if showDebugVisuals {
				sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
			}
            UserDefaults.standard.set(showDebugVisuals, for: .debugMode)
        }
    }

    func setupDebug() {
		messagePanel.layer.cornerRadius = 3.0
		messagePanel.clipsToBounds = true
    }

    // MARK: - UI Elements and Actions

	@IBOutlet weak var messagePanel: UIView!
	@IBOutlet weak var messageLabel: UILabel!
	@IBOutlet weak var debugMessageLabel: UILabel!

	var textManager: TextManager!

    func setupUIControls() {
		textManager = TextManager(viewController: self)
		debugMessageLabel.isHidden = true
		featurePointCountLabel.text = ""
		debugMessageLabel.text = ""
		messageLabel.text = ""
    }

	//@IBOutlet weak var restartExperienceButton: UIButton!
	var restartExperienceButtonIsEnabled = true

	func restartExperience(_ sender: Any) {
		guard restartExperienceButtonIsEnabled, !isLoadingObject else {
			return
		}

		DispatchQueue.main.async {
			self.restartExperienceButtonIsEnabled = false

			self.textManager.cancelAllScheduledMessages()
			self.textManager.dismissPresentedAlert()
			self.textManager.showMessage("进入AR场景")
			self.use3DOFTracking = false

			self.setupFocusSquare()
			self.restartPlaneDetection()

			DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: {
				self.restartExperienceButtonIsEnabled = true
			})
		}
	}
    

    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        
        if contact.nodeA.physicsBody?.categoryBitMask == CollisionCategory.ship.rawValue || contact.nodeB.physicsBody?.categoryBitMask == CollisionCategory.ship.rawValue {
            
            
            self.removeNodeWithAnimation(contact.nodeB, explosion: false)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: { // remove/replace ship after half a second to visualize collision

                self.removeNodeWithAnimation(contact.nodeA, explosion: true)
                //self.addNewShip()
            })
        }
    }
    
    
    func removeNodeWithAnimation(_ node: SCNNode, explosion: Bool) {
        print("remove!!")
    }

    @IBOutlet var buoyancyButton: UIButton!
    @IBOutlet var buoyancyButtonHitArea: UIButton!
    @IBAction func buoyanceHandler(_ sender: Any) {

        AudioServicesPlaySystemSound(sysPeekId);
        
        let spinner = UIActivityIndicatorView()
        spinner.center = buoyancyButton.center
        spinner.bounds.size = CGSize(width: buoyancyButton.bounds.width - 5, height: buoyancyButton.bounds.height - 5)
        buoyancyButton.setImage(#imageLiteral(resourceName: "buttonring"), for: [])
        sceneView.addSubview(spinner)
        spinner.startAnimating()


        Mixpanel.mainInstance().track(event: "wind")
        
        VirtualObjectsManager.shared.extinguishVirtualObjects()
        
        self.textManager.showMessage("正在吹灭蜡烛")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            spinner.removeFromSuperview()
            self.buoyancyButton.setImage(UIImage(named: "buo"), for: [])
        })
    }

    
    @IBOutlet weak var findingText: UILabel!
    

    @IBOutlet var sweepButton: UIButton!
    @IBOutlet var sweepButtonHitArea: UIButton!
    @IBAction func sweepHandler(_ sender: Any) {

        AudioServicesPlaySystemSound(sysPeekId);
        
        let spinner = UIActivityIndicatorView()
        spinner.center = sweepButton.center
        spinner.bounds.size = CGSize(width: sweepButton.bounds.width - 5, height: sweepButton.bounds.height - 5)
        sweepButton.setImage(#imageLiteral(resourceName: "buttonring"), for: [])
        sceneView.addSubview(spinner)
        spinner.startAnimating()
        
        
        let bulletsNode = Bullet()
        
        let (direction, position) = self.getUserVector()
        bulletsNode.position = position
        let bulletDirection = direction
        let X = bulletDirection.x
        let Y = bulletDirection.y
        let Z = bulletDirection.z
        let force:Float = 1.9
        
        Mixpanel.mainInstance().track(event: "sweep")
        VirtualObjectsManager.shared.setAVirtualObjectPlaced()
        
        bulletsNode.physicsBody?.applyForce(SCNVector3(x:X * force, y:Y * force
            , z: Z * force), asImpulse: true)
        self.sceneView.scene.rootNode.addChildNode(bulletsNode)
        
        self.textManager.showMessage("正在清扫")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: {
            spinner.removeFromSuperview()
            VirtualObjectsManager.shared.resetVirtualObjects()
            self.sweepButton.setImage(UIImage(named: "sweep"), for: [])
        })
    }
    

    @IBOutlet weak var promtButton: UIButton!
    @IBAction func promtHandler(_ sender: Any) {

        self.promtAction()
        Mixpanel.mainInstance().track(event: "promt")
        self.promtButton.setImage(UIImage(named: "face"), for: [])

    }


    func promtAction() {
        Mixpanel.mainInstance().track(event: "promt-message")
        let story = "一句话祈福"
        
        let alert = UIAlertController(title: "", message: story, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: NSLocalizedString("愿逝者安息，生者前行。", comment: "string_0"), style: .`default`, handler: { _ in
            self.toastPromtMessage(message: "愿逝者安息，生者前行。")
            Mixpanel.mainInstance().track(event: "promt-action-0")
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("风雨过后，必见彩虹。", comment: "string_1"), style: .`default`, handler: { _ in
            self.toastPromtMessage(message: "风雨过后，必见彩虹。")
            Mixpanel.mainInstance().track(event: "promt-action-1")
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("愿我们永远年轻，永远热泪盈眶。", comment: "string_2"), style: .`default`, handler: { _ in
            self.toastPromtMessage(message: "愿我们永远年轻，永远热泪盈眶。")
            Mixpanel.mainInstance().track(event: "promt-action-2")
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("你若安好，便是晴天。", comment: "string_3"), style: .`default`, handler: { _ in
            self.toastPromtMessage(message: "你若安好，便是晴天。")
            Mixpanel.mainInstance().track(event: "promt-action-3")
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("自定义", comment: "diy"), style: .`default`, handler: { _ in
            self.promtInput()
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: "cancel"), style: .`cancel`, handler: { _ in
        }))
        self.present(alert, animated: true, completion: nil)
        Mixpanel.mainInstance().track(event: "promt-action")
    }
    
    let limitLength = 15
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return true }
        let newLength = text.count + string.characters.count - range.length
        return newLength <= limitLength
    }
    
    func promtInput() {
        let alert = UIAlertController(title: "一句话祈福", message: "", preferredStyle: .alert)

        alert.addTextField(configurationHandler: {(textField: UITextField!) -> Void in
            textField.text = self.textValue
            textField.font = UIFont.systemFont(ofSize: 12)
            textField.delegate = self // Set the delegate
        })

        // 3. Grab the value from the text field, and print it when the user clicks OK.
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { [weak alert] (_) in
            self.textValue = (alert?.textFields![0].text)!
            self.toastPromtMessage(message: self.textValue)
        }))

        // 4. Present the alert.
        self.present(alert, animated: true, completion: nil)
        Mixpanel.mainInstance().track(event: "promt-input")
    }
    
    func toastPromtMessage(message: String = "") {
        if (message.count <= 0) {
            return
        }
        AudioServicesPlaySystemSound(sysPeekId);
        self.textManager.showMessage("AR祈福：\n\n" + message, autoHide: false)
        Mixpanel.mainInstance().track(event: "promt-toast")
    }
    
    
    @IBOutlet weak var settingsButton: UIButton!

	@IBAction func showSettings(_ button: UIButton) {
        let pageViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal)
        
        pageViewController.setViewControllers(
            [UIHostingController(rootView: DashboardView())], direction: .forward, animated: true)

		self.present(pageViewController, animated: true, completion: nil)
	}

    func getUserVector() -> (SCNVector3, SCNVector3) { // (direction, position)
        if let frame = self.sceneView.session.currentFrame {
            let mat = SCNMatrix4(frame.camera.transform) // 4x4 transform matrix describing camera in world space
            let dir = SCNVector3(-1 * mat.m31, -1 * mat.m32, -1 * mat.m33) // orientation of camera in world space
            let pos = SCNVector3(mat.m41, mat.m42, mat.m43) // location of camera in world space
            
            return (dir, pos)
        }
        return (SCNVector3(0, 0, -1), SCNVector3(0, 0, -0.2))
    }
    
    
    @objc
    func dismissSettings() {
		self.dismiss(animated: true, completion: nil)
		updateSettings()
	}

	private func updateSettings() {
		let defaults = UserDefaults.standard

		showDebugVisuals = defaults.bool(for: .debugMode)
		showHitTestAPIVisualization = defaults.bool(for: .showHitTestAPI)
		use3DOFTracking	= defaults.bool(for: .use3DOFTracking)
		use3DOFTrackingFallback = defaults.bool(for: .use3DOFFallback)
		for (_, plane) in planes {
			plane.updateOcclusionSetting()
		}
	}

    // MARK: - Error handling

	func displayErrorMessage(title: String, message: String, allowRestart: Bool = false) {
		textManager.blurBackground()

		if allowRestart {
			let restartAction = UIAlertAction(title: "Reset", style: .default) { _ in
				self.textManager.unblurBackground()
				self.restartExperience(self)
			}
			textManager.showAlert(title: title, message: message, actions: [restartAction])
		} else {
			textManager.showAlert(title: title, message: message, actions: [])
		}
	}
}


// MARK: - ARKit / ARSCNView
extension MainViewController {
	func setupScene() {
		sceneView.setUp(viewController: self, session: session)
		DispatchQueue.main.async {
			self.screenCenter = self.sceneView.bounds.mid
		}
	}

	func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
		textManager.showTrackingQualityInfo(for: camera.trackingState, autoHide: !self.showDebugVisuals)

		switch camera.trackingState {
		case .notAvailable:
            print("notAvailable")
		case .limited:
            self.limitedCallBack()
            self.resetVirtualObject()//每次回到limit都reset一下
			if use3DOFTrackingFallback {
				trackingFallbackTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false, block: { _ in
					self.use3DOFTracking = true
					self.trackingFallbackTimer?.invalidate()
					self.trackingFallbackTimer = nil
				})
			}
		case .normal:
			textManager.cancelScheduledMessage(forType: .trackingStateEscalation)
			if use3DOFTrackingFallback && trackingFallbackTimer != nil {
				trackingFallbackTimer!.invalidate()
				trackingFallbackTimer = nil
			}
		}
	}

	func session(_ session: ARSession, didFailWithError error: Error) {
		guard let arError = error as? ARError else { return }

        Mixpanel.mainInstance().track(event: "camera-crash")

        let alert = UIAlertController(title: "相机权限未开启", message: "AR场景的呈现需要开启相机权限", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("去开启", comment: "sure"), style: .`destructive`, handler: { _ in
            
            let url = NSURL.init(string: UIApplicationOpenSettingsURLString)
            if (UIApplication.shared.canOpenURL(url! as URL)) {
                UIApplication.shared.openURL(url! as URL)
            }
            
            self.present(alert, animated: true, completion: nil)
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
    

	func sessionWasInterrupted(_ session: ARSession) {
		textManager.blurBackground()
		textManager.showAlert(title: "AR场景有扰动",
		                      message: "请稳定摄像机画面")
	}

	func sessionInterruptionEnded(_ session: ARSession) {
		textManager.unblurBackground()
		session.run(sessionConfig, options: [.resetTracking, .removeExistingAnchors])
		restartExperience(self)
		textManager.showMessage("重启AR场景")
	}
    
    func configureSession() {
        if ARWorldTrackingConfiguration.isSupported {
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = ARWorldTrackingConfiguration.PlaneDetection.horizontal
            
            sceneView.session.run(configuration)
        }
        // DEBUG
        // DEBUG
        else {
            let sessionErrorMsg = "该设备不支持ARKit"
            Mixpanel.mainInstance().track(event: "no-arkit")
            displayErrorMessage(title: "", message: sessionErrorMsg, allowRestart: false)
        }
    }
}


// MARK: Gesture Recognized
extension MainViewController {
	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		guard let object = VirtualObjectsManager.shared.getVirtualObjectSelected() else {
			return
		}

		if currentGesture == nil {
			currentGesture = Gesture.startGestureFromTouches(touches, self.sceneView, object)
		} else {
			currentGesture = currentGesture!.updateGestureFromTouches(touches, .touchBegan)
		}

		displayVirtualObjectTransform()
	}

	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		if !VirtualObjectsManager.shared.isAVirtualObjectPlaced() {
			return
		}
		currentGesture = currentGesture?.updateGestureFromTouches(touches, .touchMoved)
		displayVirtualObjectTransform()
	}

	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		if !VirtualObjectsManager.shared.isAVirtualObjectPlaced() {
			return
		}

		currentGesture = currentGesture?.updateGestureFromTouches(touches, .touchEnded)
	}

	override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
		if !VirtualObjectsManager.shared.isAVirtualObjectPlaced() {
			return
		}
		currentGesture = currentGesture?.updateGestureFromTouches(touches, .touchCancelled)
	}
}


// MARK: - UIPopoverPresentationControllerDelegate
extension MainViewController: UIPopoverPresentationControllerDelegate {
	func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
		return .none
	}

	func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
		updateSettings()
	}
}


// MARK: - VirtualObjectSelectionViewControllerDelegate
extension MainViewController :VirtualObjectSelectionViewControllerDelegate {
    

    func getPlaneStatus(_: VirtualObjectSelectionViewController) -> Int {
        return planeStatus
    }
    
    func warningStatus(_: VirtualObjectSelectionViewController) {
    
        self.textManager.showMessage("请继续寻找平面")
        textManager.scheduleMessage("可以尝试离平面远一点", inSeconds: 1, messageType: .contentPlacement)
        return;
    }
    
    func virtualObjectSelectionViewController(_: VirtualObjectSelectionViewController, object: VirtualObject) {
		loadVirtualObject(object: object)
	}

	func loadVirtualObject(object: VirtualObject) {
		// Show progress indicator
    
        candle_count += 1
		let spinner = UIActivityIndicatorView()
		spinner.center = addObjectButton.center
		spinner.bounds.size = CGSize(width: addObjectButton.bounds.width - 5, height: addObjectButton.bounds.height - 5)

		sceneView.addSubview(spinner)
		spinner.startAnimating()

		DispatchQueue.global().async {
			self.isLoadingObject = true
			object.viewController = self
			VirtualObjectsManager.shared.addVirtualObject(virtualObject: object)
			VirtualObjectsManager.shared.setVirtualObjectSelected(virtualObject: object)

            
			object.loadModel()

			DispatchQueue.main.async {
				if let lastFocusSquarePos = self.focusSquare?.lastPosition {
					self.setNewVirtualObjectPosition(lastFocusSquarePos)
				} else {
					self.setNewVirtualObjectPosition(SCNVector3Zero)
				}
                
                self.textManager.showMessage("放置成功")
                AudioServicesPlaySystemSound(sysPeekId);
                self.showDashBoard()
                
                var fire = ""
                if object.title == "白蜡烛" {
                    fire = "red-fire"
                }
                else if object.title == "红蜡烛" {
                    fire = "red-fire"
                }
                else if object.title == "冰蜡烛" {
                    fire = "blue-fire"
                }
                
                if (fire.count > 0) {
                    let particleSystem = SCNParticleSystem(named: fire, inDirectory: nil)
                    object.addParticleSystem(particleSystem!)
                }
                
                spinner.removeFromSuperview()
                Mixpanel.mainInstance().track(event: object.title)

                let buttonImage = UIImage.composeButtonImage(from: object.thumbImage, alpha: 0.8)
                self.addObjectButton.setImage(buttonImage, for: [])
				self.isLoadingObject = false
                self.planeStatus = 2
			}
		}
	}
}


// MARK: - ARSCNViewDelegate
extension MainViewController :ARSCNViewDelegate {
	func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
		refreshFeaturePoints()

		DispatchQueue.main.async {
			self.updateFocusSquare()
			self.hitTestVisualization?.render()

			// If light estimation is enabled, update the intensity of the model's lights and the environment map
			if let lightEstimate = self.session.currentFrame?.lightEstimate {
				self.sceneView.enableEnvironmentMapWithIntensity(lightEstimate.ambientIntensity / 40)
			} else {
				self.sceneView.enableEnvironmentMapWithIntensity(25)
			}
		}
	}

	func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
		DispatchQueue.main.async {
			if let planeAnchor = anchor as? ARPlaneAnchor {
				self.addPlane(node: node, anchor: planeAnchor)
				self.checkIfObjectShouldMoveOntoPlane(anchor: planeAnchor)
			}
		}
	}

	func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
		DispatchQueue.main.async {
			if let planeAnchor = anchor as? ARPlaneAnchor {
				if let plane = self.planes[planeAnchor] {
					plane.update(planeAnchor)
				}
				self.checkIfObjectShouldMoveOntoPlane(anchor: planeAnchor)
			}
		}
	}

	func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
		DispatchQueue.main.async {
			if let planeAnchor = anchor as? ARPlaneAnchor, let plane = self.planes.removeValue(forKey: planeAnchor) {
				plane.removeFromParentNode()
			}
		}
	}
}


// MARK: Virtual Object Manipulation
extension MainViewController {
    
	func displayVirtualObjectTransform() {
		guard let object = VirtualObjectsManager.shared.getVirtualObjectSelected(),
			let cameraTransform = session.currentFrame?.camera.transform else {
			return
		}

		// Output the current translation, rotation & scale of the virtual object as text.
		let cameraPos = SCNVector3.positionFromTransform(cameraTransform)
		let vectorToCamera = cameraPos - object.position

		let distanceToUser = vectorToCamera.length()

		var angleDegrees = Int(((object.eulerAngles.y) * 180) / Float.pi) % 360
		if angleDegrees < 0 {
			angleDegrees += 360
		}

		let distance = String(format: "%.2f", distanceToUser)
		let scale = String(format: "%.2f", object.scale.x)
		textManager.showDebugMessage("距离: \(distance) m\n旋转角: \(angleDegrees)°\n尺寸: \(scale)x")
	}

	func moveVirtualObjectToPosition(_ pos: SCNVector3?, _ instantly: Bool, _ filterPosition: Bool) {

		guard let newPosition = pos else {
			textManager.showMessage("无法放置蜡烛 请在周围尝试")
			// Reset the content selection in the menu only if the content has not yet been initially placed.
			if !VirtualObjectsManager.shared.isAVirtualObjectPlaced() {
				resetVirtualObject()
			}
			return
		}

		if instantly {
			setNewVirtualObjectPosition(newPosition)
		} else {
			updateVirtualObjectPosition(newPosition, filterPosition)
		}
	}

	func worldPositionFromScreenPosition(_ position: CGPoint,
	                                     objectPos: SCNVector3?,
	                                     infinitePlane: Bool = false) -> (position: SCNVector3?,
																		  planeAnchor: ARPlaneAnchor?,
																		  hitAPlane: Bool) {

		let planeHitTestResults = sceneView.hitTest(position, types: .existingPlaneUsingExtent)
		if let result = planeHitTestResults.first {

			let planeHitTestPosition = SCNVector3.positionFromTransform(result.worldTransform)
			let planeAnchor = result.anchor

			// Return immediately - this is the best possible outcome.
			return (planeHitTestPosition, planeAnchor as? ARPlaneAnchor, true)
		}


		var featureHitTestPosition: SCNVector3?
		var highQualityFeatureHitTestResult = false

		let highQualityfeatureHitTestResults =
			sceneView.hitTestWithFeatures(position, coneOpeningAngleInDegrees: 18, minDistance: 0.2, maxDistance: 2.0)

		if !highQualityfeatureHitTestResults.isEmpty {
			let result = highQualityfeatureHitTestResults[0]
			featureHitTestPosition = result.position
			highQualityFeatureHitTestResult = true
		}


		if (infinitePlane && dragOnInfinitePlanesEnabled) || !highQualityFeatureHitTestResult {

			let pointOnPlane = objectPos ?? SCNVector3Zero

			let pointOnInfinitePlane = sceneView.hitTestWithInfiniteHorizontalPlane(position, pointOnPlane)
			if pointOnInfinitePlane != nil {
				return (pointOnInfinitePlane, nil, true)
			}
		}

		if highQualityFeatureHitTestResult {
			return (featureHitTestPosition, nil, false)
		}

		let unfilteredFeatureHitTestResults = sceneView.hitTestWithFeatures(position)
		if !unfilteredFeatureHitTestResults.isEmpty {
			let result = unfilteredFeatureHitTestResults[0]
			return (result.position, nil, false)
		}

		return (nil, nil, false)
	}

	func setNewVirtualObjectPosition(_ pos: SCNVector3) {

		guard let object = VirtualObjectsManager.shared.getVirtualObjectSelected(),
			let cameraTransform = session.currentFrame?.camera.transform else {
			return
		}

		recentVirtualObjectDistances.removeAll()

		let cameraWorldPos = SCNVector3.positionFromTransform(cameraTransform)
		var cameraToPosition = pos - cameraWorldPos
		cameraToPosition.setMaximumLength(DEFAULT_DISTANCE_CAMERA_TO_OBJECTS)

		object.position = cameraWorldPos + cameraToPosition

		if object.parent == nil {
			sceneView.scene.rootNode.addChildNode(object)
		}
	}
    
    func showDashBoard() {
        if (isDashBoardShow == true) {
            return
        }
        promtButton.isHidden = false
        buoyancyButton.isHidden = false
        buoyancyButtonHitArea.isHidden = false
        sweepButton.isHidden = false
        sweepButtonHitArea.isHidden = false
    }

    
    func hideDashBoard() {
        isDashBoardShow = false
        promtButton.isHidden = true
        buoyancyButton.isHidden = true
        buoyancyButtonHitArea.isHidden = true
        sweepButton.isHidden = true
        sweepButtonHitArea.isHidden = true
    }

    func showAdd() {
        if (addObjectButton.isHidden == true) {
            addObjectButton.isHidden = false
        }
        if (findingText.isHidden == false) {
            findingText.isHidden = true
        }
    }
    
    func limitedCallBack() {
        if (findingText.isHidden == false) {
            findingText.text = "请左右移动您的手机"
        }
        // 去掉定时反而很好？
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: {
            if (self.findingText.isHidden == false) {
                self.findingText.text = "请寻找光滑的平面"
            }
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: {
            if (self.findingText.isHidden == false) {
                self.findingText.text = "请左右移动您的手机"
            }
        })
    }

    func hideAdd() {
        addObjectButton.isHidden = true
        findingText.isHidden = false
        findingText.text = "正在检测光滑平面"
    }

	func resetVirtualObject() {
		VirtualObjectsManager.shared.resetVirtualObjects()
        planeStatus = 0
        hideDashBoard()
	}

	func updateVirtualObjectPosition(_ pos: SCNVector3, _ filterPosition: Bool) {
		guard let object = VirtualObjectsManager.shared.getVirtualObjectSelected() else {
			return
		}

		guard let cameraTransform = session.currentFrame?.camera.transform else {
			return
		}

		let cameraWorldPos = SCNVector3.positionFromTransform(cameraTransform)
		var cameraToPosition = pos - cameraWorldPos
		cameraToPosition.setMaximumLength(DEFAULT_DISTANCE_CAMERA_TO_OBJECTS)

		let hitTestResultDistance = CGFloat(cameraToPosition.length())

		recentVirtualObjectDistances.append(hitTestResultDistance)
		recentVirtualObjectDistances.keepLast(10)

		if filterPosition {
			let averageDistance = recentVirtualObjectDistances.average!

			cameraToPosition.setLength(Float(averageDistance))
			let averagedDistancePos = cameraWorldPos + cameraToPosition

			object.position = averagedDistancePos
		} else {
			object.position = cameraWorldPos + cameraToPosition
		}
	}

	func checkIfObjectShouldMoveOntoPlane(anchor: ARPlaneAnchor) {
		guard let object = VirtualObjectsManager.shared.getVirtualObjectSelected(),
			let planeAnchorNode = sceneView.node(for: anchor) else {
			return
		}

		// Get the object's position in the plane's coordinate system.
		let objectPos = planeAnchorNode.convertPosition(object.position, from: object.parent)

		if objectPos.y == 0 {
			return; // The object is already on the plane
		}

		// Add 10% tolerance to the corners of the plane.
		let tolerance: Float = 0.1

		let minX: Float = anchor.center.x - anchor.extent.x / 2 - anchor.extent.x * tolerance
		let maxX: Float = anchor.center.x + anchor.extent.x / 2 + anchor.extent.x * tolerance
		let minZ: Float = anchor.center.z - anchor.extent.z / 2 - anchor.extent.z * tolerance
		let maxZ: Float = anchor.center.z + anchor.extent.z / 2 + anchor.extent.z * tolerance

		if objectPos.x < minX || objectPos.x > maxX || objectPos.z < minZ || objectPos.z > maxZ {
			return
		}

		// Drop the object onto the plane if it is near it.
		let verticalAllowance: Float = 0.03
		if objectPos.y > -verticalAllowance && objectPos.y < verticalAllowance {
			textManager.showDebugMessage("物体在附近放置成功")

			SCNTransaction.begin()
			SCNTransaction.animationDuration = 0.5
			SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
			object.position.y = anchor.transform.columns.3.y
			SCNTransaction.commit()
		}
	}
}
