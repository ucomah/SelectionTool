//
//  RootViewController.swift
//  FreeCropImageTool
//
//  Created by Evgeniy Melkov on 21.03.16.
//  Copyright © 2016 Evgeniy Melkov. All rights reserved.
//

import UIKit


class RootViewController: UIViewController {
    internal var titleItem: UINavigationItem?
    @IBOutlet weak var navBar: UINavigationBar?
    
    private var barConstraint: NSLayoutConstraint?
    
    override var title: String? {
        get {
            if let item = self.titleItem {
                return item.title
            }
            return self.navigationController?.navigationItem.title
        }
        set {
            if let item = self.titleItem {
                item.title = newValue
            }
            self.navigationController?.navigationItem.title = newValue
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if self.navBar != nil {
            titleItem = UINavigationItem.init()
        }
        
        //NavigationBar costumization
        navBar?.translucent = true
        
        let shadow: NSShadow = NSShadow()
        shadow.shadowColor = UIColor.init(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        shadow.shadowOffset = CGSizeMake(0, 0)
        
        let attrs = [
            NSForegroundColorAttributeName: UIColor.lightGrayColor(),
            NSShadowAttributeName: shadow,
            NSFontAttributeName: UIFont.boldSystemFontOfSize(18.0)
        ]
        navBar?.titleTextAttributes = attrs
        
        barConstraint = NSLayoutConstraint.init(item: navBar!,
                                                attribute: NSLayoutAttribute.Height,
                                                relatedBy: NSLayoutRelation.Equal,
                                                toItem: nil,
                                                attribute: NSLayoutAttribute.Height,
                                                multiplier: 1,
                                                constant: 64.0)
    }
    
    override func viewWillAppear(animated: Bool) {
        
        self.addConstrintIfNeeded()
        
        if (self.navBar != nil) {
            self.navBar?.items = [self.titleItem!]
        }
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    private func addConstrintIfNeeded() {
        //Fix navigationBar height
        if self.modalPresentationStyle != UIModalPresentationStyle.FormSheet {
            view.addConstraint(barConstraint!)
        }
    }
    
    override func didRotateFromInterfaceOrientation(fromInterfaceOrientation: UIInterfaceOrientation) {
        if UIDevice.currentDevice().userInterfaceIdiom == UIUserInterfaceIdiom.Phone &&
        UIDevice.currentDevice().orientation.isLandscape {
            self.view.removeConstraint(barConstraint!)
        }
        else {
            self.addConstrintIfNeeded()
        }
    }
}