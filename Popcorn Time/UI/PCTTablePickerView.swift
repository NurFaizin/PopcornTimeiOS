

import UIKit

@objc public protocol PCTTablePickerViewDelegate: class {
	optional func tablePickerView(tablePickerView: PCTTablePickerView, didSelect item: String)
	optional func tablePickerView(tablePickerView: PCTTablePickerView, didDeselect item: String)
	optional func tablePickerView(tablePickerView: PCTTablePickerView, didClose items: [String])
	optional func tablePickerView(tablePickerView: PCTTablePickerView, willClose items: [String])
}

public class PCTTablePickerView: UIView, UITableViewDataSource, UITableViewDelegate {
	
	@IBOutlet private var view: UIView!
	@IBOutlet public weak var tableView: UITableView!
	@IBOutlet public weak var toolbar: UIToolbar!
	@IBOutlet public weak var button: UIBarButtonItem!
	
	public weak var delegate: PCTTablePickerViewDelegate?
    private var visible: Bool {
        return !hidden
    }
    private let dimmingView: UIView
	private var superView: UIView
	private var dataSourceKeys = [String]()
	private var dataSourceValues = [String]()
    public var selectedItems = [String]() {
        didSet {
            tableView?.reloadData()
        }
    }
    private var cellBackgroundColor: UIColor = UIColor.clearColor() {
        didSet {
            tableView?.reloadData()
        }
    }
    private var cellBackgroundColorSelected: UIColor = UIColor(red: 217.0/255.0, green: 217.0/255.0, blue: 217.0/255.0, alpha: 1.0) {
        didSet {
            tableView?.reloadData()
        }
    }
    private var cellTextColor: UIColor = UIColor.lightGrayColor() {
        didSet {
            tableView?.reloadData()
        }
    }
	private var multipleSelect: Bool = false
	private var nullAllowed: Bool = true
	private var speed: Double = 0.2
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        layoutView()
    }
    
    /**
     Designated Initialiser. Creates a UITableView with toolbar on top to handle dismissal of the view. Also handles hiding and showing animations.
     
     Parameter superView:                   View that the pickerView is a subview of.
     Parameter sourceDict:                  Data source dictionary for the tableView. Values will be used as table view cell 
                                            text and keys are used to keep track of selected items.
     Parameter delegate:                    Register for `PCTTablePickerViewDelegate` notifications.
     */
    public init(superView: UIView, sourceDict: [String : String]?, _ delegate: PCTTablePickerViewDelegate?) {
        self.superView = superView
        self.dimmingView = {
            let view = UIView(frame: superView.bounds)
            view.backgroundColor = UIColor.blackColor()
            return view
        }()
		super.init(frame: CGRectZero)
		self.superView = superView
		if let sourceDict = sourceDict {
			self.setSourceDictionay(sourceDict)
		}
		self.delegate = delegate
        prepareView()
	}
    /**
     Designated Initialiser. Creates a UITableView with toolbar on top to handle dismissal of the view. Also handles hiding and showing animations.
     
     Parameter superView:                   View that the pickerView is a subview of.
     Parameter sourceArray:                 Data source array for the tableView.
     Parameter delegate:                    Register for `PCTTablePickerViewDelegate` notifications.
     */
	public init(superView: UIView, sourceArray: [String]?, _ delegate: PCTTablePickerViewDelegate?) {
        self.superView = superView
        self.dimmingView = {
            let view = UIView(frame: superView.bounds)
            view.backgroundColor = UIColor.blackColor()
            return view
        }()
		super.init(frame: CGRectZero)
		self.superView = superView
		if var sourceArray = sourceArray {
            sourceArray.sortInPlace({$0 < $1})
			self.setSourceArray(sourceArray)
		}
		self.delegate = delegate
		prepareView()
	}
    /**
     This method of initialisation is not supported.
     */
    @available(iOS, deprecated = 9.0, message="Use initWithSuperView:sourceArray:delegate: or initWithSuperView:sourceDict:delegate: instead.") required public init?(coder aDecoder: NSCoder) {
        fatalError("This method of initialisation is not supported. Use initWithSuperView:sourceArray:delegate: or initWithSuperView:sourceDict:delegate: instead.")
    }
    /**
     Set data source dictionary for the tableView.
     
     - Parameter source: The dictionary.
     */
	public func setSourceDictionay(source: [String : String]) {
		let sortedKeysAndValues = source.sort({ $0.1 < $1.1 })
		for (key, value) in sortedKeysAndValues {
			self.dataSourceKeys.append(key)
			self.dataSourceValues.append(value)
		}
		tableView?.reloadData()
	}
    /**
     Set data source array for the tableView.
     
     - Parameter source: The array.
     */
	public func setSourceArray(source: [String]) {
		self.dataSourceKeys = source
		self.dataSourceValues = source
		tableView?.reloadData()
	}
    /**
     Deselect the tableView row.
     
     - Parameter item: The title of the row that will be deselected. If the title is not in the tableView, nothing will be deselected.
     */
	public func deselect(item: String) {
		if let index = selectedItems.indexOf(item) {
			selectedItems.removeAtIndex(index)
			tableView?.reloadData()
			delegate?.tablePickerView?(self, didDeselect: item)
		}
	}
    /**
     Deselect every tableView apart from the passed in row.
     
     - Parameter item: The title of the row that will not be deselected. If the title is not in the tableView, nothing will be deselected. If mulitple selection is not enabled or if nothing is selected the passed in row will be selected.
     */
	public func deselectButThis(item: String) {
		for _item in selectedItems {
			if _item != item {
				delegate?.tablePickerView?(self, didDeselect: item)
			}
		}
		selectedItems = [item]
		tableView?.reloadData()
	}
    /**
     Show tablePickerView in superView with animation.
     */
	public func show() {
        if let selectedItem = selectedItems.first where dataSourceKeys.contains(selectedItem) {
            tableView.scrollToRowAtIndexPath(NSIndexPath(forRow: dataSourceKeys.indexOf(selectedItem)!, inSection: 0) , atScrollPosition: .Top, animated: true)
        } else {
            tableView.scrollToRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 0) , atScrollPosition: .Top, animated: false)
        }
        dimmingView.hidden = false
        view.frame.origin.y = superView.bounds.height
        hidden = false
        UIView.animateWithDuration(speed, delay: 0, options: .CurveEaseInOut, animations: {
            self.dimmingView.alpha = 0.6
            self.view.frame.origin.y = self.superView.bounds.height - (self.superView.bounds.height / 2.7)
            }, completion: nil)
	}
    /**
     Hide tablePickerView in superView with animation.
     */
	public func hide() {
		if visible {
            UIView.animateWithDuration(speed, delay: 0, options: .CurveEaseInOut, animations: { [unowned self] in
                self.dimmingView.alpha = 0
                self.view.frame.origin.y = self.superView.bounds.height
                self.delegate?.tablePickerView?(self, willClose: self.selectedItems)
                }, completion: { [unowned self] _ in
                    self.dimmingView.hidden = true
                    self.hidden = true
                    self.delegate?.tablePickerView?(self, didClose: self.selectedItems)
                })
		}
	}
    /**
     Toggle hiding/showing of tablePickerView in superView with animation.
     */
    public func toggle() {
        visible ? hide() : show()
    }
	
    // MARK: - UITableViewDataSource
	
	public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return 1
	}
	
	public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return dataSourceKeys.count
	}
	
	public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = UITableViewCell()
		cell.textLabel?.text = dataSourceValues[indexPath.row]
        cell.backgroundColor = cellBackgroundColor
        let bg = UIView()
        bg.backgroundColor = cellBackgroundColorSelected
        cell.selectedBackgroundView = bg
        cell.textLabel?.textColor = cellTextColor
        cell.tintColor = cellTextColor
        cell.accessoryType = selectedItems.contains(dataSourceKeys[indexPath.row]) ? .Checkmark : .None
		return cell
	}
	
	public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		let cell = tableView.cellForRowAtIndexPath(indexPath)!
		let selectedItem = dataSourceKeys[indexPath.row]
		if selectedItems.contains(selectedItem) && (nullAllowed || selectedItems.count > 1) {
			selectedItems.removeAtIndex(selectedItems.indexOf(selectedItem)!)
			delegate?.tablePickerView?(self, didDeselect: selectedItem)
			cell.accessoryType = .None
		} else {
			if !multipleSelect && selectedItems.count > 0 {
				let oldSelected = selectedItems[0]
				selectedItems.removeAll()
				if let index = dataSourceKeys.indexOf(oldSelected) {
					let oldCell = tableView.cellForRowAtIndexPath(NSIndexPath(forItem: index, inSection: 0))
					oldCell?.accessoryType = .None
				}
			}
			
			selectedItems.append(selectedItem)
			cell.accessoryType = .Checkmark
			delegate?.tablePickerView?(self, didSelect: selectedItem)
		}
		
		tableView.deselectRowAtIndexPath(indexPath, animated: true)
	}

	
	// MARK: Private methods
	
	private func prepareView() {
        loadNib()
        hidden = true
        let borderTop = CALayer()
        borderTop.frame = CGRectMake(0.0, toolbar.frame.height - 1, toolbar.frame.width, 0.5);
        borderTop.backgroundColor = UIColor(red:0.17, green:0.17, blue:0.17, alpha:1.0).CGColor
        toolbar.layer.addSublayer(borderTop)
        tableView.separatorColor = UIColor.darkGrayColor()
        tableView.backgroundColor = UIColor.clearColor()
        let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .Dark))
        tableView.backgroundView = blurEffectView
        tableView.tableFooterView = UIView(frame: CGRectZero)
        layoutView()
        insertSubview(dimmingView, belowSubview: view)
        dimmingView.alpha = 0
        dimmingView.hidden = true
        dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(done)))
        view.frame.origin.y = superView.bounds.height
	}
    
    private func layoutView() {
        frame = CGRect(x: 0, y: 0, width: superView.frame.width, height: superView.bounds.height)
        dimmingView.frame = superView.bounds
        view.frame = CGRect(origin: CGPoint(x: 0, y: superView.bounds.height - (superView.bounds.height / 2.7)), size: CGSize(width: superView.bounds.width, height: superView.bounds.height / 2.7))
    }
	
	private func loadNib() {
		UINib(nibName: "PCTTablePickerView", bundle: nil).instantiateWithOwner(self, options: nil)[0] as? UIView
		addSubview(view)
	}
	
	@IBAction func done(sender: AnyObject) {
		hide()
	}
}
