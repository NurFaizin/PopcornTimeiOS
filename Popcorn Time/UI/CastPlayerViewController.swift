

import UIKit
import PopcornTorrent
import GoogleCast
import JGProgressHUD
import SwiftyTimer


class CastPlayerViewController: UIViewController, GCKRemoteMediaClientListener, PCTPickerViewDelegate {
    
    @IBOutlet var progressSlider: PCTProgressSlider!
    @IBOutlet var volumeSlider: UISlider?
    @IBOutlet var closeButton: PCTBlurButton!
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var backgroundImageView: UIImageView!
    @IBOutlet var elapsedTimeLabel: UILabel!
    @IBOutlet var remainingTimeLabel: UILabel!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var playPauseButton: UIButton!
    @IBOutlet var compactConstraints: [NSLayoutConstraint]!
    @IBOutlet var regularConstraints: [NSLayoutConstraint]!
    
    private var classContext = 0
    private var elapsedTimer: NSTimer!
    private var observingValues: Bool = false
    private var bufferView: JGProgressHUD = {
       let hud = JGProgressHUD(style: .Dark)
        hud.textLabel.text = "Buffering"
        hud.interactionType = .BlockAllTouches
        return hud
    }()
    private var subtitleColors: [String: UIColor] = {
        var colorDict = [String: UIColor]()
        for (index, color) in UIColor.systemColors().enumerate() {
            colorDict[UIColor.systemColorStrings()[index]] = color
        }
        return colorDict
    }()
    private var subtitleFonts: [String: UIFont] = {
        var fontDict = [String: UIFont]()
        for familyName in UIFont.familyNames() {
            for fontName in UIFont.fontNamesForFamilyName(familyName) {
                let font = UIFont(name: fontName, size: 25)!; let traits = font.fontDescriptor().symbolicTraits
                if !traits.contains(.TraitCondensed) && !traits.contains(.TraitBold) && !traits.contains(.TraitItalic) && !fontName.contains("Thin") && !fontName.contains("Light") && !fontName.contains("Medium") && !fontName.contains("Black") {
                    fontDict[fontName] = UIFont(name: fontName, size: 25)
                }
            }
        }
        fontDict["Default"] = UIFont.systemFontOfSize(25)
        return fontDict
    }()
    private var subtitles = ["None": ""]
    private var selectedSubtitleMeta: [String]
    
    var backgroundImage: UIImage?
    var media: PCTItem! {
        didSet {
            if let subtitles = media.subtitles {
                var subtitleDict = [String: String]()
                for subtitle in subtitles {
                    subtitleDict[subtitle.language] = subtitle.link
                }
                self.subtitles += subtitleDict
                self.selectedSubtitleMeta[0] = media.currentSubtitle?.language ?? NSUserDefaults.standardUserDefaults().stringForKey("PreferredSubtitleLanguage") ?? "None"
            }
        }
    }
    var directory: NSURL!
    var pickerView: PCTPickerView!
    
    private var remoteMediaClient = GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient
    private var timeSinceLastMediaStatusUpdate: NSTimeInterval {
        if let remoteMediaClient = remoteMediaClient where state == .Playing {
            return remoteMediaClient.timeSinceLastMediaStatusUpdate
        }
        return 0.0
    }
    private var streamPosition: NSTimeInterval {
        get {
            if let mediaStatus = remoteMediaClient?.mediaStatus {
                return mediaStatus.streamPosition + timeSinceLastMediaStatusUpdate
            }
            return 0.0
        } set {
            remoteMediaClient?.seekToTimeInterval(newValue, resumeState: GCKMediaResumeState.Play)
        }
    }
    private var state: GCKMediaPlayerState {
        return remoteMediaClient?.mediaStatus?.playerState ?? GCKMediaPlayerState.Unknown
    }
    private var idleReason: GCKMediaPlayerIdleReason {
        return remoteMediaClient?.mediaStatus?.idleReason ?? GCKMediaPlayerIdleReason.None
    }
    private var streamDuration: NSTimeInterval {
        return remoteMediaClient?.mediaStatus?.mediaInformation?.streamDuration ?? 0.0
    }
    private var elapsedTime: VLCTime {
        return VLCTime(number: NSNumber(double: streamPosition * 1000))
    }
    private var remainingTime: VLCTime {
        return VLCTime(number: NSNumber(double: (streamPosition - streamDuration) * 1000))
    }
    
    @IBAction func playPause(sender: UIButton) {
        if state == .Paused {
            remoteMediaClient?.play()
        } else if state == .Playing {
            remoteMediaClient?.pause()
        }
    }
    
    @IBAction func rewind() {
        streamPosition -= 30
    }
    
    @IBAction func fastForward() {
        streamPosition += 30
    }
    
    @IBAction func subtitles(sender: UIButton) {
        pickerView.toggle()
    }
    
    @IBAction func volumeSliderAction() {
        remoteMediaClient?.setStreamVolume(volumeSlider!.value)
    }
    
    @IBAction func progressSliderAction() {
        streamPosition += (NSTimeInterval(progressSlider.value) * streamDuration)
    }
    
    @IBAction func progressSliderDrag() {
        remoteMediaClient?.pause()
        elapsedTimeLabel.text = VLCTime(number: NSNumber(double: ((NSTimeInterval(progressSlider.value) * streamDuration)) * 1000)).stringValue
        remainingTimeLabel.text = VLCTime(number: NSNumber(double: (((NSTimeInterval(progressSlider.value) * streamDuration) - streamDuration)) * 1000)).stringValue
    }
    
    @IBAction func close() {
        if observingValues {
            remoteMediaClient?.mediaStatus?.removeObserver(self, forKeyPath: "playerState")
        }
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        remoteMediaClient?.stop()
        PTTorrentStreamer.sharedStreamer().cancelStreaming()
        if NSUserDefaults.standardUserDefaults().boolForKey("removeCacheOnPlayerExit") {
            try! NSFileManager.defaultManager().removeItemAtURL(directory)
        }
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    override func traitCollectionDidChange(previousTraitCollection: UITraitCollection?) {
        for constraint in compactConstraints {
            constraint.priority = traitCollection.horizontalSizeClass == .Compact ? 999 : traitCollection.horizontalSizeClass == .Regular && traitCollection.verticalSizeClass == .Regular ? 240 : constraint.priority
        }
        for constraint in regularConstraints {
            constraint.priority = traitCollection.horizontalSizeClass == .Compact ? 240 : traitCollection.horizontalSizeClass == .Regular && traitCollection.verticalSizeClass == .Regular ? 999 : constraint.priority
        }
        UIView.animateWithDuration(animationLength, animations: {
            self.view.layoutIfNeeded()
        })
    }
    
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if context == &classContext,  let newValue = change?[NSKeyValueChangeNewKey] {
            if keyPath == "playerState" {
                let type: TraktTVAPI.type = media is PCTMovie ? .Movies : .Shows
                bufferView.dismiss()
                switch GCKMediaPlayerState(rawValue: newValue as! Int)! {
                case .Paused:
                    TraktTVAPI.sharedInstance.scrobble(media.id, progress: progressSlider.value, type: type, status: .Paused)
                    playPauseButton.setImage(UIImage(named: "Play"), forState: .Normal)
                    elapsedTimer.invalidate()
                    elapsedTimer = nil
                case .Playing:
                    TraktTVAPI.sharedInstance.scrobble(media.id, progress: progressSlider.value, type: type, status: .Watching)
                    playPauseButton.setImage(UIImage(named: "Pause"), forState: .Normal)
                    if elapsedTimer == nil {
                        elapsedTimer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: #selector(updateTime), userInfo: nil, repeats: true)
                    }
                case .Buffering:
                    playPauseButton.setImage(UIImage(named: "Play"), forState: .Normal)
                    bufferView.showInView(view)
                case .Idle:
                    switch idleReason {
                    case .None:
                        break
                    default:
                        TraktTVAPI.sharedInstance.scrobble(media.id, progress: progressSlider.value, type: type, status: .Finished)
                        close()
                    }
                default:
                    break
                }
            }
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
    func updateTime() {
        progressSlider.value = Float(streamPosition/streamDuration)
        remainingTimeLabel.text = remainingTime.stringValue
        elapsedTimeLabel.text = elapsedTime.stringValue
    }
    
    func remoteMediaClient(client: GCKRemoteMediaClient, didUpdateMediaStatus mediaStatus: GCKMediaStatus) {
        if unsafeAddressOf(mediaStatus) != nil // mediaStatus can be uninitialised when this delegate method is called even though it is not marked as an optional value. Stupid google-cast-sdk.
        {
            if !observingValues {
                if let subtitles = media.subtitles, let subtitle = media.currentSubtitle {
                    remoteMediaClient?.setActiveTrackIDs([NSNumber(integer: subtitles.indexOf(subtitle)!)])
                }
                elapsedTimer = elapsedTimer ?? NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: #selector(updateTime), userInfo: nil, repeats: true)
                mediaStatus.addObserver(self, forKeyPath: "playerState", options: .New, context: &classContext)
                observingValues = true
                self.volumeSlider?.setValue(mediaStatus.volume, animated: true)
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        selectedSubtitleMeta = ["None", NSUserDefaults.standardUserDefaults().stringForKey("PreferredSubtitleColor") ?? "White", NSUserDefaults.standardUserDefaults().stringForKey("PreferredSubtitleFont") ?? "Default"]
        super.init(coder: aDecoder)
        remoteMediaClient?.addListener(self)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        pickerView?.setNeedsLayout()
        pickerView?.layoutIfNeeded()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let image = backgroundImage {
            imageView.image = image
            backgroundImageView.image = image
        }
        pickerView = PCTPickerView(superView: view, componentDataSources: [subtitles, subtitleColors, subtitleFonts], delegate: self, selectedItems: selectedSubtitleMeta, attributesForComponents: [nil, NSForegroundColorAttributeName, NSFontAttributeName])
        view.addSubview(pickerView)
        bufferView.showInView(view)
        NSTimer.after(30.0) { [unowned self] in
            if self.bufferView.visible && self.streamPosition == 0.0 {
                self.bufferView.indicatorView = JGProgressHUDErrorIndicatorView()
                self.bufferView.textLabel.text = "Error loading movie."
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(3.0 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), {
                    self.close()
                })
            }
        }
        titleLabel.text = title
        volumeSlider?.setThumbImage(UIImage(named: "Scrubber Image"), forState: .Normal)
    }
    
    func pickerView(pickerView: PCTPickerView, didChange items: [String: AnyObject]) {
        selectedSubtitleMeta = Array(items.keys)
        let trackStyle = GCKMediaTextTrackStyle.createDefault()
        for (index, value) in items.values.enumerate() {
            if let font = value as? UIFont {
                trackStyle.fontFamily = font.familyName
            } else if let color = value as? UIColor {
                trackStyle.foregroundColor = GCKColor(UIColor: color)
            } else if let link = value as? String {
                if link != "None" {
                    downloadSubtitle(link, fileName: NSLocale.langs.allKeysForValue(Array(items.keys)[index]).first! + ".vtt", downloadDirectory: directory, covertToVTT: true, completion: { _ in
                        self.remoteMediaClient?.setActiveTrackIDs([NSNumber(integer: index)])
                    })
                } else {
                    remoteMediaClient?.setActiveTrackIDs(nil)
                }
            }
        }
        remoteMediaClient?.setTextTrackStyle(trackStyle)
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }

}
