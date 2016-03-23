//
//  ViewController.swift
//  FreeCropImageTool
//
//  Created by Evgeniy Melkov on 21.03.16.
//  Copyright © 2016 Evgeniy Melkov. All rights reserved.
//

import UIKit


@objc protocol SelectionToolPopOverDelegate {
    optional func tablePopOver(popOver: UIViewController, didSelectItemAtIndex index: Int)
}

class ViewController: RootViewController, SelectionToolPopOverDelegate, UIDocumentPickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var helperLabel : UILabel?
    @IBOutlet weak var imageHolder: EMZoomImageView?
    
    private var btnAdd: UIBarButtonItem?
    private var btnCrop: UIBarButtonItem?
    private var btnDelete: UIBarButtonItem?
    private var inImageSource: ImageSourceViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("Selection Tool", comment: "Main screen title")
        helperLabel?.text = NSLocalizedString("Press '+' button to start", comment: "Main screen helper label text")
        
        //Navigation bar setup
        self.toggleNavigationBarButtons()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    //MARK: - Actions

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
            let alert = UIAlertController.init(title: NSLocalizedString("Import image from:", comment: ""), message: "", preferredStyle: UIAlertControllerStyle.ActionSheet)
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
    
    internal func doShowSelectCropScreen() {
        
    }
    
    internal func doDeleteImage() {
        self.setImage(nil)
    }
    
    //MARK: - Setup
    
    func setImage(image: UIImage?) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            self.imageHolder?.image = image
            self.toggleNavigationBarButtons()
        }
    }
    
    func toggleNavigationBarButtons() {
        btnAdd = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonSystemItem.Add, target: self, action: #selector(ViewController.doAddItemAction))
        self.titleItem?.leftBarButtonItems = [btnAdd!]
        
        if self.imageHolder?.image != nil {
            btnCrop = UIBarButtonItem.init(title: NSLocalizedString("Crop", comment: "ToolBar Crop selection button title"),
                                           style: UIBarButtonItemStyle.Plain,
                                           target: self,
                                           action: Selector(self.doShowSelectCropScreen()))
            btnDelete = UIBarButtonItem.init(barButtonSystemItem: .Trash, target: self, action: Selector(self.doDeleteImage()))
            
            self.titleItem?.leftBarButtonItems?.append(btnCrop!)
            self.titleItem?.rightBarButtonItems = [btnDelete!]
        }
        
    }
    
    //MARK: - UIPopoverPresentationControllerDelegate
    
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
    
    //MARK: - UIDocumentPickerDelegate
    
    func documentPicker(controller: UIDocumentPickerViewController, didPickDocumentAtURL url: NSURL) {
        NSLog("UIDocumentPicker picked doc with URL: %@", url);
        
        //Get image by URL
        let data = NSData.init(contentsOfURL: url)
        if data == nil {
            NSLog("Failed to import image from UIDocumentPickerViewController")
            return
        }
        let image = UIImage.init(data: data!)
        self.setImage(image)
        controller.dismissViewControllerAnimated(true, completion:nil)
    }
    
    //MARK: - UIImagePickerControllerDelegate
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingImage image: UIImage, editingInfo: [String : AnyObject]?) {
        self.setImage(image)
        picker.dismissViewControllerAnimated(true, completion:nil)
    }
}


//MARK: -


class SelectionTypeView: UIViewController {
    
}