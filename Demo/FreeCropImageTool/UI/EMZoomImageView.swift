//
//  ZoomImageView.swift
//  FreeCropImageTool
//
//  Created by Evgeniy Melkov on 21.03.16.
//  Copyright © 2016 Evgeniy Melkov. All rights reserved.
//

import UIKit

class EMZoomImageView: UIView, UIScrollViewDelegate {

    ///Default is 0.5
    var imageAppearanceDuration: CGFloat = 0.5
    var image: UIImage? {
        get {
            return imageView.image
        }
        set {
            self.setImage(newValue, animated: true)
        }
    }
    
    func setImage(image: UIImage?, animated: Bool) {
        if (animated) {
            self.imageView.alpha = 0
        }
        self.imageView.image = image
        self.updateZoom()
        
        if (animated) {
            // Assign image with animation
            UIView.transitionWithView(self.imageView, 
                                      duration: NSTimeInterval(self.imageAppearanceDuration),
                                      options: [UIViewAnimationOptions.TransitionCrossDissolve, UIViewAnimationOptions.CurveLinear],
                                      animations: {
                                        self.imageView.alpha = 1
                }, completion: { (finished: Bool) in
            })
        }
    }
    
    private(set) var imageView: UIImageView = UIImageView.init()
    private(set) var scrollView: UIScrollView = UIScrollView.init()
    private var lastZoomScale: CGFloat = 0.0
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.commonInit()
    }
    
    private func commonInit() {
        self.multipleTouchEnabled = true
        self.userInteractionEnabled = true
        
        //Subviews
        self.scrollView.frame = self.bounds
        self.scrollView.delegate = self
        self.scrollView.maximumZoomScale = 20
        self.scrollView.contentMode = UIViewContentMode.ScaleToFill
        self.scrollView.autoresizingMask = [UIViewAutoresizing.FlexibleHeight, UIViewAutoresizing.FlexibleWidth]
        
        self.imageView.frame = CGRectMake(0, 0, CGRectGetWidth(scrollView.frame), CGRectGetHeight(scrollView.frame))
        self.imageView.contentMode = UIViewContentMode.Center
        self.imageView.clipsToBounds = false
        self.imageView.autoresizingMask = [UIViewAutoresizing.FlexibleHeight, UIViewAutoresizing.FlexibleWidth, UIViewAutoresizing.FlexibleBottomMargin, UIViewAutoresizing.FlexibleTopMargin, UIViewAutoresizing.FlexibleLeftMargin, UIViewAutoresizing.FlexibleRightMargin]
        
        self.addSubview(scrollView)
        scrollView.addSubview(imageView)
        
        //Gestures
        let doubleTap = UITapGestureRecognizer.init(target: self, action: #selector(EMZoomImageView.doDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        self.scrollView.addGestureRecognizer(doubleTap)
        
        let singleTap = UITapGestureRecognizer.init(target: self, action: #selector(EMZoomImageView.doSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        singleTap.numberOfTouchesRequired = 1
        self.scrollView.addGestureRecognizer(singleTap)
        singleTap.requireGestureRecognizerToFail(doubleTap)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.updateZoom()
    }
    
    //MARK: - Helpers
    
    //! Zoom shows as bigger image part as possible unless image is smaller than screen
    func updateZoom() {
        if self.image == nil {
            return
        }
        var minZoom: CGFloat = min(self.bounds.size.width / (self.imageView.image!.size.width),
                                   self.bounds.size.height / self.imageView.image!.size.height)
        
        if (minZoom > 1) {
            minZoom = 1
        }
        self.scrollView.minimumZoomScale = minZoom
        
        // Force scrollViewDidZoom fire if zoom did not change
        if (minZoom == self.lastZoomScale) {
            minZoom += 0.000001
        }
        self.lastZoomScale = minZoom
        self.scrollView.zoomScale = minZoom
    }
    
    private func zoomRectForScale(scale: CGFloat, withCenter center: CGPoint) -> CGRect {
        let aCenter = self.imageView.convertPoint(center, fromView: self)
        
        let w = self.imageView.frame.size.width / scale
        let h = self.imageView.frame.size.height / scale
        let x = aCenter.x - w / 2
        let y = aCenter.y - h / 2
        
        return CGRectMake(x,y,w,h)
    }
    
    private func centerSubview(subView: UIView) {
        let offsetX = max((self.scrollView.bounds.size.width - self.scrollView.contentSize.width) * 0.5, 0.0)
        let offsetY = max((self.scrollView.bounds.size.height - self.scrollView.contentSize.height) * 0.5, 0.0)
        
        subView.center = CGPointMake(self.scrollView.contentSize.width * 0.5 + offsetX,
                                     self.scrollView.contentSize.height * 0.5 + offsetY)
    }
    
    //MARK: - UIScrollViewDelegate
    
    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return self.imageView
    }
    
    func scrollViewDidZoom(scrollView: UIScrollView) {
        //Center zoomed image
        let subView = scrollView.subviews[0]
        self.centerSubview(subView)
        
//        for subview in self.scrollView.subviews {
//            self.centerSubview(subView)
//        }
    }
    
    //MARK: - Touch handlers
    
    internal func doDoubleTap(sender: UITapGestureRecognizer) {
        // Zoom in / Zoom out to tap point
        let newScale = self.scrollView.zoomScale * 4.0
        if (self.scrollView.zoomScale > self.scrollView.minimumZoomScale) {
            self.scrollView.setZoomScale(self.scrollView.minimumZoomScale, animated: true)
        } else {
            let zoomRect = self.zoomRectForScale(newScale, withCenter: sender.locationInView(sender.view))
            self.scrollView.zoomToRect(zoomRect, animated: true)
        }
    }
    
    internal func doSingleTap(sender: UITapGestureRecognizer) {
        
    }
}
