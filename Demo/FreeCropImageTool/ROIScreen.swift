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
    
    var selectionType: EMSelectionType
    var delegate: ROIScreenDelegate?
    
    private
    var btnCancel: UIBarButtonItem?
    var btnApply: UIBarButtonItem?
    var btnDeselect: UIBarButtonItem?
    var btnUndo: UIBarButtonItem?
    var cropView: EMCropView?
    
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
        
        self.title = NSLocalizedString(selectionType.stringValue, comment: "")
    }
    
    //MARK: - Setup
    
    func setImage(image: UIImage, animated: Bool) {
        cropView?.image = image
    }
    
    func showCropViewWithSelectionType(selectionType: EMSelectionType, animated: Bool, completion: (Bool) -> Void) {
        
    }
    
    func hideCropViewAnimated(aniamted: Bool, completion: (Bool) -> Void) {
        
    }
    
    func toggleBarButtons() {
        
    }
}
