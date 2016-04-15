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

class ViewController: RootViewController, SelectionToolPopOverDelegate, UIDocumentPickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, SelectionTypeViewControllerDelegate, ROIScreenDelegate, UIDocumentInteractionControllerDelegate {

    @IBOutlet weak var helperLabel : UILabel?
    @IBOutlet weak var imageHolder: EMZoomImageView?
    
    @IBOutlet var btnAdd: UIBarButtonItem?
    @IBOutlet var btnCrop: UIBarButtonItem?
    @IBOutlet var btnDelete: UIBarButtonItem?
    @IBOutlet var btnShare: UIBarButtonItem?
    @IBOutlet var btnReload: UIBarButtonItem?
    var inImageSource: ImageSourceViewController?
    private var docInteracton: UIDocumentInteractionController?
    
    private(set) var image: UIImage? {
        didSet {
            self.imageHolder?.image = self.image
            self.helperLabel?.hidden = self.image != nil ? true : false
            self.toggleNavigationBarButtons()
        }
        
    }
    
    func setImage(image: UIImage?, useCache: Bool) {
        //Cache image in background
        if useCache {
            self.cacheImage(image, to: self.cacheImagePath, with: nil)
        }
        //Set image
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            if image == self.image {
                return
            }
            self.image = image
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("Selection Tool", comment: "Main screen title")
        helperLabel?.text = NSLocalizedString("Press '+' button to start", comment: "Main screen helper label text")
        
        self.imageHolder?.scrollView.showsVerticalScrollIndicator = true
        self.imageHolder?.scrollView.showsHorizontalScrollIndicator = true
        
        //Load last used image
        self.loadCachedImage(nil)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        //Navigation bar setup
        self.toggleNavigationBarButtons()
    }
    
    deinit {
        self.cleanupTempFiles()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    //MARK: Actions

    @IBAction internal func doAddItemAction(sender: AnyObject) {
        if UIDevice.currentDevice().userInterfaceIdiom == UIUserInterfaceIdiom.Pad {
            if inImageSource == nil {
                inImageSource = ImageSourceViewController.init(style: UITableViewStyle.Plain)
                inImageSource!.delegate = self
                inImageSource!.modalPresentationStyle = UIModalPresentationStyle.Popover
                if (UIImagePickerController.availableMediaTypesForSourceType(UIImagePickerControllerSourceType.Camera) != nil) {
                    inImageSource!.preferredContentSize = CGSizeMake(220, 150)
                }
                else {
                    inImageSource!.preferredContentSize = CGSizeMake(220, 100)
                }
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
            if (UIImagePickerController.availableMediaTypesForSourceType(UIImagePickerControllerSourceType.Camera) != nil) {
                alert.addAction(UIAlertAction.init(title: NSLocalizedString("Take a Photo", comment: ""), style: UIAlertActionStyle.Default, handler: { (action: UIAlertAction) -> Void in
                    self.do_ImagePickerImportWithSourceType(UIImagePickerControllerSourceType.Camera)
                }))
            }
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
    
    private func do_iCloudExport() {
        self.prepareForSharingWithCompeltion { (ready) in
            //Perform export
            let documentPicker = UIDocumentPickerViewController.init(URL: self.tempFileURL, inMode: UIDocumentPickerMode.ExportToService)
            documentPicker.modalPresentationStyle = UIModalPresentationStyle.FormSheet
            self.presentViewController(documentPicker, animated: true, completion: nil)
        }
    }
    
    @IBAction internal func doShareImage(sender: AnyObject) {
        
        docInteracton = UIDocumentInteractionController.init(URL: self.tempFileURL)
        docInteracton!.delegate = self
        if UIDevice.currentDevice().userInterfaceIdiom == UIUserInterfaceIdiom.Pad {
            docInteracton?.presentOptionsMenuFromBarButtonItem(self.btnShare!, animated: true)
        }
        else {
            docInteracton?.presentOptionsMenuFromRect(self.view.frame, inView: self.view, animated: true)
        }
        
    }
    
    @IBAction internal func doDeleteImage(sender: AnyObject) {
        self.setImage(nil, useCache: true)
    }
    
    @IBAction internal func doReloadImage(sender: AnyObject) {
        self.loadCachedImage { (finished) in
            
        }
    }
    
    //MARK: - UIDocumentInteractionControllerDelegate
    
    func documentInteractionControllerRectForPreview(controller: UIDocumentInteractionController) -> CGRect {
        return self.view.frame
    }
    
    func documentInteractionControllerViewForPreview(controller: UIDocumentInteractionController) -> UIView? {
        return self.view
    }
    
    func documentInteractionControllerDidDismissOptionsMenu(controller: UIDocumentInteractionController) {
        self.cleanupTempFiles()
    }
    
    func documentInteractionControllerDidDismissOpenInMenu(controller: UIDocumentInteractionController) {
        self.cleanupTempFiles()
    }
    
    //MARK: - Cache
    
    private func prepareForSharingWithCompeltion(completion: ((ready: Bool) -> Void)) {
        //Store current image to temporary URL if needed
        self.cacheImage(self.image, to: self.tempFileURL.path!) { (success) in
            if !success {
                UIAlertView.init(title: NSLocalizedString("Error", comment: ""),
                                 message: NSLocalizedString("Failed to cache a file for exporting!", comment: ""),
                                 delegate: nil,
                                 cancelButtonTitle: "Ok").show()
            }
            completion(ready: success)
        }
    }
    
    private var cacheImagePath: String {
        var path = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true).last!
        path += "/last_used_image.png"
        return path
    }
    
    private var tempFileURL: NSURL {
        var path = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true).last!
        path += "/temp.png"
        let url = NSURL.init(fileURLWithPath: path)
        return url
    }
    
    private func loadCachedImage(completion: ((finished: Bool) -> Void)?) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
            if let data = NSData.init(contentsOfFile: self.cacheImagePath) {
                let img = UIImage.init(data: data)
                if (img?.isEqual(self.image))! == false {
                    self.setImage(img, useCache: true)
                }
            }
        }
    }
    
    func cleanupTempFiles() {
        do {
            try NSFileManager.defaultManager().removeItemAtURL(self.tempFileURL)
        }
        catch {
            
        }
    }
    
    /**
     Cache image in background.
     If @param image is nil, current cache will be cleaned
     */
    private func cacheImage(image: UIImage?, to path: String, with completion: ((success: Bool) -> Void)?) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
            var success = false
            var isDirectory: ObjCBool = ObjCBool(true)
            if NSFileManager.defaultManager().fileExistsAtPath(path, isDirectory: &isDirectory) {
                if let img = image {
                    if let data = UIImagePNGRepresentation(img) {
                        success = data.writeToFile(path, atomically: true)
                    }
                }
                else { //Remove cached image if some
                    do {
                        try NSFileManager.defaultManager().removeItemAtPath(path)
                        success = true
                    }
                    catch {
                        success = false
                    }
                }
            }
            if let handler = completion {
                dispatch_async(dispatch_get_main_queue()) { () -> Void in
                    handler(success: success)
                }
            }
        }
    }
    
    //MARK: Setup
    
    func toggleNavigationBarButtons() {
        btnAdd = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonSystemItem.Add,
                                      target: self,
                                      action: #selector(doAddItemAction(_:)))
        self.navigationItem.leftBarButtonItems = [btnAdd!]
        
        if self.imageHolder?.image != nil {
            btnCrop = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonSystemItem.Edit,
                                           target: self,
                                           action: #selector(ViewController.navigateToSelectCropScreen(_:)))
            btnShare = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonSystemItem.Action, target: self, action: #selector(doShareImage(_:)))
            btnDelete = UIBarButtonItem.init(barButtonSystemItem: .Trash, target: self, action: #selector(ViewController.doDeleteImage(_:)))
            btnReload = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonSystemItem.Refresh, target: self, action: #selector(doReloadImage(_:)))
            
            self.titleItem?.leftBarButtonItems?.append(btnCrop!)
            self.titleItem?.leftBarButtonItems?.append(btnReload!)
            self.titleItem?.rightBarButtonItems = [btnDelete!, btnShare!]
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
            case 2:
                self.do_ImagePickerImportWithSourceType(UIImagePickerControllerSourceType.Camera)
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
        self.setImage(image, useCache: true)
        controller.dismissViewControllerAnimated(true, completion:nil)
    }
    
    //MARK: UIImagePickerControllerDelegate
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingImage image: UIImage, editingInfo: [String : AnyObject]?) {
        self.setImage(image, useCache: true)
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
    
    @IBAction internal func navigateToSelectCropScreen(sender: AnyObject) {
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
        self.setImage(resultImage, useCache: false)
        screen.dismissViewControllerAnimated(true, completion: nil)
    }
}


