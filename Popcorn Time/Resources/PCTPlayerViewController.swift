

import UIKit
import MediaPlayer
import PopcornTorrent
import Alamofire
import GZIP
import SRT2VTT

private enum videoDimensions: NSString {
    case FourByThree = "4:3"
    case SixteenByNine = "16:9"
}

protocol PCTPlayerViewControllerDelegate: class {
    func playNext(episode: PCTEpisode)
    func presentCastPlayer(media: PCTItem, videoFilePath: NSURL)
}

class PCTPlayerViewController: UIViewController, UIGestureRecognizerDelegate, UIActionSheetDelegate, VLCMediaPlayerDelegate, SubtitlesTableViewControllerDelegate, UIPopoverPresentationControllerDelegate, UpNextViewDelegate {
    
    // MARK: - IBOutlets
    @IBOutlet var movieView: UIView!
    @IBOutlet var positionSlider: PCTBarSlider!
    @IBOutlet var bufferProgressView: UIProgressView? {
        didSet {
            bufferProgressView?.layer.borderWidth = 0.6
            bufferProgressView?.layer.cornerRadius = 1.0
            bufferProgressView?.clipsToBounds = true
            bufferProgressView?.layer.borderColor = UIColor.darkTextColor().CGColor
        }
    }
    @IBOutlet var volumeSlider: PCTBarSlider! {
        didSet {
            volumeSlider.setValue(AVAudioSession.sharedInstance().outputVolume, animated: false)
        }
    }
    @IBOutlet var loadingView: UIView!
    @IBOutlet var playPauseButton: UIButton!
    @IBOutlet var subtitleSwitcherButton: UIButton!
    @IBOutlet var tapOnVideoRecognizer: UITapGestureRecognizer!
    @IBOutlet var doubleTapToZoomOnVideoRecognizer: UITapGestureRecognizer!
    @IBOutlet var playPauseRegularBottomConstraint: NSLayoutConstraint!
    @IBOutlet var regularConstraints: [NSLayoutConstraint]!
    @IBOutlet var compactConstraints: [NSLayoutConstraint]!
    @IBOutlet var duringScrubbingConstraints: NSLayoutConstraint!
    @IBOutlet var finishedScrubbingConstraints: NSLayoutConstraint!
    @IBOutlet var subtitleSwitcherButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet var scrubbingSpeedLabel: UILabel!
    @IBOutlet var elapsedTimeLabel: UILabel!
    @IBOutlet var remainingTimeLabel: UILabel!
    @IBOutlet var navigationView: UIVisualEffectView!
    @IBOutlet var toolBarView: UIVisualEffectView!
    @IBOutlet var upNextView: UpNextView!
    @IBOutlet var videoDimensionsButton: UIButton!
    
    // MARK: - Slider actions
    
    @IBAction func sliderDidDrag() {
        resetIdleTimer()
    }
    @IBAction func positionSliderDidDrag() {
        resetIdleTimer()
        let streamDuration = (fabsf(mediaplayer.remainingTime.numberValue.floatValue) + mediaplayer.time.numberValue.floatValue)
        elapsedTimeLabel.text = VLCTime(number: NSNumber(float: (positionSlider.value * streamDuration))).stringValue
        remainingTimeLabel.text = VLCTime(number: NSNumber(float: ((positionSlider.value * streamDuration) - streamDuration))).stringValue
        var text = ""
        switch positionSlider.scrubbingSpeed {
        case 1.0:
            text = "Hi-Speed"
        case 0.5:
            text = "Half-Speed"
        case 0.25:
            text = "Quarter-Speed"
        case 0.1:
            text = "Fine"
        default:
            break
        }
        text += " Scrubbing"
        scrubbingSpeedLabel.text = text
    }
    @IBAction func positionSliderTouchedDown() {
        stateBeforeScrubbing = mediaplayer.state
        if mediaplayer.playing {
            mediaplayer.pause()
        }
        UIView.animateWithDuration(animationLength, animations: {
            self.finishedScrubbingConstraints.active = false
            self.duringScrubbingConstraints.active = true
            self.view.layoutIfNeeded()
        })
    }
    @IBAction func volumeSliderAction() {
        resetIdleTimer()
        for subview in volumeView.subviews {
            if let slider = subview as? UISlider {
                slider.setValue(volumeSlider.value, animated: true)
            }
        }
    }
    @IBAction func positionSliderAction() {
        if stateBeforeScrubbing != .Paused {
            mediaplayer.play()
            playPauseButton.setImage(UIImage(named: "Pause"), forState: .Normal)
        }
        mediaplayer.position = positionSlider.value
        view.layoutIfNeeded()
        UIView.animateWithDuration(animationLength, animations: {
            self.duringScrubbingConstraints.active = false
            self.finishedScrubbingConstraints.active = true
            self.view.layoutIfNeeded()
        })
    }
    
    override func nextResponder() -> UIResponder? {
        resetIdleTimer()
        return super.nextResponder()
    }
    
    // MARK: - Button actions
    
    @IBAction func playandPause(sender: UIButton) {
        if mediaplayer.playing {
            mediaplayer.pause()
        } else {
            mediaplayer.play()
        }
    }
    @IBAction func fastForward() {
        mediaplayer.longJumpForward()
    }
    @IBAction func rewind() {
        mediaplayer.longJumpBackward()
    }
    @IBAction func fastForwardHeld(sender: UILongPressGestureRecognizer) {
        resetIdleTimer()
        switch sender.state {
        case .Began:
            fallthrough
        case .Changed:
            mediaplayer.mediumJumpForward()
        default:
            break
        }
        
    }
    @IBAction func rewindHeld(sender: UILongPressGestureRecognizer) {
        resetIdleTimer()
        switch sender.state {
        case .Began:
            fallthrough
        case .Changed:
            mediaplayer.mediumJumpBackward()
        default:
            break
        }
    }
    
    @IBAction func switchVideoDimensions() {
        resetIdleTimer()
        if videoDimensionsButton.imageView?.image == UIImage(named: "Scale To Fill") // Change to aspect to scale to fill
        {
            let screen = UIScreen.mainScreen()
            let f_ar = screen.bounds.size.width / screen.bounds.size.height
            if f_ar == 16.0/9.0 // All Landscape iPhones
            {
                videoDimensionsButton.setImage(UIImage(named: "Scale To Fit"), forState: .Normal)
                currentVideoDimension = .SixteenByNine
                mediaplayer.videoCropGeometry = UnsafeMutablePointer<Int8>(currentVideoDimension!.rawValue.UTF8String)
            } else if f_ar == 4.0/3.0 // All Landscape iPads
            {
                videoDimensionsButton.setImage(UIImage(named: "Scale To Fit"), forState: .Normal)
                currentVideoDimension = .FourByThree
                mediaplayer.videoCropGeometry = UnsafeMutablePointer<Int8>(currentVideoDimension!.rawValue.UTF8String)
            }
        } else // Change aspect ratio to scale to fit
        {
            videoDimensionsButton.setImage(UIImage(named: "Scale To Fill"), forState: .Normal)
            mediaplayer.videoAspectRatio = nil
            mediaplayer.videoCropGeometry = nil
        }
    }
    @IBAction func didFinishPlaying() {
        dismissViewControllerAnimated(true, completion: nil)
        mediaplayer.stop()
        PTTorrentStreamer.sharedStreamer().cancelStreaming()
        if NSUserDefaults.standardUserDefaults().boolForKey("removeCacheOnPlayerExit") {
            try! NSFileManager.defaultManager().removeItemAtURL(directory)
        }
    }
    
    // MARK: - Public vars
    
    weak var delegate: PCTPlayerViewControllerDelegate?
    var subtitles = [PCTSubtitle]()
    var currentSubtitle: PCTSubtitle? {
        didSet {
            if let subtitle = currentSubtitle {
                mediaplayer.numberOfChaptersForTitle(Int32(subtitles.indexOf(subtitle)!)) != NSNotFound ? mediaplayer.currentChapterIndex = Int32(subtitles.indexOf(subtitle)!) : openSubtitles(NSURL(string: subtitle.link)!)
            } else {
                mediaplayer.currentChapterIndex = NSNotFound // Remove all subtitles
            }
        }
    }
    
    // MARK: - Private vars
    
    private (set) var mediaplayer = VLCMediaPlayer()
    private var stateBeforeScrubbing: VLCMediaPlayerState!
    private var currentVideoDimension: videoDimensions? = nil
    private (set) var url: NSURL!
    private (set) var directory: NSURL!
    private (set) var media: PCTItem!
    internal var nextMedia: PCTEpisode?
    private var startPosition: Float = 0.0
    private var idleTimer: NSTimer!
    private var shouldHideStatusBar = true
    private let NSNotFound: Int32 = -1
    private var volumeView: MPVolumeView = {
       let view = MPVolumeView(frame: CGRectMake(-1000, -1000, 100, 100))
        view.sizeToFit()
        return view
    }()
    
    // MARK: - Player functions
    
    func play(media: PCTItem, fromURL url: NSURL, progress fromPosition: Float, nextEpisode: PCTEpisode? = nil, directory: NSURL) {
        self.url = url
        self.media = media
        self.startPosition = fromPosition
        self.nextMedia = nextEpisode
        self.directory = directory
        if let subtitles = media.subtitles {
            self.subtitles = subtitles
            currentSubtitle = media.currentSubtitle
        }
    }
    
    private func openSubtitles(filePath: NSURL) {
        if filePath.fileURL {
            mediaplayer.addPlaybackSlave(NSURL(fileURLWithPath: filePath.relativeString!), type: .Subtitle, enforce: true)
        } else {
            downloadSubtitle(filePath.relativeString!, downloadDirectory: self.directory, covertToVTT: false, completion: { [unowned self] subtitlePath in
                self.mediaplayer.addPlaybackSlave(subtitlePath, type: .Subtitle, enforce: true)
            })
        }
    }
    
    // MARK: - View Methods
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        view.addObserver(self, forKeyPath: "frame", options: NSKeyValueObservingOptions(rawValue: 0), context: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(orientationChanged), name: UIDeviceOrientationDidChangeNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(mediaPlayerStateChanged), name: VLCMediaPlayerStateChanged, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(mediaPlayerTimeChanged), name: VLCMediaPlayerTimeChanged, object: nil)
        
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if startPosition > 0.0 {
            let continueWatchingAlert = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
            continueWatchingAlert.addAction(UIAlertAction(title: "Continue Watching", style: .Default, handler:{ action in
                self.mediaplayer.play()
                self.mediaplayer.position = self.startPosition
                self.positionSlider.value = self.startPosition
            }))
            continueWatchingAlert.addAction(UIAlertAction(title: "Start from beginning", style: .Default, handler: { action in
                self.mediaplayer.play()
            }))
            self.presentViewController(continueWatchingAlert, animated: true, completion: nil)
            
        } else {
            mediaplayer.play()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let font = NSUserDefaults.standardUserDefaults().stringForKey("PreferredSubtitleFont"),
            let name = UIFont(name: font, size: 0)?.familyName {
            (mediaplayer as VLCFontAppearance).setTextRendererFont!(name)
        }
        if let style = NSUserDefaults.standardUserDefaults().stringForKey("PreferredSubtitleFontStyle") {
            (mediaplayer as VLCFontAppearance).setTextRendererFontForceBold!(NSNumber(bool: style == "Bold"))
        }
        if let size = NSUserDefaults.standardUserDefaults().stringForKey("PreferredSubtitleSize") {
            (mediaplayer as VLCFontAppearance).setTextRendererFontSize!(NSNumber(float: Float(size.stringByReplacingOccurrencesOfString(" pt", withString: ""))!))
        }
        if let subtitleColor = NSUserDefaults.standardUserDefaults().stringForKey("PreferredSubtitleColor")?.camelCaseString,
            let color = UIColor.performSelector(Selector(subtitleColor + "Color")).takeRetainedValue() as? UIColor {
            (mediaplayer as VLCFontAppearance).setTextRendererFontColor!(NSNumber(unsignedInt: color.hexInt()))
        }
        subtitleSwitcherButton.hidden = subtitles.count == 0
        subtitleSwitcherButtonWidthConstraint.constant = subtitleSwitcherButton.hidden == true ? 0 : 24
        mediaplayer.delegate = self
        mediaplayer.drawable = movieView
        mediaplayer.media = VLCMedia(URL: url)
        if let nextMedia = nextMedia {
            upNextView.delegate = self
            upNextView.nextEpisodeInfoLabel.text = "Season \(nextMedia.season) Episode \(nextMedia.episode)"
            upNextView.nextEpisodeTitleLabel.text = nextMedia.title
            upNextView.nextShowTitleLabel.text = nextMedia.show!.title
            TVAPI.sharedInstance.getEpisodeInfo(nextMedia) { (imageURLAsString, subtitles) in
                self.nextMedia!.coverImageAsString = imageURLAsString
                self.upNextView.nextEpsiodeThumbImageView.af_setImageWithURL(NSURL(string: self.nextMedia!.coverImageAsString!)!)
                self.nextMedia!.subtitles = subtitles
            }
        }
        resetIdleTimer()
        view.addSubview(volumeView)
        for subview in volumeView.subviews {
            if let slider = subview as? UISlider {
                slider.addTarget(self, action: #selector(volumeChanged), forControlEvents: .ValueChanged)
            }
        }
        tapOnVideoRecognizer.requireGestureRecognizerToFail(doubleTapToZoomOnVideoRecognizer)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        observeValueForKeyPath("frame", ofObject: view, change: nil, context: nil) // Fixes autolayout bug with Volume view
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        view.removeObserver(self, forKeyPath: "frame")
        mediaplayer.pause()
        NSNotificationCenter.defaultCenter().removeObserver(self)
        if idleTimer != nil {
            idleTimer.invalidate()
            idleTimer = nil
        }
    }
    
    // MARK: - Player changes notifications
    
    func mediaPlayerStateChanged() {
        resetIdleTimer()
        let type: TraktTVAPI.type = media is PCTMovie ? .Movies : .Shows
        switch mediaplayer.state {
        case .Error:
            fallthrough
        case .Ended:
            fallthrough
        case .Stopped:
            TraktTVAPI.sharedInstance.scrobble(media.id, progress: positionSlider.value, type: type, status: .Finished)
            didFinishPlaying()
        case .Paused:
            playPauseButton.setImage(UIImage(named: "Play"), forState: .Normal)
            TraktTVAPI.sharedInstance.scrobble(media.id, progress: positionSlider.value, type: type, status: .Paused)
        case .Playing:
            playPauseButton.setImage(UIImage(named: "Pause"), forState: .Normal)
            TraktTVAPI.sharedInstance.scrobble(media.id, progress: positionSlider.value, type: type, status: .Watching)
        default:
            break
        }
    }
    
    func mediaPlayerTimeChanged() {
        if loadingView.hidden == false {
            positionSlider.hidden = false
            bufferProgressView!.hidden = false
            loadingView.hidden = true
            elapsedTimeLabel.hidden = false
            remainingTimeLabel.hidden = false
            videoDimensionsButton.hidden = false
        }
        positionSlider.value = mediaplayer.position
        remainingTimeLabel.text = mediaplayer.remainingTime.stringValue
        elapsedTimeLabel.text = mediaplayer.time.stringValue
        if nextMedia != nil && (mediaplayer.remainingTime.intValue/1000) == -30 {
            upNextView.show()
        } else if (mediaplayer.remainingTime.intValue/1000) < -30 && !upNextView.hidden {
            upNextView.hide()
        }
    }
    
    func orientationChanged() {
        resetIdleTimer()
        videoDimensionsButton.setImage(UIImage(named: "Scale To Fill"), forState: .Normal)
        mediaplayer.videoAspectRatio = nil
        mediaplayer.videoCropGeometry = nil
    }
    
    func volumeChanged() {
        if toolBarView.hidden {
            toggleControlsVisible()
            resetIdleTimer()
        }
        for subview in volumeView.subviews {
            if let slider = subview as? UISlider {
                volumeSlider.setValue(slider.value, animated: true)
            }
        }
    }
    
    // MARK: - View changes
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if object as? UIView == view && keyPath! == "frame" {
            volumeSlider.removeConstraints()
            if traitCollection.horizontalSizeClass == .Compact // Load compact volume view constraints
            {
                playPauseRegularBottomConstraint.active = false
                for constraint in compactConstraints {
                    constraint.active = true
                }
            } else if traitCollection.horizontalSizeClass == .Regular // Load regular constraints
            {
                playPauseRegularBottomConstraint.active = true
                for constraint in regularConstraints {
                    constraint.active = true
                }
            }
            volumeSlider.setNeedsUpdateConstraints()
            UIView.animateWithDuration(animationLength, animations: {
                self.volumeSlider.layoutIfNeeded()
            })
        }
    }
    
    @IBAction func toggleControlsVisible() {
        shouldHideStatusBar = navigationView.hidden
        UIView.animateWithDuration(0.25, animations: {
            if self.toolBarView.hidden {
                self.toolBarView.alpha = 1.0
                self.navigationView.alpha = 1.0
                self.toolBarView.hidden = false
                self.navigationView.hidden = false
            } else {
                self.toolBarView.alpha = 0.0
                self.navigationView.alpha = 0.0
            }
            self.setNeedsStatusBarAppearanceUpdate()
            }) { finished in
                if self.toolBarView.alpha == 0.0 {
                    self.toolBarView.hidden = true
                    self.navigationView.hidden = true
                }
        }
    }
    
    // MARK: - Navigation
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        fixIOS9PopOverAnchor(segue)
        segue.destinationViewController.popoverPresentationController?.delegate = self
        if segue.identifier == "showSubtitles" {
            let vc = (segue.destinationViewController as! UINavigationController).viewControllers.first! as! SubtitlesTableViewController
            vc.dataSourceArray = subtitles
            vc.selectedSubtitle = currentSubtitle
            vc.delegate = self
        } else if segue.identifier == "showDevices" {
            let vc = (segue.destinationViewController as! UINavigationController).viewControllers.first! as! StreamToDevicesTableViewController
            let duration: NSTimeInterval = mediaplayer.time.numberValue.doubleValue/1000.0 + fabs(mediaplayer.remainingTime.numberValue.doubleValue/1000.0)
            if let movie = media as? PCTMovie {
                vc.castMetadata = PCTCastMetaData(movie: movie, duration: duration, startPosition: mediaplayer.time.numberValue.doubleValue/1000.0, url: url.relativeString!, mediaAssetsPath: directory)
            } else if let episode = media as? PCTEpisode {
                vc.castMetadata = PCTCastMetaData(episode: episode, duration: duration, startPosition: mediaplayer.time.numberValue.doubleValue/1000.0, url: url.relativeString!, mediaAssetsPath: directory)
            }
        }
    }
    
    func presentationController(controller: UIPresentationController, viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle) -> UIViewController? {
        (controller.presentedViewController as! UINavigationController).topViewController?.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel", style: .Plain, target: self, action: #selector(dismiss))
        return controller.presentedViewController
        
    }
    
    func dismiss() {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    // MARK: - Timers
    
    func resetIdleTimer() {
        if idleTimer == nil {
            idleTimer = NSTimer.scheduledTimerWithTimeInterval(5, target: self, selector: #selector(idleTimerExceeded), userInfo: nil, repeats: false)
            if !mediaplayer.playing || loadingView.hidden == false // If paused or loading, cancel timer so UI doesn't disappear
            {
                idleTimer.invalidate()
                idleTimer = nil
            }
        } else {
            idleTimer.invalidate()
            idleTimer = nil
            resetIdleTimer()
        }
    }
    
    func idleTimerExceeded() {
        idleTimer = nil
        if !toolBarView.hidden {
            toggleControlsVisible()
        }
    }
    
    // MARK: - Status Bar
    
    override func prefersStatusBarHidden() -> Bool {
        return !shouldHideStatusBar
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .Default
    }
    
}
/**
 Protocol wrapper for private subtitle appearance API in MobileVLCKit. Can be toll free bridged from VLCMediaPlayer. Example for changing font:
 
        let mediaPlayer = VLCMediaPlayer()
        (mediaPlayer as VLCFontAppearance).setTextRendererFont!("HelveticaNueve")
 */
@objc protocol VLCFontAppearance {
    /**
     Change color of subtitle font.
     
     [All colors available here]: http://www.nameacolor.com/Color%20numbers.htm
     
     - Parameter fontColor: An `NSNumber` wrapped hexInt(`UInt32`) indicating the color. Eg. Black: 0, White: 16777215, etc.
     
     - SeeAlso: [All colors available here]
     */
    optional func setTextRendererFontColor(fontColor: NSNumber)
    /**
     Toggle bold on subtitle font.
     
     - Parameter fontForceBold: `NSNumber` wrapped `Bool`.
     */
    optional func setTextRendererFontForceBold(fontForceBold: NSNumber)
    /**
     Change the subtitle font.
     
     - Parameter fontname: `NSString` representation of font name. Eg `UIFonts` familyName property.
     */
    optional func setTextRendererFont(fontname: NSString)
    /**
     Change the subtitle font size.
     
     - Parameter fontname: `NSNumber` wrapped `Int` of the fonts size.
     
     - Important: Provide the font in reverse size as `libvlc` sets the text matrix to the identity matrix which reverses the font size. Ie. 5pt is really big and 100pt is really small.
     */
    optional func setTextRendererFontSize(fontSize: NSNumber)
}

extension VLCMediaPlayer: VLCFontAppearance {}

func downloadSubtitle(path: String, fileName suggestedName: String? = nil, downloadDirectory directory: NSURL, covertToVTT: Bool, completion: (subtitlePath: NSURL) -> Void) {
    var downloadDirectory: NSURL!
    var zippedFilePath: NSURL!
    var fileName: String!
    Alamofire.download(.GET, path, destination: { (temporaryURL, response) -> NSURL in
            fileName = suggestedName != nil ? suggestedName! : response.suggestedFilename!
            downloadDirectory = directory.URLByAppendingPathComponent("Subtitles")
            if !NSFileManager.defaultManager().fileExistsAtPath(downloadDirectory.relativePath!) {
                try! NSFileManager.defaultManager().createDirectoryAtURL(downloadDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            zippedFilePath = downloadDirectory.URLByAppendingPathComponent(fileName)
            return zippedFilePath
    }).validate().response { (_, _, _, error) in
        if let error = error where error.code != 516 // Error 516 throws if file already exists.
        {
            print(error)
            return
        }
        let filePath = downloadDirectory.relativePath! + "/" + fileName.stringByReplacingOccurrencesOfString(".gz", withString: "")
        NSFileManager.defaultManager().createFileAtPath(filePath, contents: NSFileManager.defaultManager().contentsAtPath(zippedFilePath.relativePath!)?.gunzippedData(), attributes: nil)
        covertToVTT ? completion(subtitlePath: SRT.sharedConverter().convertFileToVTT(NSURL(fileURLWithPath: filePath))) : completion(subtitlePath: NSURL(fileURLWithPath: filePath))
        
    }
}
