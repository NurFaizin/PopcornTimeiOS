

import UIKit
import SafariServices

class SettingsTableViewController: UITableViewController, PCTTablePickerViewDelegate, PCTPickerViewDelegate {

    @IBOutlet var streamOnCellularSwitch: UISwitch!
    @IBOutlet var removeCacheOnPlayerExitSwitch: UISwitch!
    @IBOutlet var qualitySegmentedControl: UISegmentedControl!
    @IBOutlet var traktSignInButton: UIButton!
    @IBOutlet var openSubsSignInButton: UIButton!
	
	var tablePickerView: PCTTablePickerView!
    var pickerView: PCTPickerView!
    
    var safariViewController: SFSafariViewController!
    let ud = NSUserDefaults.standardUserDefaults()
    var state: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tablePickerView = PCTTablePickerView(superView: view, sourceArray: NSLocale.commonLanguages(), self)
        tabBarController?.view.addSubview(tablePickerView)
        pickerView = PCTPickerView(superView: view, componentDataSources: [[String : AnyObject]](), delegate: self, selectedItems: [String]())
        tabBarController?.view.addSubview(pickerView)
        updateSignedInStatus(traktSignInButton, isSignedIn: ud.boolForKey("AuthorizedTrakt"))
        updateSignedInStatus(openSubsSignInButton, isSignedIn: ud.boolForKey("AuthorizedOpenSubs"))
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(safariLogin(_:)), name: safariLoginNotification, object: nil)
        streamOnCellularSwitch.on = ud.boolForKey("StreamOnCellular")
        removeCacheOnPlayerExitSwitch.on = ud.boolForKey("removeCacheOnPlayerExit")
        for index in 0..<qualitySegmentedControl.numberOfSegments {
            if qualitySegmentedControl.titleForSegmentAtIndex(index) == ud.stringForKey("PreferredQuality") {
                qualitySegmentedControl.selectedSegmentIndex = index
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        pickerView?.setNeedsLayout()
        pickerView?.layoutIfNeeded()
        tablePickerView?.setNeedsLayout()
        tablePickerView?.layoutIfNeeded()
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let cell = tableView.cellForRowAtIndexPath(indexPath)!
        switch indexPath.section {
        case 0 where indexPath.row == 2:
            tablePickerView?.toggle()
        case 2:
            let selectedItem = ud.stringForKey("PreferredSubtitle\(cell.textLabel!.text!.capitalizedString.stringByReplacingOccurrencesOfString(" ", withString: ""))")
            var dict = [String: AnyObject]()
            if indexPath.row == 0 || indexPath.row == 2 {
                for (index, color) in UIColor.systemColors().enumerate() {
                    dict[UIColor.systemColorStrings()[index]] = color
                }
                if indexPath.row == 2 {
                    dict["None"] = UIColor.clearColor()
                }
                pickerView.componentDataSources = [dict]
                pickerView.selectedItems = [selectedItem ?? cell.detailTextLabel!.text!]
                pickerView.attributesForComponents = [NSForegroundColorAttributeName]
            } else if indexPath.row == 1 {
                for size in 16...40 {
                    dict["\(size) pt"] = UIFont.systemFontOfSize(CGFloat(size))
                }
                pickerView.componentDataSources = [dict]
                pickerView.selectedItems = [selectedItem ?? cell.detailTextLabel!.text! + " pt"]
                pickerView.attributesForComponents = [NSFontAttributeName]
            } else if indexPath.row == 3 {
                for familyName in UIFont.familyNames() {
                    for fontName in UIFont.fontNamesForFamilyName(familyName) {
                        let font = UIFont(name: fontName, size: 16)!; let traits = font.fontDescriptor().symbolicTraits
                        if !traits.contains(.TraitCondensed) && !traits.contains(.TraitBold) && !traits.contains(.TraitItalic) && !fontName.contains("Thin") && !fontName.contains("Light") && !fontName.contains("Medium") && !fontName.contains("Black") {
                            dict[fontName] = UIFont(name: fontName, size: 16)
                        }
                    }
                }
                dict["Default"] = UIFont.systemFontOfSize(16)
                pickerView.componentDataSources = [dict]
                pickerView.selectedItems = [selectedItem ?? cell.detailTextLabel!.text!]
                pickerView.attributesForComponents = [NSFontAttributeName]
            } else if indexPath.row == 4 {
                dict = ["Normal": UIFont.systemFontOfSize(16), "Bold": UIFont.boldSystemFontOfSize(16), "Italic": UIFont.italicSystemFontOfSize(16), "Bold-Italic": UIFont.systemFontOfSize(16).boldItalic()]
                pickerView.componentDataSources = [dict]
                pickerView.selectedItems = [selectedItem ?? cell.detailTextLabel!.text!]
                pickerView.attributesForComponents = [NSFontAttributeName]
            }
            pickerView.toggle()
        case 3 where indexPath.row == 1:
            let controller = UIAlertController(title: nil, message: nil, preferredStyle: .Alert)
            controller.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
            do {
                let size = NSFileManager.defaultManager().folderSizeAtPath(downloadsDirectory)
                try NSFileManager.defaultManager().removeItemAtURL(NSURL(fileURLWithPath: downloadsDirectory))
                controller.title = "Success"
                if size == 0 {
                    controller.message = "Cache was already empty, no disk space was reclamed."
                } else {
                    controller.message = "Cleaned \(size) bytes."
                }
            } catch {
                controller.title = "Failed"
                controller.message = "Error cleanining cache."
                print("Error: \(error)")
            }
            presentViewController(controller, animated: true, completion: nil)
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
        case 4 where indexPath.row == 2:
            openUrl("https://github.com/PopcornTimeTV/PopcornTimeiOS/blob/master/NOTICE.md")
        default:
           break
        }
    }
    
    // MARK: - UITableViewDataSource
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAtIndexPath: indexPath)
        switch indexPath.section {
        case 0 where indexPath.row == 2:
            cell.detailTextLabel?.text = "None"
            tablePickerView.selectedItems.removeAll()
            if let preferredSubtitleLanguage = ud.stringForKey("PreferredSubtitleLanguage") where preferredSubtitleLanguage != "None" {
                self.tablePickerView.selectedItems = [preferredSubtitleLanguage]
                cell.detailTextLabel?.text = preferredSubtitleLanguage
            }
        case 2:
            if let string = ud.stringForKey("PreferredSubtitle\(cell.textLabel!.text!.capitalizedString.stringByReplacingOccurrencesOfString(" ", withString: ""))") {
                cell.detailTextLabel?.text = string
            }
        case 4 where indexPath.row == 1:
            cell.detailTextLabel?.text = "\(NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString")!).\(NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleVersion")!)"
        default:
            break
        }
        return cell
    }
    
    func updateSignedInStatus(sender: UIButton, isSignedIn: Bool) {
        sender.setTitle(isSignedIn ? "Sign Out": "Authorize", forState: .Normal)
        sender.setTitleColor(isSignedIn ? UIColor(red: 230.0/255.0, green: 46.0/255.0, blue: 37.0/255.0, alpha: 1.0) : view.window?.tintColor!, forState: .Normal)
    }
    
    // MARK: - PCTTablePickerViewDelegate
    
    func tablePickerView(tablePickerView: PCTTablePickerView, didChange items: [String]) {
        if items.count > 0 {
            ud.setObject(items.first!, forKey: "PreferredSubtitleLanguage")
        } else {
            ud.setObject("None", forKey: "PreferredSubtitleLanguage")
        }
        tableView.reloadData()
    }
    
    func tablePickerView(tablePickerView: PCTTablePickerView, willClose items: [String]) {
        if let indexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
        }
    }
    
    // MARK: - PCTPickerViewDelegate
    
    func pickerView(pickerView: PCTPickerView, didChange items: [String : AnyObject]) {
        if let index = tableView.indexPathForSelectedRow, let text = tableView.cellForRowAtIndexPath(index)?.textLabel?.text {
            ud.setObject(items.keys.first, forKey: "PreferredSubtitle\(text.capitalizedString.stringByReplacingOccurrencesOfString(" ", withString: ""))")
        }
        tableView.reloadData()
    }

    func pickerView(pickerView: PCTPickerView, willClose items: [String : AnyObject]) {
        if let index = tableView.indexPathForSelectedRow {
            tableView.deselectRowAtIndexPath(index, animated: true)
        }
    }
    
    @IBAction func streamOnCellular(sender: UISwitch) {
        ud.setBool(sender.on, forKey: "StreamOnCellular")
    }
    
    @IBAction func removeCacheOnPlayerExit(sender: UISwitch) {
        ud.setBool(sender.on, forKey: "removeCacheOnPlayerExit")
    }
    
    @IBAction func preferredQuality(control: UISegmentedControl) {
        ud.setObject(control.titleForSegmentAtIndex(control.selectedSegmentIndex), forKey: "PreferredQuality")
    }
    
    // MARK: - Authorization
    
    @IBAction func authorizeTraktTV(sender: UIButton) {
        if ud.boolForKey("AuthorizedTrakt") {
            let alert = UIAlertController(title: "Sign Out", message: "Are you sure you want to Sign Out?", preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "Yes", style: .Destructive, handler: { action in
                OAuthCredential.deleteCredentialWithIdentifier("trakt")
                self.ud.setBool(false, forKey: "AuthorizedTrakt")
                self.updateSignedInStatus(sender, isSignedIn: false)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
            presentViewController(alert, animated: true, completion: nil)
        } else {
            state = randomString(length: 15)
            openUrl("https://trakt.tv/oauth/authorize?client_id=a3b34d7ce9a7f8c1bb216eed6c92b11f125f91ee0e711207e1030e7cdc965e19&redirect_uri=PopcornTime%3A%2F%2Ftrakt&response_type=code&state=\(state)")
        }
    }
    
    @IBAction func authorizeOpenSubs(sender: UIButton) {
        if ud.boolForKey("AuthorizedOpenSubs") {
            let alert = UIAlertController(title: "Sign Out", message: "Are you sure you want to Sign Out?", preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "Yes", style: .Destructive, handler: { action in
            
                let credential = NSURLCredentialStorage.sharedCredentialStorage().credentialsForProtectionSpace(OpenSubtitles.sharedInstance.protectionSpace)!.values.first!
                NSURLCredentialStorage.sharedCredentialStorage().removeCredential(credential, forProtectionSpace: OpenSubtitles.sharedInstance.protectionSpace)
                self.ud.setBool(false, forKey: "AuthorizedOpenSubs")
                self.updateSignedInStatus(sender, isSignedIn: false)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
            presentViewController(alert, animated: true, completion: nil)
        } else {
            var alert = UIAlertController(title: "Sign In", message: "VIP account required.", preferredStyle: .Alert)
            alert.addTextFieldWithConfigurationHandler({ (textField) in
                textField.placeholder = "Username"
            })
            alert.addTextFieldWithConfigurationHandler({ (textField) in
                textField.placeholder = "Password"
                textField.secureTextEntry = true
            })
            alert.addAction(UIAlertAction(title: "Sign In", style: .Default, handler: { (action) in
                let credential = NSURLCredential(user: alert.textFields![0].text!, password: alert.textFields![1].text!, persistence: .Permanent)
                NSURLCredentialStorage.sharedCredentialStorage().setCredential(credential, forProtectionSpace: OpenSubtitles.sharedInstance.protectionSpace)
                OpenSubtitles.sharedInstance.login({
                    self.ud.setBool(true, forKey: "AuthorizedOpenSubs")
                    self.updateSignedInStatus(sender, isSignedIn: true)
                    }, error: { error in
                        NSURLCredentialStorage.sharedCredentialStorage().removeCredential(credential, forProtectionSpace: OpenSubtitles.sharedInstance.protectionSpace)
                        alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .Alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
                        self.presentViewController(alert, animated: true, completion: nil)
                })
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
            presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    func openUrl(url: String) {
        safariViewController = SFSafariViewController(URL: NSURL(string: url)!)
        self.safariViewController.view.tintColor = UIColor(red:0.37, green:0.41, blue:0.91, alpha:1.0)
        presentViewController(self.safariViewController, animated: true, completion: nil)
    }
    
    // MARK: - TraktOAuth
    
    func safariLogin(notification: NSNotification) {
        safariViewController.dismissViewControllerAnimated(true, completion: nil)
        let url = notification.object as! NSURL
        let query = url.query!.urlStringValues()
        let state = query["state"]
        guard state != self.state else {
            dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.rawValue), 0)) {
                do {
                    let credential = try OAuthCredential(URLString: "https://api-v2launch.trakt.tv/oauth/token", code: query["code"]!, redirectURI: "PopcornTime://trakt", clientID: TraktTVAPI.sharedInstance.clientId, clientSecret: TraktTVAPI.sharedInstance.clientSecret, useBasicAuthentication: false)
                    OAuthCredential.storeCredential(credential!, identifier: "trakt")
                    dispatch_async(dispatch_get_main_queue(), {
                        self.ud.setBool(true, forKey: "AuthorizedTrakt")
                        self.updateSignedInStatus(self.traktSignInButton, isSignedIn: true)
                    })
                } catch {}
            }
            return
        }
        let error = UIAlertController(title: "Error", message: "Uh Oh! It looks like your connection has been compromised. You may be a victim of Cross Site Request Forgery. If you are on a public WiFi network please disconnect immediately and contact the network administrator.", preferredStyle: .Alert)
        error.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
        error.addAction(UIAlertAction(title: "Learn More", style: .Default, handler: { action in
            UIApplication.sharedApplication().openURL(NSURL(string: "http://www.veracode.com/security/csrf")!)
            self.dismissViewControllerAnimated(true, completion: nil)
        }))
        presentViewController(error, animated: true, completion: nil)
    }
}
