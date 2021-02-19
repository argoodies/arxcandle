import UIKit
import Mixpanel

enum Setting: String {
    // Bool settings with SettingsViewController switches
    case debugMode
    case scaleWithPinchGesture
    case showHitTestAPI
    case use3DOFTracking
    case use3DOFFallback
	case useOcclusionPlanes

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Setting.scaleWithPinchGesture.rawValue: true
        ])
    }
}
extension UserDefaults {
    func bool(for setting: Setting) -> Bool {
        return bool(forKey: setting.rawValue)
    }
    func set(_ bool: Bool, for setting: Setting) {
        set(bool, forKey: setting.rawValue)
    }
    func integer(for setting: Setting) -> Int {
        return integer(forKey: setting.rawValue)
    }
    func set(_ integer: Int, for setting: Setting) {
        set(integer, forKey: setting.rawValue)
    }
}

class SettingsViewController: UITableViewController {

    @IBOutlet weak var privacyButton: UIButton!
    @IBOutlet weak var mailButton: UIButton!
    @IBOutlet var rateButton: UIButton!
    @IBOutlet weak var shareTimelineButton: UIButton!
    @IBOutlet var watchSupportButton: UIButton!
    
    override func viewWillAppear(_ animated: Bool) {
        
        
        Mixpanel.mainInstance().track(event: "setting")
        
        super.viewWillAppear(animated)
        populateSettings()
    }
    
    @IBAction func linkIntoPrivacy(_ sender: UIButton) {
        let alert = UIAlertController(title: "", message: "是否允许浏览器打开链接", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: "sure"), style: .`default`, handler: { _ in
            
            Mixpanel.mainInstance().track(event: "privacy")
            
            UIApplication.shared.openURL(URL(string: "https://argoodies.github.io/arxcandle-share/#privacy")!)
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: "cancel"), style: .`cancel`, handler: { _ in
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    
    @IBAction func linkIntoMail(_ sender: UIButton) {
        let alert = UIAlertController(title: "", message: "是否允许启动邮箱", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: "sure"), style: .`default`, handler: { _ in
            Mixpanel.mainInstance().track(event: "mail")
            UIApplication.shared.openURL(URL(string: "mailto:meloalright@gmail.com?subject=ARCandle%20Feedback")!)
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: "cancel"), style: .`cancel`, handler: { _ in
        }))
        self.present(alert, animated: true, completion: nil)
    }

    @IBAction func rateHandler(_ sender: Any) {
        let alert = UIAlertController(title: "", message: "是否允许打开[App Store]", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: "sure"), style: .`default`, handler: { _ in
            
            Mixpanel.mainInstance().track(event: "rate")
            
            UIApplication.shared.openURL(URL(string: "https://itunes.apple.com/app/arxcandle/id1346647915?mt=8")!)
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: "cancel"), style: .`cancel`, handler: { _ in
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func triggerShareTimeline(_ sender: UIButton) {
        let textToShare = "<AR祈福>AR祈福应用-增强现实x祈福"
        
        Mixpanel.mainInstance().track(event: "share")
        
        if let myWebsite = URL(string: "https://apps.apple.com/cn/app/arxcandle/id1346647915") {
            //Enter link to your app here
            let objectsToShare = [textToShare, myWebsite] as [Any]
            let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
            
            //Excluded Activities
            activityVC.excludedActivityTypes = [UIActivityType.airDrop, UIActivityType.addToReadingList]
            //
            
            activityVC.popoverPresentationController?.sourceView = sender
            self.present(activityVC, animated: true, completion: nil)
        }
    }


	private func populateSettings() {
		let defaults = UserDefaults.standard
	}
}
