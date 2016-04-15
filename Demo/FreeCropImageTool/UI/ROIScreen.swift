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
        
        self.view.backgroundColor = super.view.backgroundColor
        self.cropView?.backgroundColor = UIColor.clearColor()
        
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
        
        btnCancel = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonSystemItem.Cancel,
                                         target: self,
                                         action: #selector(doCancel))
        btnDeselect = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonSystemItem.Refresh,
                                           target: self,
                                           action: #selector(doDeselect))
        btnApply = UIBarButtonItem.init(title: NSLocalizedString("Apply", comment: "'Apply crop' bar button item title"),
                                        style: UIBarButtonItemStyle.Plain,
                                        target: self,
                                        action: #selector(doApply))
        btnUndo = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonSystemItem.Undo,
                                       target: self,
                                       action: #selector(doUndo))
        
        self.navigationItem.leftBarButtonItems = [btnCancel!, btnDeselect!]
        self.navigationItem.rightBarButtonItems = [btnApply!]
    }
    
    //MARK: - Actions
    
    func doCancel() {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func doDeselect() {
        self.cropView?.deselect()
    }
    
    func doUndo() {
        self.cropView?.undo()
    }
    
    func doApply() {
        if (self.cropView?.canDoCrop() == false || self.cropView?.cropPath.isZeroPath == true ) {
            delegate?.roiScreen(self, didFinishSelectionWithImage: (self.cropView?.image)!)
            return
        }
        HUD.show(HUDContentType.Progress)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
            let img = self.cropView?.croppedImageWithTrnsparentPixelsTrimmed(true)
            dispatch_async(dispatch_get_main_queue()) { () -> Void in
                HUD.hide(animated: true)
                self.delegate?.roiScreen(self, didFinishSelectionWithImage: img!)
            }
        }
    }
}
