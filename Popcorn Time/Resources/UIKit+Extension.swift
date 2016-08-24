

import UIKit
import OBSlider
import MediaPlayer


// MARK: - UIView

@IBDesignable class GradientView: UIView {
    
    @IBInspectable var topColor: UIColor? {
        didSet {
            configureView()
        }
    }
    @IBInspectable var bottomColor: UIColor? {
        didSet {
            configureView()
        }
    }
    
    override class func layerClass() -> AnyClass {
        return CAGradientLayer.self
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configureView()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }
    
    override func tintColorDidChange() {
        super.tintColorDidChange()
        configureView()
    }
    
    func configureView() {
        let layer = self.layer as! CAGradientLayer
        let locations = [ 0.0, 1.0 ]
        layer.locations = locations
        let color1: UIColor = topColor ?? self.tintColor
        let color2: UIColor = bottomColor ?? UIColor.blackColor()
        let colors = [ color1.CGColor, color2.CGColor ]
        layer.colors = colors
    }
    
}


@IBDesignable class CircularView: UIView {
    @IBInspectable var cornerRadius: CGFloat = 0 {
        didSet {
            layer.cornerRadius = cornerRadius
            layer.masksToBounds = cornerRadius > 0
        }
    }
    @IBInspectable var borderWidth: CGFloat = 0 {
        didSet {
            layer.borderWidth = borderWidth
        }
    }
    @IBInspectable var borderColor: UIColor? {
        didSet {
            layer.borderColor = borderColor?.CGColor
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

extension UIView {
    /**
     Remove all constraints from the view.
     */
    func removeConstraints() {
        if let superview = self.superview {
            for constraint in superview.constraints {
                if constraint.firstItem as? UIView == self || constraint.secondItem as? UIView == self {
                    constraint.active = false
                }
            }
        }
        for constraint in constraints {
            constraint.active = false
        }
    }
    
    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        while parentResponder != nil {
            parentResponder = parentResponder!.nextResponder()
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
        }
        return nil
    }
}

// MARK: - UIButton

@IBDesignable class PCTBorderButton: UIButton {
    @IBInspectable var cornerRadius: CGFloat = 0 {
        didSet {
            layer.cornerRadius = cornerRadius
            layer.masksToBounds = cornerRadius > 0
        }
    }
    @IBInspectable var borderWidth: CGFloat = 0 {
        didSet {
            layer.borderWidth = borderWidth
        }
    }
    @IBInspectable var borderColor: UIColor? {
        didSet {
            layer.borderColor = borderColor?.CGColor
            setTitleColor(borderColor, forState: .Normal)
        }
    }
    override var highlighted: Bool {
        didSet {
            updateColor(highlighted, borderColor)
        }
    }
    
    override func tintColorDidChange() {
        if tintAdjustmentMode == .Dimmed {
            updateColor(false)
        } else {
            updateColor(false, borderColor)
        }
    }
    
    func updateColor(highlighted: Bool, _ color: UIColor? = nil) {
        UIView.animateWithDuration(0.25) {
            if highlighted {
                self.backgroundColor =  color ?? self.tintColor
                self.layer.borderColor = color?.CGColor ?? self.tintColor?.CGColor
                self.setTitleColor(UIColor.whiteColor(), forState: .Highlighted)
            } else {
                self.backgroundColor = UIColor.clearColor()
                self.layer.borderColor = color?.CGColor ?? self.tintColor?.CGColor
                self.setTitleColor(color ?? self.tintColor, forState: .Normal)
            }
        }
    }
}

@IBDesignable class PCTBlurButton: UIButton {
    var cornerRadius: CGFloat = 0.0 {
        didSet {
            backgroundView.layer.cornerRadius = cornerRadius
            backgroundView.layer.masksToBounds = cornerRadius > 0
        }
    }
    @IBInspectable var blurTint: UIColor = UIColor.clearColor() {
        didSet {
            backgroundView.contentView.backgroundColor = blurTint
        }
    }
    var blurStyle: UIBlurEffectStyle = .Light {
        didSet {
            backgroundView.effect = UIBlurEffect(style: blurStyle)
        }
    }
    
    var imageTransform: CGAffineTransform = CGAffineTransformMakeScale(0.5, 0.5) {
        didSet {
            updatedImageView.transform = imageTransform
        }
    }
    
    var backgroundView: UIVisualEffectView
    private var updatedImageView = UIImageView()
    
    override init(frame: CGRect) {
        backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
        super.init(frame: frame)
        setUpButton()
    }
    
    required init?(coder aDecoder: NSCoder) {
        backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
        super.init(coder: aDecoder)
        setUpButton()
    }
    
    func setUpButton() {
        backgroundView.frame = bounds
        backgroundView.userInteractionEnabled = false
        insertSubview(backgroundView, atIndex: 0)
        updatedImageView = UIImageView(image: self.imageView!.image)
        updatedImageView.frame = self.imageView!.bounds
        updatedImageView.center = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds))
        updatedImageView.userInteractionEnabled = false
        self.imageView?.removeFromSuperview()
        addSubview(updatedImageView)
        updatedImageView.transform = imageTransform
        cornerRadius = frame.width/2
    }
    
    override var highlighted: Bool {
        didSet {
            updateColor(highlighted)
        }
    }
    
    func updateColor(tint: Bool) {
        UIView.animateWithDuration(0.25, delay: 0.0, options: .CurveEaseInOut, animations: { 
            self.backgroundView.contentView.backgroundColor = tint ? UIColor.whiteColor() : self.blurTint
            }, completion: nil)
    }
}

@IBDesignable class PCTHighlightedImageButton: UIButton {
    @IBInspectable var highlightedImageTintColor: UIColor = UIColor.whiteColor()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setImage(self.imageView?.image?.withColor(highlightedImageTintColor), forState: .Highlighted)
    }
    
    override func setImage(image: UIImage?, forState state: UIControlState) {
        super.setImage(image, forState: state)
        super.setImage(image?.withColor(highlightedImageTintColor), forState: .Highlighted)
    }
}



// MARK: - String

func randomString(length length: Int) -> String {
    let alphabet = "-_1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    let upperBound = UInt32(alphabet.characters.count)
    return String((0..<length).map { _ -> Character in
        return alphabet[alphabet.startIndex.advancedBy(Int(arc4random_uniform(upperBound)))]
        })
}

let downloadsDirectory: String = {
    let cachesPath = NSFileManager.defaultManager().URLsForDirectory(.CachesDirectory, inDomains: .UserDomainMask)[0]
    let downloadsDirectoryPath = cachesPath.URLByAppendingPathComponent("Downloads")
    if !NSFileManager.defaultManager().fileExistsAtPath(downloadsDirectoryPath.relativePath!) {
        try! NSFileManager.defaultManager().createDirectoryAtPath(downloadsDirectoryPath.relativePath!, withIntermediateDirectories: true, attributes: nil)
    }
    return downloadsDirectoryPath.relativePath!
}()

extension String {
    func urlStringValues() -> [String: String] {
        var queryStringDictionary = [String: String]()
        let urlComponents = componentsSeparatedByString("&")
        for keyValuePair in urlComponents {
            let pairComponents = keyValuePair.componentsSeparatedByString("=")
            let key = pairComponents.first?.stringByRemovingPercentEncoding
            let value = pairComponents.last?.stringByRemovingPercentEncoding
            queryStringDictionary[key!] = value!
        }
        return queryStringDictionary
    }
    
    func sliceFrom(start: String, to: String) -> String {
        return (rangeOfString(start)?.endIndex).flatMap { sInd in
            let eInd = rangeOfString(to, range: sInd..<endIndex)
            if eInd != nil {
                return (eInd?.startIndex).map { eInd in
                    return substringWithRange(sInd..<eInd)
                }
            }
            return substringWithRange(sInd..<endIndex)
        } ?? start
    }
    
    func contains(aString: String) -> Bool {
        return rangeOfString(aString, options: NSStringCompareOptions.CaseInsensitiveSearch) != nil
    }
    /// Produce a string of which all spaces are removed.
    var whiteSpacelessString: String {
        return stringByReplacingOccurrencesOfString(" ", withString: "")
    }
    /// Produce a string of which all spaces are removed and all letters capitalised except for the first.
    var camelCaseString: String {
        guard characters.count < 1 else {
            var camelString = capitalizedString.whiteSpacelessString
            camelString.replaceRange(startIndex..<startIndex.advancedBy(1), with: String(capitalizedString.characters.first!).lowercaseString)
            return camelString
        }
        return self
    }
}

// MARK: - Dictionary

extension Dictionary {
    
    func filter(predicate: Element -> Bool) -> Dictionary {
        var filteredDictionary = Dictionary()
        
        for (key, value) in self {
            if predicate(key, value) {
                filteredDictionary[key] = value
            }
        }
        
        return filteredDictionary
    }
    
}

extension Dictionary where Value : Equatable {
    func allKeysForValue(val : Value) -> [Key] {
        return self.filter { $1 == val }.map { $0.0 }
    }
}

func += <K, V> (inout left: [K:V], right: [K:V]) {
    for (k, v) in right {
        left.updateValue(v, forKey: k)
    }
}

// MARK: - NSLocale


extension NSLocale {
    
    static var langs: [String: String] {
        get {
            return [
                "af": "Afrikaans",
                "sq": "Albanian",
                "ar": "Arabic",
                "hy": "Armenian",
                "at": "Asturian",
                "az": "Azerbaijani",
                "eu": "Basque",
                "be": "Belarusian",
                "bn": "Bengali",
                "bs": "Bosnian",
                "br": "Breton",
                "bg": "Bulgarian",
                "my": "Burmese",
                "ca": "Catalan",
                "zh": "Chinese (simplified)",
                "zt": "Chinese (traditional)",
                "ze": "Chinese bilingual",
                "hr": "Croatian",
                "cs": "Czech",
                "da": "Danish",
                "nl": "Dutch",
                "en": "English",
                "eo": "Esperanto",
                "et": "Estonian",
                "ex": "Extremaduran",
                "fi": "Finnish",
                "fr": "French",
                "ka": "Georgian",
                "gl": "Galician",
                "de": "German",
                "el": "Greek",
                "he": "Hebrew",
                "hi": "Hindi",
                "hu": "Hungarian",
                "it": "Italian",
                "is": "Icelandic",
                "id": "Indonesian",
                "ja": "Japanese",
                "kk": "Kazakh",
                "km": "Khmer",
                "ko": "Korean",
                "lv": "Latvian",
                "lt": "Lithuanian",
                "lb": "Luxembourgish",
                "ml": "Malayalam",
                "ms": "Malay",
                "ma": "Manipuri",
                "mk": "Macedonian",
                "me": "Montenegrin",
                "mn": "Mongolian",
                "no": "Norwegian",
                "oc": "Occitan",
                "fa": "Persian",
                "pl": "Polish",
                "pt": "Portuguese",
                "pb": "Portuguese (BR)",
                "pm": "Portuguese (MZ)",
                "ru": "Russian",
                "ro": "Romanian",
                "sr": "Serbian",
                "si": "Sinhalese",
                "sk": "Slovak",
                "sl": "Slovenian",
                "es": "Spanish",
                "sw": "Swahili",
                "sv": "Swedish",
                "sy": "Syriac",
                "ta": "Tamil",
                "te": "Telugu",
                "tl": "Tagalog",
                "th": "Thai",
                "tr": "Turkish",
                "uk": "Ukrainian",
                "ur": "Urdu",
                "vi": "Vietnamese",
            ]
        }
    }
    
    static func commonISOLanguageCodes() -> [String] {
        return Array(langs.keys)
    }
    
    static func commonLanguages() -> [String] {
        return Array(langs.values)
    }
}

// MARK: - UITableViewCell

extension UITableViewCell {
    func relatedTableView() -> UITableView {
        guard let superview = self.superview as? UITableView ?? self.superview?.superview as? UITableView else {
            fatalError("UITableView shall always be found.")
        }
        return superview
    }
    
    // Fixes multiple color bugs in iPads because of interface builder
    public override var backgroundColor: UIColor? {
        get {
            return backgroundView?.backgroundColor
        }
        set {
            backgroundView?.backgroundColor = backgroundColor
        }
    }
}


// MARK: - UIStoryboardSegue

class DismissSegue: UIStoryboardSegue {
    override func perform() {
        sourceViewController.dismissViewControllerAnimated(true, completion: nil)
    }
}

// MARK: - UIImage

extension UIImage {

    func crop(rect: CGRect) -> UIImage {
        var rect = rect
        if self.scale > 1.0 {
            rect = CGRectMake(rect.origin.x * self.scale,
                              rect.origin.y * self.scale,
                              rect.size.width * self.scale,
                              rect.size.height * self.scale)
        }
        
        let imageRef = CGImageCreateWithImageInRect(self.CGImage, rect)
        return UIImage(CGImage: imageRef!, scale: self.scale, orientation: self.imageOrientation)
    }
    
    func withColor(color: UIColor?) -> UIImage {
        var color: UIColor! = color
        color = color ?? UIColor.appColor()
        UIGraphicsBeginImageContextWithOptions(self.size, false, UIScreen.mainScreen().scale)
        let context = UIGraphicsGetCurrentContext()
        color.setFill()
        CGContextTranslateCTM(context, 0, self.size.height)
        CGContextScaleCTM(context, 1.0, -1.0)
        CGContextSetBlendMode(context, CGBlendMode.ColorBurn)
        let rect = CGRectMake(0, 0, self.size.width, self.size.height)
        CGContextDrawImage(context, rect, self.CGImage)
        CGContextSetBlendMode(context, CGBlendMode.SourceIn)
        CGContextAddRect(context, rect)
        CGContextDrawPath(context, CGPathDrawingMode.Fill)
        let coloredImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return coloredImage
    }
    
    class func fromColor(color: UIColor?, inRect rect: CGRect = CGRectMake(0, 0, 1, 1)) -> UIImage {
        var color: UIColor! = color
        color = color ?? UIColor.appColor()
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        CGContextSetFillColorWithColor(context, color.CGColor)
        CGContextFillRect(context, rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

}

// MARK: - NSFileManager

extension NSFileManager {
    func fileSizeAtPath(path: String) -> Int64 {
        do {
            let fileAttributes = try attributesOfItemAtPath(path)
            let fileSizeNumber = fileAttributes[NSFileSize]
            let fileSize = fileSizeNumber?.longLongValue
            return fileSize!
        } catch {
            print("error reading filesize, NSFileManager extension fileSizeAtPath")
            return 0
        }
    }
    
    func folderSizeAtPath(path: String) -> Int64 {
        var size : Int64 = 0
        do {
            let files = try subpathsOfDirectoryAtPath(path)
            for i in 0 ..< files.count {
                size += fileSizeAtPath((path as NSString).stringByAppendingPathComponent(files[i]) as String)
            }
        } catch {
            print("Error reading directory.")
        }
        return size
    }
}

// MARK: - UISlider

class PCTBarSlider: OBSlider {
    
    override func trackRectForBounds(bounds: CGRect) -> CGRect {
        var customBounds = super.trackRectForBounds(bounds)
        customBounds.size.height = 3
        customBounds.origin.y -= 1
        return customBounds
    }
    
    override func awakeFromNib() {
        self.setThumbImage(UIImage(named: "Scrubber Image"), forState: .Normal)
        super.awakeFromNib()
    }
}

class PCTProgressSlider: UISlider {
    
    override func trackRectForBounds(bounds: CGRect) -> CGRect {
        var customBounds = super.trackRectForBounds(bounds)
        customBounds.size.height = 3
        customBounds.origin.y -= 1
        return customBounds
    }
    
    override func awakeFromNib() {
        setThumbImage(UIImage(named: "Progress Indicator")?.withColor(minimumTrackTintColor), forState: .Normal)
        setMinimumTrackImage(UIImage.fromColor(minimumTrackTintColor), forState: .Normal)
        setMaximumTrackImage(UIImage.fromColor(maximumTrackTintColor), forState: .Normal)
        super.awakeFromNib()
    }
    
    override func pointInside(point: CGPoint, withEvent event: UIEvent?) -> Bool {
        var bounds = self.bounds
        bounds = CGRectInset(bounds, 0, -5)
        return CGRectContainsPoint(bounds, point)
    }
    
    override func thumbRectForBounds(bounds: CGRect, trackRect rect: CGRect, value: Float) -> CGRect {
        var frame = super.thumbRectForBounds(bounds, trackRect: rect, value: value)
        frame.origin.y += rect.origin.y
        return frame
    }
    
}

// MARK: - Magnets

func makeMagnetLink(torrHash: String) -> String {
    let trackers = [
        "udp://tracker.opentrackr.org:1337/announce",
        "udp://glotorrents.pw:6969/announce",
        "udp://torrent.gresille.org:80/announce",
        "udp://tracker.openbittorrent.com:80",
        "udp://tracker.coppersurfer.tk:6969",
        "udp://tracker.leechers-paradise.org:6969",
        "udp://p4p.arenabg.ch:1337",
        "udp://tracker.internetwarriors.net:1337",
        "udp://open.demonii.com:80",
        "udp://tracker.coppersurfer.tk:80",
        "udp://tracker.leechers-paradise.org:6969",
        "udp://exodus.desync.com:6969"
    ]
    let magnetURL = "magnet:?xt=urn:btih:\(torrHash)&tr=" + trackers.joinWithSeparator("&tr=")
    return magnetURL
}

func cleanMagnet(url: String) -> String {
    var hash: String
    if !url.isEmpty {
        if url.containsString("&dn=") {
            hash = url.sliceFrom("magnet:?xt=urn:btih:", to: "&dn=")
        } else {
            hash = url.sliceFrom("magnet:?xt=urn:btih:", to: "")
        }
        return makeMagnetLink(hash)
    }
    return url
}

// MARK: - UITableView

extension UITableView {
    func sizeHeaderToFit() {
        if let header = tableHeaderView {
            header.setNeedsLayout()
            header.layoutIfNeeded()
            let height = header.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize).height
            var frame = header.frame
            frame.size.height = height
            header.frame = frame
            tableHeaderView = header
        }
    }
    
    var indexPathsForAllCells: [NSIndexPath] {
        var allIndexPaths = [NSIndexPath]()
        for section in 0..<numberOfSections {
            for row in 0..<numberOfRowsInSection(section) {
                allIndexPaths.append(NSIndexPath(forRow: row, inSection: section))
            }
        }
        return allIndexPaths
    }
}

// MARK: - CGSize

extension CGSize {
    static let max = CGSizeMake(CGFloat.max, CGFloat.max)
}

// MARK: - UIViewController

extension UIViewController {
    func fixIOS9PopOverAnchor(segue: UIStoryboardSegue?)
    {
        if let popOver = segue?.destinationViewController.popoverPresentationController,
            let anchor  = popOver.sourceView
            where popOver.sourceRect == CGRect()
                && segue!.sourceViewController === self
        { popOver.sourceRect = anchor.bounds }
    }
    func fixPopOverAnchor(controller: UIAlertController)
    {
        if let popOver = controller.popoverPresentationController,
            let anchor = popOver.sourceView
            where popOver.sourceRect == CGRect()
        { popOver.sourceRect = anchor.bounds }
    }
    
    func statusBarHeight() -> CGFloat {
        let statusBarSize = UIApplication.sharedApplication().statusBarFrame.size
        return Swift.min(statusBarSize.width, statusBarSize.height)
    }
    
    func dismissUntilAnimated<T: UIViewController>(animated: Bool, viewController: T.Type, completion: ((viewController: T) -> Void)?) {
        var vc = presentingViewController!
        while let new = vc.presentingViewController where !(new is T) {
            vc = new
        }
        vc.dismissViewControllerAnimated(animated, completion: {
            completion?(viewController: vc as! T)
        })
    }
}

extension UIScrollView {
    var isAtTop: Bool {
        return contentOffset.y <= verticalOffsetForTop
    }
    
    var isAtBottom: Bool {
        return contentOffset.y >= verticalOffsetForBottom
    }
    
    var verticalOffsetForTop: CGFloat {
        let topInset = contentInset.top
        return -topInset
    }
    
    var verticalOffsetForBottom: CGFloat {
        let scrollViewHeight = bounds.height
        let scrollContentSizeHeight = contentSize.height
        let bottomInset = contentInset.bottom
        let scrollViewBottomOffset = scrollContentSizeHeight + bottomInset - scrollViewHeight
        return scrollViewBottomOffset
    }
}

// MARK: - NSUserDefaults

extension NSUserDefaults {
    func reset() {
        for key in dictionaryRepresentation().keys {
            removeObjectForKey(key)
        }
    }
}

// MARK: - UIColor 

extension UIColor {
    class func appColor() -> UIColor {
        return UIColor(red:0.37, green:0.41, blue:0.91, alpha:1.0)
    }
    
    class func systemColors() -> [UIColor] {
        return [UIColor.blackColor(), UIColor.darkGrayColor(), UIColor.lightGrayColor(), UIColor.whiteColor(), UIColor.grayColor(), UIColor.redColor(), UIColor.greenColor(), UIColor.blueColor(), UIColor.cyanColor(), UIColor.yellowColor(), UIColor.magentaColor(), UIColor.orangeColor(), UIColor.purpleColor(), UIColor.brownColor()]
    }
    
    class func systemColorStrings() -> [String] {
       return ["Black", "Dark Gray", "Light Gray", "White", "Gray", "Red", "Green", "Blue", "Cyan", "Yellow", "Magenta", "Orange", "Purple", "Brown"]
    }
    
    func hexString() -> String {
        let colorSpace = CGColorSpaceGetModel(CGColorGetColorSpace(self.CGColor))
        let components = CGColorGetComponents(self.CGColor)
        
        var r, g, b: CGFloat!
        
        if (colorSpace == .Monochrome) {
            r = components[0]
            g = components[0]
            b = components[0]
        } else if (colorSpace == .RGB) {
            r = components[0]
            g = components[1]
            b = components[2]
        }
        
        return NSString(format: "#%02lX%02lX%02lX", lroundf(Float(r) * 255), lroundf(Float(g) * 255), lroundf(Float(b) * 255)) as String
    }
    
    func hexInt() -> UInt32 {
        let hex = hexString()
        var rgb: UInt32 = 0
        let s = NSScanner(string: hex)
        s.scanLocation = 1
        s.scanHexInt(&rgb)
        return rgb
    }
}

extension UIFont {
    
    func withTraits(traits:UIFontDescriptorSymbolicTraits...) -> UIFont {
        let descriptor = self.fontDescriptor()
            .fontDescriptorWithSymbolicTraits(UIFontDescriptorSymbolicTraits(traits))
        return UIFont(descriptor: descriptor, size: 0)
    }
    
    func boldItalic() -> UIFont {
        return withTraits(.TraitBold, .TraitItalic)
    }
    
    func bold() -> UIFont {
        return withTraits(.TraitBold)
    }
    
    func italic() -> UIFont {
        return withTraits(.TraitItalic)
    }
}

extension GCKMediaTextTrackStyle {
    
    class func pct_createDefault() -> Self {
        let ud = NSUserDefaults.standardUserDefaults()
        let windowType = GCKMediaTextTrackStyleWindowType.None
        let windowColor = GCKColor(UIColor: UIColor.clearColor())
        var fontFamily: String?
        var edgeColor: GCKColor?
        let edgeType: GCKMediaTextTrackStyleEdgeType
        let fontScale: CGFloat
        var foregroundColor: GCKColor?
        if let font = ud.stringForKey("PreferredSubtitleFont") {
            fontFamily = UIFont(name: font, size: 0)?.familyName
        }
        var fontStyle = GCKMediaTextTrackStyleFontStyle.Normal
        if let style = ud.stringForKey("PreferredSubtitleFontStyle") {
            switch style {
            case "Bold":
                fontStyle = .Bold
            case "Italic":
                fontStyle = .Italic
            case "Bold-Italic":
                fontStyle = .BoldItalic
            default:
                break
            }
        }
        if let color = ud.stringForKey("PreferredSubtitleOutlineColor")?.camelCaseString {
            edgeColor = GCKColor(UIColor: UIColor.performSelector(Selector(color + "Color")).takeRetainedValue() as! UIColor)
        }
        edgeType = edgeColor != nil ? .Outline : .DropShadow
        var scale: CGFloat = 25
        if let size = ud.stringForKey("PreferredSubtitleSize") {
            scale = CGFloat(Float(size.stringByReplacingOccurrencesOfString(" pt", withString: ""))!)
        }
        fontScale = scale
        var textColor = UIColor.whiteColor()
        if let color = ud.stringForKey("PreferredSubtitleColor")?.camelCaseString {
            textColor = UIColor.performSelector(Selector(color + "Color")).takeRetainedValue() as! UIColor
        }
        foregroundColor = GCKColor(UIColor: textColor)
        let swizzledSelf = self.init()
        swizzledSelf.windowType = windowType
        swizzledSelf.windowColor = windowColor
        swizzledSelf.fontFamily = fontFamily
        swizzledSelf.edgeColor = edgeColor
        swizzledSelf.edgeType = edgeType
        swizzledSelf.fontScale = fontScale
        swizzledSelf.foregroundColor = foregroundColor
        swizzledSelf.fontStyle = fontStyle
        return swizzledSelf
    }
    
    public override class func initialize() {
        struct Static {
            static var token: dispatch_once_t = 0
        }
        
        // make sure this isn't a subclass
        if self !== GCKMediaTextTrackStyle.self {
            return
        }
        
        dispatch_once(&Static.token) {
            let originalSelector = #selector(createDefault)
            let swizzledSelector = #selector(pct_createDefault)
            let originalMethod = class_getClassMethod(self, originalSelector)
            let swizzledMethod = class_getClassMethod(self, swizzledSelector)
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
}