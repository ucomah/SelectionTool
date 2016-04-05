//
//  ViewController.swift
//  FreeCropImageTool
//
//  Created by Evgeniy Melkov on 21.03.16.
//  Copyright © 2016 Evgeniy Melkov. All rights reserved.
//

import UIKit

//MARK: - ViewController

@objc protocol SelectionToolPopOverDelegate {
    optional func tablePopOver(popOver: UIViewController, didSelectItemAtIndex index: Int)
}

class ViewController: RootViewController, SelectionToolPopOverDelegate, UIDocumentPickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, SelectionTypeViewControllerDelegate, ROIScreenDelegate {

    @IBOutlet weak var helperLabel : UILabel?
    @IBOutlet weak var imageHolder: EMZoomImageView?
    
    private var btnAdd: UIBarButtonItem?
    private var btnCrop: UIBarButtonItem?
    private var btnDelete: UIBarButtonItem?
    private var inImageSource: ImageSourceViewController?
    
    var image: UIImage? {
        didSet {
            //Cache image in background
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
                if let img = self.image {
                    if let data = UIImageJPEGRepresentation(img, 1.0) {
                        data.writeToFile(self.tempImagePath, atomically: true)
                    }
                }
                else { //Remove cached image if some
                    do {
                        try NSFileManager.defaultManager().removeItemAtPath(self.tempImagePath)
                    }
                    catch {
                    }
                }
            }
            //Set image
            dispatch_async(dispatch_get_main_queue()) { () -> Void in
                self.imageHolder?.image = self.image
                self.toggleNavigationBarButtons()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("Selection Tool", comment: "Main screen title")
        helperLabel?.text = NSLocalizedString("Press '+' button to start", comment: "Main screen helper label text")
        
        self.imageHolder?.scrollView.showsVerticalScrollIndicator = true
        self.imageHolder?.scrollView.showsHorizontalScrollIndicator = true
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        //Navigation bar setup
        self.toggleNavigationBarButtons()
        
        //Load last used image
        if let data = NSData.init(contentsOfFile: self.tempImagePath) {
            let img = UIImage.init(data: data)
            self.image = img
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    //MARK: Actions

    internal func doAddItemAction() {
        if UIDevice.currentDevice().userInterfaceIdiom == UIUserInterfaceIdiom.Pad {
            if inImageSource == nil {
                inImageSource = ImageSourceViewController.init(style: UITableViewStyle.Plain)
                inImageSource!.delegate = self
                inImageSource!.modalPresentationStyle = UIModalPresentationStyle.Popover
                inImageSource!.preferredContentSize = CGSizeMake(220, 100)
            }
            presentViewController(inImageSource!, animated: true, completion: nil)
            let popoverPresentationController = inImageSource!.popoverPresentationController
            popoverPresentationController?.barButtonItem = btnAdd
        }
        else {
            let alert = UIAlertController.init(title: NSLocalizedString("Import image from:", comment: ""),
                                               message: "",
                                               preferredStyle: UIAlertControllerStyle.ActionSheet)
            alert.addAction(UIAlertAction.init(title: NSLocalizedString("iCloud Drive", comment: ""), style: UIAlertActionStyle.Default, handler: { (action: UIAlertAction) -> Void in
                self.do_iCloudImport()
            }))
            alert.addAction(UIAlertAction.init(title: NSLocalizedString("Camera Roll", comment: ""), style: UIAlertActionStyle.Default, handler: { (action: UIAlertAction) -> Void in
                self.do_ImagePickerImportWithSourceType(UIImagePickerControllerSourceType.PhotoLibrary)
            }))
            alert.addAction(UIAlertAction.init(title: NSLocalizedString("Cancel", comment: ""), style: UIAlertActionStyle.Destructive, handler: { (action: UIAlertAction) -> Void in
                alert.dismissViewControllerAnimated(true, completion: nil)
            }))
            self.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    private func do_iCloudImport() {
        let documentPicker = UIDocumentPickerViewController.init(documentTypes: ["public.image"], inMode: UIDocumentPickerMode.Import)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = UIModalPresentationStyle.FormSheet
        self.presentViewController(documentPicker, animated: true, completion: nil)
    }
    
    private func do_ImagePickerImportWithSourceType(sourceType: UIImagePickerControllerSourceType) {
        let picker = UIImagePickerController.init()
        picker.delegate = self
        picker.sourceType = sourceType
        picker.allowsEditing = false
        self.presentViewController(picker, animated: true, completion: nil)
    }
    
    internal func doDeleteImage() {
        self.image = nil
    }
    
    private var tempImagePath: String {
        var path = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true).last!
        path += "/last_used_image.jpeg"
        return path
    }
    
    //MARK: Setup
    
    func toggleNavigationBarButtons() {
        btnAdd = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonSystemItem.Add,
                                      target: self,
                                      action: #selector(ViewController.doAddItemAction))
        self.titleItem?.leftBarButtonItems = [btnAdd!]
        
        if self.imageHolder?.image != nil {
            btnCrop = UIBarButtonItem.init(title: NSLocalizedString("Crop", comment: "ToolBar Crop selection button title"),
                                           style: UIBarButtonItemStyle.Plain,
                                           target: self,
                                           action: #selector(ViewController.navigateToSelectCropScreen))
            btnDelete = UIBarButtonItem.init(barButtonSystemItem: .Trash, target: self, action: #selector(ViewController.doDeleteImage))
            
            self.titleItem?.leftBarButtonItems?.append(btnCrop!)
            self.titleItem?.rightBarButtonItems = [btnDelete!]
        }
        else {
            self.titleItem?.rightBarButtonItems = []
        }
    }
    
    //MARK: UIPopoverPresentationControllerDelegate
    
    func tablePopOver(popOver: UIViewController, didSelectItemAtIndex index: Int) {
        inImageSource?.dismissViewControllerAnimated(true, completion: { 
            switch index {
            case 0:
                self.do_iCloudImport()
            case 1:
                self.do_ImagePickerImportWithSourceType(UIImagePickerControllerSourceType.PhotoLibrary)
            default:
                break
            }
        })
    }
    
    //MARK: UIDocumentPickerDelegate
    
    func documentPicker(controller: UIDocumentPickerViewController, didPickDocumentAtURL url: NSURL) {
        NSLog("UIDocumentPicker picked doc with URL: %@", url);
        
        //Get image by URL
        let data = NSData.init(contentsOfURL: url)
        if data == nil {
            NSLog("Failed to import image from UIDocumentPickerViewController")
            return
        }
        let image = UIImage.init(data: data!)
        self.image = image
        controller.dismissViewControllerAnimated(true, completion:nil)
    }
    
    //MARK: UIImagePickerControllerDelegate
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingImage image: UIImage, editingInfo: [String : AnyObject]?) {
        self.image = image
        picker.dismissViewControllerAnimated(true, completion:nil)
    }
    
    //MARK: Navigation
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.destinationViewController is SelectionTypeViewController {
            let controller = segue.destinationViewController as! SelectionTypeViewController
            controller.delegate = self
        }
//        else if segue.destinationViewController is ROIScreen {
//            let controller = segue.destinationViewController as! ROIScreen
//            
//            controller.setImage((self.imageHolder?.image)!, animated: true)
//            controller.selectionType = EMSelectionType(rawValue: (sender?.integerValue)!)!
//        }
    }
    
    internal func navigateToSelectCropScreen() {
        self.performSegueWithIdentifier("showSelectCropTypeScreen", sender: self)
//        if let cropSelectScreen = self.storyboard?.instantiateViewControllerWithIdentifier("SelectionTypeViewController_identifier") {
//            self.presentViewController(cropSelectScreen, animated: true, completion: nil)
//        }
    }
    
    internal func navigateToROIScreenWithSelectionType(selectionType: EMSelectionType) {
//        self.performSegueWithIdentifier("showROIScreen", sender: selectionType.rawValue)
        
        if let controller = self.storyboard?.instantiateViewControllerWithIdentifier("ROIScreen_identifier") as? ROIScreen {
            controller.delegate = self
            self.imageHolder?.tag = selectionType.rawValue
            self.presentViewController(controller, animated: true, completion: {
            })
        }
    }
    
    //MARK: SelectionTypeViewControllerDelegate
    
    func selectionTypeViewController(controller: SelectionTypeViewController, didChoseSelectionType type: EMSelectionType) {
        controller.dismissViewControllerAnimated(true) { 
            self.navigateToROIScreenWithSelectionType(type)
        }
    }
    
    ////MARK: ROIScreenDelegate
    
    func selectionTypeForROIScreen(screen: ROIScreen) -> EMSelectionType {
        return EMSelectionType(rawValue: (self.imageHolder?.tag)!)!
    }
    
    func imageForROIScreen(screen: ROIScreen) -> UIImage {
        return self.image!
    }
    
    func roiScreen(screen: ROIScreen, didFinishSelectionWithImage resultImage: UIImage) {
        print(#function)
    }
}


