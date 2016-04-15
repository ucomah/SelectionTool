//
//  EMCollectionLayout.swift
//  FreeCropImageTool
//
//  Created by Evgeniy Melkov on 23.03.16.
//  Copyright © 2016 Evgeniy Melkov. All rights reserved.
//

import UIKit

class PALayout: UICollectionViewLayout {
    
    var itemOffset: UIOffset = UIOffsetMake(2.0, 2.0)
    var itemSize: CGSize = CGSizeMake(104, 108)
    var horizontalItemsSpacing: CGFloat = 2
    var verticalItemsSpacing: CGFloat = 2
    var isVertical = false
    
    private var addedItems = [AnyObject]()
    private var itemAttributes = [UICollectionViewLayoutAttributes]()
    private var itemsCount: Int {
        return (self.collectionView?.numberOfItemsInSection(0))! ?? 0
//        if  let cv = self.collectionView {
//            return cv.numberOfItemsInSection(0)
//        }
//        return 0
    }
    private var contentSize = CGSizeZero
    
    override init() {
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func prepareLayout() {
        if (isVertical) {
            self.placeItemsVertically()
        }
        else {
            self.placeItemsHorizontally()
        }
    }
    
    override func collectionViewContentSize() -> CGSize {
        return self.contentSize
    }
    
    override func layoutAttributesForItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        return itemAttributes[indexPath.row]
    }
    
    override func layoutAttributesForElementsInRect(rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var arr = [UICollectionViewLayoutAttributes]()
        for attr in itemAttributes {
            if CGRectIntersectsRect(rect, attr.frame) {
                arr.append(attr)
            }
        }
        return arr
    }
    
    override func shouldInvalidateLayoutForBoundsChange(newBounds: CGRect) -> Bool {
        return true
    }
    
    /**
     "Tile" aniamtion appearance.
     Commented baceuse I've got there's no need to show any pretty animations when mass items shown.
     It's enough just to do a smooth appearance provided by system.
     And the last thing - if it's still wanted a "Tiled" animation, it will cause an UI hang when there're many items.
     */
//    override func initialLayoutAttributesForAppearingItemAtIndexPath(itemIndexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
//        var attrs = super.initialLayoutAttributesForAppearingItemAtIndexPath(itemIndexPath)
//        if !addedItems.contains({ (obj: AnyObject) -> Bool in
//            let ip = obj as! NSIndexPath
//            return ip == itemIndexPath
//        }) {
//            attrs = itemAttributes[itemIndexPath.row] as? UICollectionViewLayoutAttributes
//            attrs!.transform3D = CATransform3DMakeScale(0.1, 0.1, 1.0)
//            addedItems.append(itemIndexPath)
//        }
//        return attrs
//    }
    
    func placeItemsVertically() {
        itemAttributes.removeAll()
        
        //"vertical scroll" display mode
        //int colCount = self.frame.size.width / elemWidth;
        let colCount = Int(self.collectionView!.frame.size.width / (itemSize.width + horizontalItemsSpacing))
        let rowCount =  (itemsCount / colCount) + Int(pow(Float(itemsCount % colCount), 1))
        
        self.contentSize = CGSizeMake(self.collectionView!.frame.size.width, (itemSize.height + verticalItemsSpacing) * CGFloat(rowCount) )
        
        var allItemsCount = itemsCount
        
        for i in 0..<rowCount {
            for j in 0..<colCount {

                let indx = (i * colCount) + j
                if (indx >= itemsCount) {
                    break
                }
                
                var xPos = CGFloat(j) * itemSize.width
                var yPos = CGFloat(i) * itemSize.height
                
                //container's borders indent
                xPos += horizontalItemsSpacing
                yPos += verticalItemsSpacing
                //spacing between items
                xPos += horizontalItemsSpacing * CGFloat(j)
                yPos += verticalItemsSpacing * CGFloat(i)
                
                let indexPath = NSIndexPath.init(forItem: indx, inSection: 0)
                
                let attributes = UICollectionViewLayoutAttributes.init(forCellWithIndexPath: indexPath)
                attributes.frame = CGRectMake(xPos, yPos, itemSize.width, itemSize.height)
                //CGRectIntegral(CGRectMake(xOffset, yOffset, itemSize.width, itemSize.height))
                itemAttributes.append(attributes)
                
                allItemsCount-=1
            }
        }
    }
    
    func placeItemsHorizontally() {
        itemAttributes.removeAll()
        
        if self.collectionView == nil {
            return
        }
        
        //elements count per Page
        let colCount = Int(self.collectionView!.frame.size.width / (itemSize.width + horizontalItemsSpacing))
        let rowCount = Int(self.collectionView!.frame.size.height / (itemSize.height + verticalItemsSpacing))
        
        let elemsOnPageCount = Int(colCount * rowCount)
        let pagesCount = itemsCount / elemsOnPageCount
        
        let expectedCount = pagesCount * elemsOnPageCount
        var lastElems = (elemsOnPageCount - (expectedCount - itemsCount))
        lastElems = self.collectionView!.pagingEnabled && lastElems > 0 ? colCount : lastElems
        let totalColls = ((pagesCount-1)  * colCount) + lastElems
        
        let width = (CGFloat(totalColls) * (itemSize.width + horizontalItemsSpacing) + horizontalItemsSpacing * CGFloat(totalColls))
        let height = self.collectionView!.frame.size.height
        self.contentSize = CGSizeMake(width,height);
        
        for i in 0..<pagesCount {
            let elementsOnCurrPageCount = (i+1) == Int(pagesCount) ? ( abs(itemsCount - (i * elemsOnPageCount)) ) :  elemsOnPageCount
            //NSLog("page %d has %d elements", i, elementsOnCurrPageCount)
            for j in 0..<elementsOnCurrPageCount {
                let indx = (i * elemsOnPageCount) + j
                if (indx >= itemsCount) {
                    break
                }
                
                //item position
                var xPos = (CGFloat(j % colCount) * itemSize.width) + (CGFloat(i) * self.collectionView!.frame.size.width)
                var yPos = CGFloat(j / colCount) * itemSize.height
                
                //container's borders indent
                xPos += horizontalItemsSpacing
                yPos += verticalItemsSpacing
                //spacing between items
                xPos += horizontalItemsSpacing * CGFloat(j % colCount)
                yPos += verticalItemsSpacing * CGFloat(j / colCount)
                
                let indexPath = NSIndexPath.init(forItem: indx, inSection: 0)
                let attributes = UICollectionViewLayoutAttributes.init(forCellWithIndexPath: indexPath)
                attributes.frame = CGRectMake(xPos, yPos, itemSize.width, itemSize.height);
                //CGRectIntegral(CGRectMake(xOffset, yOffset, itemSize.width, itemSize.height))
                itemAttributes.append(attributes)
            }
        }

    }
}
