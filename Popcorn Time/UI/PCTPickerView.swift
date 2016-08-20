

import UIKit

/**
 Listen for PCTPickerView delegate calls.
 */
@objc public protocol PCTPickerViewDelegate: class {
    /**
     Called when the pickerView has been closed.
     
     - Parameter pickerView:    The pickerView.
     - Parameter items:         The current selected item(s) in the pickerView. These may not have changed from the 
                                original selected items passed in.
     */
    optional func pickerView(pickerView: PCTPickerView, didClose items: [String: AnyObject])
    /**
     Called when the pickerView is about to be closed.
     
     - Parameter pickerView:    The pickerView.
     - Parameter items:         The current selected item(s) in the pickerView. These may not have changed from the 
                                original selected items passed in.
     */
    optional func pickerView(pickerView: PCTPickerView, willClose items: [String: AnyObject])
    /**
     Called when the pickerView has been closed and it's selected items have been changed.
     
     - Parameter pickerView:    The pickerView.
     - Parameter items:         The current selected item(s) in the pickerView.
     */
    optional func pickerView(pickerView: PCTPickerView, didChange items: [String: AnyObject])
}
/**
 A class based on UIPickerView that handles hiding and dismissing itself from the view its added to.
 */
public class PCTPickerView: UIView, UIPickerViewDataSource, UIPickerViewDelegate {
    
    @IBOutlet private var view: UIView!
    @IBOutlet public weak var pickerView: UIPickerView!
    @IBOutlet public weak var toolbar: UIToolbar!
    @IBOutlet public weak var cancelButton: UIBarButtonItem!
    @IBOutlet public weak var doneButton: UIBarButtonItem!
    @IBOutlet public weak var backgroundView: UIView!
    
    public weak var delegate: PCTPickerViewDelegate?
    private var visible: Bool {
        return !hidden
    }
    private var superView: UIView
    private var speed: Double = 0.2
    private let dimmingView: UIView
    public private (set) var numberOfComponents: Int = 0
    public private (set) var numberOfRowsInComponets = [Int]()
    public var selectedItems: [String]
    public var componentDataSources: [[String: AnyObject]] {
        didSet {
            numberOfComponents = componentDataSources.count
            numberOfRowsInComponets.removeAll()
            for array in componentDataSources {
                numberOfRowsInComponets.append(array.count)
            }
            pickerView?.reloadAllComponents()
        }
    }
    public var attributesForComponents: [String?]! {
        didSet {
            pickerView?.reloadAllComponents()
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        layoutView()
    }
    
    
    /**
     Designated Initialiser. Creates a UIPickerView with toolbar on top to handle dismissal of the view. Also handles hiding and showing animations.
     
     Parameter superview:                   View that the pickerView is a subview of.
     Parameter componentDataSources:        Data source dictionaries of the components in the picker.
     Parameter delegate:                    Register for `PCTPickerViewDelegate` notifications.
     Parameter selectedItems:               Data source keys that the pickerView will start on.
     Parameter attributesForComponenets:    Array of keys for NSAttributedString to customize component text style. Value
     for supplied key will be taken from the corresponding componentDataSource value.
     */
    public init(superView: UIView, componentDataSources: [[String: AnyObject]], delegate: PCTPickerViewDelegate?, selectedItems: [String], attributesForComponents: [String?]? = nil) {
        self.superView = superView
        self.componentDataSources = componentDataSources
        self.delegate = delegate
        self.selectedItems = selectedItems
        self.dimmingView = {
           let view = UIView(frame: superView.bounds)
            view.backgroundColor = UIColor.blackColor()
            return view
        }()
        super.init(frame: CGRectZero)
        self.attributesForComponents = attributesForComponents ?? [String?](count:numberOfComponents, repeatedValue: nil)
        loadNib()
        self.hidden = true
        let borderTop = CALayer()
        borderTop.frame = CGRectMake(0.0, toolbar.frame.height - 1, toolbar.frame.width, 0.5);
        borderTop.backgroundColor = UIColor(red:0.17, green:0.17, blue:0.17, alpha:1.0).CGColor
        toolbar.layer.addSublayer(borderTop)
        layoutView()
        insertSubview(dimmingView, belowSubview: view)
        dimmingView.alpha = 0
        dimmingView.hidden = true
        dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cancel)))
        view.frame.origin.y = self.superView.bounds.height
    }
    /**
     This method of initialisation is not supported.
     */
    @available(iOS, deprecated = 9.0, message="Use initWithSuperView:componentDataSources:delegate:selectedItems:attributesForComponents: instead.") required public init?(coder aDecoder: NSCoder) {
        fatalError("This method of initialisation is not supported. Use initWithSuperView:componentDataSources:delegate:selectedItems:attributesForComponents: instead.")
    }
    /**
     Show pickerView in superView with animation.
     */
    public func show() {
        for component in 0..<numberOfComponents {
            pickerView?.selectRow(Array(componentDataSources[component].keys.sort(>)).indexOf(selectedItems[component])!, inComponent: component, animated: false)
        }
        dimmingView.hidden = false
        view.setNeedsLayout()
        view.layoutIfNeeded()
        self.view.frame.origin.y = self.superView.bounds.height
        hidden = false
        UIView.animateWithDuration(speed, delay: 0, options: .CurveEaseInOut, animations: {
            self.dimmingView.alpha = 0.6
            self.view.frame.origin.y = self.superView.bounds.height - (self.superView.bounds.height / 2.7)
            }, completion: nil)
    }
    /**
     Hide pickerView in superView with animation.
     */
    public func hide() {
        if visible {
            var selected = [String: AnyObject]()
            for component in 0..<numberOfComponents {
                let key = Array(componentDataSources[component].keys.sort(>))[pickerView.selectedRowInComponent(component)]
                let value = componentDataSources[component][key]
                selected[key] = value
            }
            selectedItems = Array(selected.keys).reverse()
            self.delegate?.pickerView?(self, willClose: selected)
            UIView.animateWithDuration(speed, delay: 0, options: .CurveEaseInOut, animations: { [unowned self] in
                self.dimmingView.alpha = 0
                self.view.frame.origin.y = self.superView.bounds.height
                }, completion: { [unowned self] _ in
                    self.delegate?.pickerView?(self, didClose: selected)
                    self.dimmingView.hidden = true
                    self.hidden = true
            })
        }
    }
    /**
     Toggle hiding/showing of pickerView in superView with animation.
     */
    public func toggle() {
        visible ? hide() : show()
    }
    
    // MARK: - UIPickerViewDataSource
    
    public func pickerView(pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusingView view: UIView?) -> UIView {
        let key = Array(componentDataSources[component].keys).sort(>)[row]
        let value = componentDataSources[component][key]
        var attributes = [String: AnyObject]()
        if let attribute = attributesForComponents[component] {
            attributes[attribute] = value
        }
        let textLabel = view as? UILabel ?? {
            let label = UILabel()
            label.textColor = UIColor.whiteColor()
            label.textAlignment = .Center
            return label
            }()
        textLabel.text = key
        textLabel.attributedText = NSAttributedString(string: key, attributes: attributes)
        return textLabel
    }
    
    public func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return numberOfRowsInComponets[component]
    }
    
    public func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return numberOfComponents
    }
    
    // MARK: Private methods
    
    @objc private func layoutView() {
        frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: self.superView.bounds.height)
        dimmingView.frame = superView.bounds
        view.frame = CGRect(origin: CGPoint(x: 0, y: self.superView.bounds.height - (self.superView.bounds.height / 2.7)), size: CGSize(width: superView.bounds.width, height: self.superView.bounds.height / 2.7))
    }
    
    private func loadNib() {
        UINib(nibName: "PCTPickerView", bundle: nil).instantiateWithOwner(self, options: nil)[0] as? UIView
        addSubview(view)
    }
    
    @IBAction func done() {
        var selected = [String: AnyObject]()
        for component in 0..<numberOfComponents {
            let key = Array(componentDataSources[component].keys.sort(>))[pickerView.selectedRowInComponent(component)]
            let value = componentDataSources[component][key]
            selected[key] = value
        }
        if selectedItems != Array(selected.keys).reverse() {
            selectedItems = Array(selected.keys).reverse()
            delegate?.pickerView?(self, didChange: selected)
        } else {
            selectedItems = Array(selected.keys).reverse()
        }
        hide()
    }
    
    @IBAction func cancel() {
        hide()
    }
}
