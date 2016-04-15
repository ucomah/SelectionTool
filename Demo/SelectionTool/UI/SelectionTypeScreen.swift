//
//  SelectionTypeScreen.swift
//  FreeCropImageTool
//
//  Created by Evgeniy Melkov on 05.04.16.
//  Copyright © 2016 Evgeniy Melkov. All rights reserved.
//

import UIKit

//MARK: - SelectionTypeViewController

protocol SelectionTypeViewControllerDelegate {
    func selectionTypeViewController(controller: SelectionTypeViewController,  didChoseSelectionType type: EMSelectionType)
}

let cellReuseIdentifier = "SelectionTypeViewControllerCell_identifier"

@objc class SelectionTypeViewController: RootViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    
    @IBOutlet weak var collectionHolder: UICollectionView?
    var delegate: SelectionTypeViewControllerDelegate?
    var btnCancel: UIBarButtonItem?
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.commonInit()
    }
    
    private func commonInit() {
        btnCancel = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonSystemItem.Cancel,
                                         target: self,
                                         action: #selector(SelectionTypeViewController.goCancel(_:)))
        
        self.view.backgroundColor = super.view.backgroundColor
        self.collectionHolder?.backgroundColor = UIColor.clearColor()
        self.collectionHolder?.scrollEnabled = false
        
        //CollectionView setup
        let layout = PALayout.init()
        layout.isVertical = true
        if UIDevice.currentDevice().userInterfaceIdiom == UIUserInterfaceIdiom.Pad {
            layout.itemSize = CGSizeMake(128, 160)
            layout.horizontalItemsSpacing = 100
            layout.verticalItemsSpacing = 60
        }
        else {
            layout.itemSize = CGSizeMake(80, 116)
            layout.horizontalItemsSpacing = 55
            layout.verticalItemsSpacing = 90
        }
        
        collectionHolder?.frame = self.view.bounds
        
        collectionHolder?.alwaysBounceVertical = true
        collectionHolder?.collectionViewLayout = layout
        collectionHolder?.clipsToBounds = true
        collectionHolder?.dataSource = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("Choose a selection tool", comment:"Selection type choise title")
        self.titleItem?.leftBarButtonItem = btnCancel
    }
    
    //MARK: Actions
    
    func goCancel(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    //MARK: UICollectionView dataSource
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 4
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell: SelectionTypeViewControllerCell = collectionView.dequeueReusableCellWithReuseIdentifier(cellReuseIdentifier, forIndexPath: indexPath) as! SelectionTypeViewControllerCell
        
        let type: EMSelectionType = EMSelectionType(rawValue: indexPath.item)!
        switch type {
        case .Rectangle:
            cell.imageHolder?.image = UIImage.init(named: "Rectangle_black")
        case .Circle:
            cell.imageHolder?.image = UIImage.init(named: "Oval_black")
        case .Polygon:
            cell.imageHolder?.image = UIImage.init(named: "Polygon_black")
        case .Lasso:
            cell.imageHolder?.image = UIImage.init(named: "Lasso_black")
        }
        cell.titleLabel?.text = type.stringValue
        
        return cell
    }
    
    ////MARK: UICollectionViewDelegate
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        delegate?.selectionTypeViewController(self, didChoseSelectionType: EMSelectionType(rawValue: indexPath.row)!)
    }
}

//MARK: - SelectionTypeViewControllerCell

class SelectionTypeViewControllerCell: UICollectionViewCell {
    
    @IBOutlet weak var imageHolder: UIImageView?
    @IBOutlet weak var titleLabel: UILabel?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.imageHolder!.clipsToBounds = true
        self.imageHolder!.contentMode = UIViewContentMode.ScaleAspectFill
        self.titleLabel!.textColor = UIColor.darkTextColor()
    }
}
