//
//  ROIScreen.swift
//  FreeCropImageTool
//
//  Created by Evgeniy Melkov on 23.03.16.
//  Copyright © 2016 Evgeniy Melkov. All rights reserved.
//

import UIKit

protocol ROIScreenDelegate {
    func imageForROIScreen(screen: ROIScreen) -> UIImage
    func roiScreen(screen: ROIScreen, didFinishSelectionWithImage resultImage: UIImage)
}

class ROIScreen: RootViewController {
    
    var selectionType: EMSelectionType {
        didSet {
            self.cropView?.selectionType = selectionType
            self.title = NSLocalizedString(selectionType.stringValue, comment: "")
        }
    }
    var delegate: ROIScreenDelegate?
    
    private
    var btnCancel: UIBarButtonItem?
    var btnApply: UIBarButtonItem?
    var btnDeselect: UIBarButtonItem?
    var btnUndo: UIBarButtonItem?
    @IBOutlet weak var cropView: EMCropView?
    
    //MARK: - LifeCycle
    
    init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?, selectionType: EMSelectionType) {
        self.selectionType = selectionType
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.selectionType = EMSelectionType(rawValue: Int(aDecoder.decodeIntForKey("selectionType") ?? 0))!
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.blackColor()
        self.cropView?.backgroundColor = UIColor.lightGrayColor()
        
        btnCancel = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonSystemItem.Cancel, target: self, action: #selector(doCancel))
        
        self.navigationItem.leftBarButtonItems = [btnCancel!]
    }
    
    //MARK: - Setup
    
    func setImage(image: UIImage, animated: Bool) {
        cropView?.image = image
    }
    
    
    func toggleBarButtons() {
        
    }
    
    ////MARK: - Actions
    
    func doCancel() {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}
