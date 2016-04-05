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
    func selectionTypeForROIScreen(screen: ROIScreen) -> EMSelectionType
    func roiScreen(screen: ROIScreen, didFinishSelectionWithImage resultImage: UIImage)
}

class ROIScreen: RootViewController {
    
    var delegate: ROIScreenDelegate?
    
    private
    var btnCancel: UIBarButtonItem?
    var btnApply: UIBarButtonItem?
    var btnDeselect: UIBarButtonItem?
    var btnUndo: UIBarButtonItem?
    var image: UIImage? {
        didSet {
            cropView?.image = self.image!
        }
    }
    @IBOutlet weak var cropView: EMCropView?
    
    //MARK: - LifeCycle
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.blackColor()
        self.cropView?.backgroundColor = UIColor.lightGrayColor()
        
        self.toggleBarButtons()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.title = NSLocalizedString(self.delegate?.selectionTypeForROIScreen(self).stringValue ?? "", comment: "")
        

        
        self.cropView?.alpha = 0.0
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        self.cropView?.image = (delegate?.imageForROIScreen(self))!
        self.cropView?.selectionType = (self.delegate?.selectionTypeForROIScreen(self)) ?? EMSelectionType.Rectangle
        self.cropView?.usePreDefinedSelectionFrame = false
        self.cropView?.layoutSubviews()
        self.cropView?.layoutInitialImage()
        
        UIView.animateWithDuration(0.5) { 
            self.cropView?.alpha = 1.0
        }
    }
    
    override func willRotateToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation, duration: NSTimeInterval) {
        self.cropView?.onOrientationWillChange()
    }
    
    override func didRotateFromInterfaceOrientation(fromInterfaceOrientation: UIInterfaceOrientation) {
        self.cropView?.onOrientationDidChange()
    }
    
    //MARK: - Setup
    
    func toggleBarButtons() {
        btnCancel = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonSystemItem.Cancel, target: self, action: #selector(doCancel))
        
        self.navigationItem.leftBarButtonItems = [btnCancel!]
    }
    
    //MARK: - Actions
    
    func doCancel() {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}
