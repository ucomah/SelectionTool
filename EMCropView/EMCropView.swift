//
//  EMCropView.swift
//
//  Created by Evgeniy Melkov on 02.03.16.
//  Copyright © 2016 CoLocalization Research Software. All rights reserved.
//

import Foundation
import UIKit

private let kEMCropViewMinimumBoxSize: CGFloat = 42.0
private let kEMCropViewPadding: CGFloat = 14.0
private let kEMInitialImageAnimationDuration = 0.2

/** When the user taps down to resize the box, this state is used
 to determine where they tapped and how to manipulate the box */
@objc enum EMCropViewOverlayEdge: Int {
    case None = 0,
    TopLeft, Top, TopRight, Right, BottomRight, Bottom, BottomLeft, Left, Center
}


@objc protocol EMCropViewDeleagte {
    optional func cropViewIsReadyToHandleGestures(cropView: EMCropView)
    optional func cropViewDidPauseFreeSelection(cropView: EMCropView)
    optional func cropViewDidResumeFreeSelection(cropView: EMCropView)
    optional func cropViewDidCompleteFreeSelection(cropView: EMCropView)
    optional func cropViewDidFailSelectionWithReason(cropView: EMCropView, reason: EMSelectionFailureReason)
    optional func cropViewDidChangeUndoStatus(cropView: EMCropView, canUndo: Bool)
    #if DEBUG
    //WARNING: Optional implementation causes clang segmentation fault
    #endif
    func cropView(cropView: EMCropView, didChangeCropBoxFrame cropBoxFrame: CGRect)
}



@objc class EMCropView: UIView, UIGestureRecognizerDelegate, EMSelectionShapeViewDelegate {
    
    //MARK: - Public variables
    
    /// The image that the crop view is displaying. This cannot be changed once the crop view is instantiated.
    var image: UIImage {
        get {
            return imageView.image ?? UIImage.init()
        }
        set {
            self.imageView.frame = contentBounds
            self.imageView.contentMode = .ScaleAspectFit
            self.imageView.image = newValue
            self.layoutSubviews()
            self.layoutInitialImage()
        }
    }
    /// A grid view overlaid on top of the foreground image view's container.
    let overlayView = EMCropOverlayView()
    /// When the cropping box is locked to its current size
    private(set) var aspectLockEnabled = false
    /// Inset the workable region of the crop view in case in order to make space for accessory views
    private(set) var cropRegionInsets = UIEdgeInsetsZero
    /// Indicates if CropBoxView should be resized when facing superview borders. Default is 'true'
    private(set) var resizeCropBoxOnDrag = true
    /** Indicates if app should let user to draw a selection frame box form scratch or use predefined one.
        Applicable only for Rectangle and Oval selection modes.
    */
    var usePreDefinedSelectionFrame: Bool = false {
        didSet {
            self.deselect()
        }
    }
    
    weak var delegate: EMCropViewDeleagte?
    
    var cropBoxColor: UIColor? {
        get {
            return self.overlayView.cropBoxColor
        }
        set {
            if let val = newValue {
                self.overlayView.cropBoxColor = val
            }
        }
    }
    var resizingPointInnerColor: UIColor? {
        get {
            return self.overlayView.resizingPointOuterColor
        }
        set {
            if let val = newValue {
                self.overlayView.resizingPointOuterColor = val
            }
        }
    }
    var resizingPointOuterColor: UIColor? {
        get {
            return self.overlayView.resizingPointOuterColor
        }
        set {
            if let val = newValue {
                self.overlayView.resizingPointOuterColor = val
            }
        }
    }
    
    //MARK: - Private variables
    
    private
    /// The gesture recognizer in charge of controlling the resizing of the crop view.
    let gridPanGestureRecognizer = UIPanGestureRecognizer()
    /// Handles selection bezier path cleaning
    var doubleTapHandler: UITapGestureRecognizer?
    /// The edge region that the user tapped on, to resize the cropping region.
    var tappedEdge =  EMCropViewOverlayEdge.None
    /// When resizing, this is the original frame of the crop box.
    var cropOriginFrame: CGRect?
    /// The initial touch point of the pan gesture recognizer
    var panOriginPoint: CGPoint?
    
    let imageView = UIImageView()

    /// Used to support 'resizeCropBoxOnDrag'
    var prevPoint = CGPointZero
    /// Base point for drawing a selection frame from scratch
    var initialCropRect =  CGRectZero
    private(set) var isInitialRectDrawing = false
    ///Keeps all cropOriginValues for Undo oprations
    let cropOriginsStack = NSMutableArray()
    
    
    //MARK: - Accessors
    
    /// The frame of the cropping box on the crop view
    var cropBoxFrame = CGRectZero {
        didSet {
            if (CGRectEqualToRect(cropBoxFrame, oldValue)) {
                return
            }

            //Upon init, sometimes the box size is still 0, which can result in CALayer issues
            if (cropBoxFrame.size.width < CGFloat(FLT_EPSILON) || cropBoxFrame.size.height < CGFloat(FLT_EPSILON)) {
                return
            }
            
            //clamp the cropping region to the inset boundaries of the screen
            let contentFrame: CGRect = contentBounds
            
            let xOrigin = ceil(contentFrame.origin.x)
            let xDelta = cropBoxFrame.origin.x - xOrigin
            cropBoxFrame.origin.x = floor(max(cropBoxFrame.origin.x, xOrigin))
            //If we clamp the x value, ensure we compensate for the subsequent delta generated in the width (Or else, the box will keep growing)
            if (Float(xDelta) < -FLT_EPSILON) {
                cropBoxFrame.size.width += CGFloat(xDelta)
            }
            
            let yOrigin = ceil(contentFrame.origin.y)
            let yDelta = cropBoxFrame.origin.y - yOrigin
            cropBoxFrame.origin.y = floor(max(cropBoxFrame.origin.y, yOrigin))
            if (Float(yDelta) < -FLT_EPSILON) {
                cropBoxFrame.size.height += CGFloat(yDelta)
            }
            
            //given the clamped X/Y values, make sure we can't extend the crop box beyond the edge of the screen in the current state
            let maxWidth = (contentFrame.size.width + contentFrame.origin.x) - cropBoxFrame.origin.x
            cropBoxFrame.size.width = floor(min(cropBoxFrame.size.width, maxWidth))
            
            let maxHeight = (contentFrame.size.height + contentFrame.origin.y) - cropBoxFrame.origin.y
            cropBoxFrame.size.height = floor(min(cropBoxFrame.size.height, maxHeight))
            
            //Make sure we can't make the crop box too small
            cropBoxFrame.size.width = max(cropBoxFrame.size.width, kEMCropViewMinimumBoxSize)
            cropBoxFrame.size.height = max(cropBoxFrame.size.height, kEMCropViewMinimumBoxSize)
            
            self.overlayView.frame = cropBoxFrame //set the new overlay view to match the same region
            
            dispatch_async(dispatch_get_main_queue()) { () -> Void in
                self.delegate?.cropView(self, didChangeCropBoxFrame: self.cropBoxFrame)
            }
            /*
            if let _delegate = self.delegate {
                let obj = _delegate as AnyObject
                if obj.respondsToSelector("cropView:didChangeCropBoxFrame:") {
                    self.delegate?.cropView!(self, didChangeCropBoxFrame: cropBoxFrame)
                }
            }
            */
        }
    }
    
    var imageSize: CGSize {
        get {
            return CGSizeMake(self.image.size.width, self.image.size.height)
        }
    }
    
    /// Current image frame inside the ImageView coordinates.
    var innerImageRect: CGRect {
        get {
            let imageSize = self.image.size;
            if (CGSizeEqualToSize(imageSize, CGSizeZero)) {
                return CGRectZero
            }
            let widthDelta = CGRectGetWidth(self.imageView.bounds) / imageSize.width
            let heightDelta = CGRectGetHeight(self.imageView.bounds) / imageSize.height
            let imageScale = fmin(widthDelta, heightDelta)
            let scaledImageSize = CGSizeMake(imageSize.width * imageScale, imageSize.height * imageScale)
            let imageFrame = CGRectMake(round(0.5 * (CGRectGetWidth(self.imageView.bounds) - scaledImageSize.width)),
                round(0.5 * (CGRectGetHeight(self.imageView.bounds) - scaledImageSize.height)),
                round(scaledImageSize.width),
                round(scaledImageSize.height))
            return imageFrame
        }
    }
    
    var contentBounds: CGRect {
        get {
            var contentRect: CGRect = CGRectZero
            contentRect.origin.x = kEMCropViewPadding + self.cropRegionInsets.left
            contentRect.origin.y = kEMCropViewPadding + self.cropRegionInsets.top
            contentRect.size.width = CGRectGetWidth(self.bounds) - ((kEMCropViewPadding * 2) + self.cropRegionInsets.left + self.cropRegionInsets.right)
            contentRect.size.height = CGRectGetHeight(self.bounds) - ((kEMCropViewPadding * 2) + self.cropRegionInsets.top + self.cropRegionInsets.bottom)
            return contentRect
        }
    }
    
    /// In relation to the coordinate space of the image, the frame that the crop view is focussing on
    var croppedImageFrame: CGRect {
        get {
            let imageSize = self.imageSize
            let contentSize = self.contentBounds.size
            let cropBoxFrame = self.cropBoxFrame
            var contentOffset = self.convertRect(cropBoxFrame, toView: self.imageView).origin
            
            let edgeInsets: UIEdgeInsets = self.cropRegionInsets
            
            let widthDelta = imageSize.width / contentSize.width
            let heightDelta = imageSize.height / contentSize.height
            
            var frame = CGRectZero
            /*
            //Old value
            frame.origin.x = floor((contentOffset.x + edgeInsets.left) * (imageSize.width / contentSize.width))
            */
            //frame.origin.x = floor((cropBoxFrame.origin.x) * widthDelta)
            frame.origin.x = floor((contentOffset.x - edgeInsets.left ) * widthDelta)
            frame.origin.x = max(0, frame.origin.x);
            
            /*
            //Old value
            frame.origin.y = floor((contentOffset.y + edgeInsets.top) * (imageSize.height / contentSize.height))
            */
            
            //Origin will be a little different for small and big images because of a scale
            /*
            CGFloat yPos = 0
            if (heightDelta <= 1) {
                yPos = floor((contentOffset.y - (edgeInsets.top * heightDelta)) * heightDelta)
            }
            else {
                yPos = floor((contentOffset.y - (edgeInsets.top / heightDelta)) * heightDelta)
            }
            frame.origin.y = yPos
            */
            frame.origin.y = floor((contentOffset.y - edgeInsets.top) * heightDelta)
            frame.origin.y = max(0, frame.origin.y)
            //A bit more of Y position adjustmant
            contentOffset.x -= kEMCropViewPadding
            contentOffset.y -= kEMCropViewPadding
            
            //Size
            frame.size.width = ceil(cropBoxFrame.size.width * widthDelta)
            frame.size.width = min(imageSize.width, frame.size.width)
            //frame.size.width -= kTOCropViewPadding
            
            frame.size.height = ceil(cropBoxFrame.size.height * heightDelta)
            frame.size.height = min(imageSize.height, frame.size.height)
            //frame.size.height -= kTOCropViewPadding
            
            return frame;
        }
    }
    
    var cropPath: UIBezierPath {
        //Build an adjusted Path
        let croppedImageFrame = self.croppedImageFrame
        let cropPath: UIBezierPath = self.overlayView.cropPath
        if (cropPath.empty || cropPath.isZeroPath) {
            return UIBezierPath.init(rect: CGRectZero)
        }

        let adjustedPath = EMBezierPathUtils.pathByAdjustingPathToFitFrame(cropPath, targetFrame: croppedImageFrame)
        
        //Move path to fit view origin
        var transform: CGAffineTransform = CGAffineTransformIdentity
        let xPixelsToMove: CGFloat = croppedImageFrame.origin.x
        let yPixelsToMove: CGFloat = croppedImageFrame.origin.y
        transform = CGAffineTransformTranslate(transform, xPixelsToMove, yPixelsToMove)
        if let buf = CGPathCreateCopyByTransformingPath(adjustedPath.CGPath, &transform) {
            return UIBezierPath.init(CGPath: buf)
        }
        
        return UIBezierPath.init(rect: CGRectZero)
    }
    
    /// Indicates a selection path type for cropView. Default is 'Rectangle'.
    var selectionType = EMSelectionType.Rectangle {
        didSet {
            self.overlayView.selectionView.type = selectionType
            
            if (!isFreeSelectionMode()) { //Rectangle or Oval mode
                if (!self.usePreDefinedSelectionFrame) {
                    self.initialCropRect = CGRectZero
                    self.isInitialRectDrawing = true
                    //self.cropBoxFrame = CGRectZero
                }
                else {
                    self.isInitialRectDrawing = false
                }
            }
            
            //Enable FreeSelection mode if needed
            self.beginFreeSelectionIfNeeded()
        }
    }
    
    
    //MARK: - Helpers
    
    func isFreeSelectionMode() -> Bool {
        return self.selectionType == .Polygon || self.selectionType == .Lasso
    }
    
    func canDoCrop() -> Bool {
        return !self.isInitialRectDrawing && !self.overlayView.selectionView.selectionIsPaused &&
            !CGRectEqualToRect(self.cropBoxFrame, CGRectZero)
    }
    
    private func beginFreeSelectionIfNeeded() -> Void {
        func tellDelegate() -> Void {
            if let aDelegate = self.delegate {
                aDelegate.cropViewIsReadyToHandleGestures?(self)
            }
        }
        
        if (!self.isFreeSelectionMode()) {
            self.overlayView.setBoundsIndicatorsLayersHidden(false)
            tellDelegate()
            return
        }
        
        self.isInitialRectDrawing = false
        
        //Double tap cleans selection BezierPath
        if (self.doubleTapHandler != nil) {
            self.removeGestureRecognizer(self.doubleTapHandler!)
            self.doubleTapHandler = nil;
        }
        self.doubleTapHandler = UITapGestureRecognizer.init(target: self, action: #selector(EMCropView.doubleTapGestureRecognized(_:)))
        self.doubleTapHandler!.numberOfTapsRequired = 2
        self.doubleTapHandler!.delegate = self
        self.doubleTapHandler!.cancelsTouchesInView = true
        self.addGestureRecognizer(self.doubleTapHandler!)
        
        //Disable cropBox view resizing and moving while drawing a shape
        self.overlayView.userInteractionEnabled = true
        
        //Resize cropView to fit bounds
        UIView.animateWithDuration(kEMInitialImageAnimationDuration, animations: { () -> Void in
            self.cropBoxFrame = self.contentBounds
            self.overlayView.setBoundsIndicatorsLayersHidden(true)
            }) { (Bool) -> Void in
                tellDelegate()
        }
    }
    
    private func cropEdgeForPoint(point: CGPoint) -> EMCropViewOverlayEdge {
        var frame = self.cropBoxFrame
        
        //account for padding around the box
        frame = CGRectInset(frame, -22.0, -22.0)
        
        //Make sure the corners take priority
        let topLeftRect = CGRectMake(frame.origin.x, frame.origin.y, 44,44)
        if (CGRectContainsPoint(topLeftRect, point)) {
            return .TopLeft
        }
        
        var topRightRect = topLeftRect
        topRightRect.origin.x = CGRectGetMaxX(frame) - 44.0
        if (CGRectContainsPoint(topRightRect, point)) {
            return .TopRight
        }
        
        var bottomLeftRect = topLeftRect
        bottomLeftRect.origin.y = CGRectGetMaxY(frame) - 44.0
        if (CGRectContainsPoint(bottomLeftRect, point)) {
            return .BottomLeft
        }
        
        var bottomRightRect = topRightRect
        bottomRightRect.origin.y = bottomLeftRect.origin.y
        if (CGRectContainsPoint(bottomRightRect, point)) {
            return .BottomRight
        }
        
        //Check for edges
        let topRect = CGRectMake(frame.origin.x, frame.origin.y, CGRectGetWidth(frame), 44.0)
        if (CGRectContainsPoint(topRect, point)) {
            return .Top
        }
        
        var bottomRect = topRect
        bottomRect.origin.y = CGRectGetMaxY(frame) - 44.0
        if (CGRectContainsPoint(bottomRect, point)) {
            return .Bottom
        }
        
        let leftRect = CGRectMake(frame.origin.x, frame.origin.y, 44.0, CGRectGetHeight(frame))
        if (CGRectContainsPoint(leftRect, point)) {
            return .Left
        }
        
        var rightRect = leftRect
        rightRect.origin.x = CGRectGetMaxX(frame) - 44.0
        if (CGRectContainsPoint(rightRect, point)) {
            return .Right
        }
        
        //Check for dragging
        let innerFrame = CGRectInset(frame, 22.0, 22.0)
        if (CGRectContainsPoint(innerFrame, point)) {
            return .Center
        }
        
        return .None
    }
    
    internal func deselect() {
        if (self.isFreeSelectionMode()) {
            self.overlayView.setBoundsIndicatorsLayersHidden(true)
            //Clear selection path
            self.overlayView.selectionView .clear(true, completion: { (_: (Bool)) -> Void in
                //Reload
                self.beginFreeSelectionIfNeeded()
            })
        }
        else {
            self.overlayView.frame = CGRectZero
            self.isInitialRectDrawing = true
        }
    }
    
    //MARK: - LifeCycle
    
    init(image: UIImage) {
        //Super
        super.init(frame: CGRectMake(0, 0, image.size.width, image.size.height))
        
        self.image = image
        self.commonInit()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self);
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.commonInit()
    }
    
    private func commonInit() {
        //View properties
        self.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
        
        if self.imageView.superview != nil {
            return
        }
        
        //ImageView
        self.addSubview(self.imageView)
        
        //Overaly view
        let frame = CGRectMake(0, 0, CGRectGetWidth(self.frame)/3,CGRectGetHeight(self.frame)/3);
        self.overlayView.frame = frame
        self.overlayView.userInteractionEnabled = false
        self.overlayView.selectionView.type = self.selectionType
        self.overlayView.selectionView.delegate = self
        self.addSubview(overlayView)
        
        //Gestures
        gridPanGestureRecognizer.addTarget(self, action: #selector(EMCropView.gridPanGestureRecognized(_:)))
        gridPanGestureRecognizer.delegate = self
        self.addGestureRecognizer(self.gridPanGestureRecognizer)
        
//        //Listeners
//        NSNotificationCenter.defaultCenter().addObserver(self,
//                                                         selector: #selector(EMCropView.deviceDidChangeOrientation(_:)),
//                                                         name: UIDeviceOrientationDidChangeNotification,
//                                                         object: nil)
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        self.layoutInitialImage()
    }
    
    //MARK: - Gestures processing
    
    internal func gridPanGestureRecognized(gesture: UIPanGestureRecognizer) -> Void {
        let point = gesture.locationInView(self)
        
        func startMoveGesture(point: CGPoint) {
            self.panOriginPoint = point
            self.cropOriginFrame = self.cropBoxFrame
            if let aPoint = self.panOriginPoint {
                tappedEdge = self.cropEdgeForPoint(aPoint)
            }
            else {
                tappedEdge = .None
            }
            
            self._addCropOriginToUndo(self.cropOriginFrame!)
        }
        
        switch (gesture.state) {
            
            case .Began:
                if (self.isInitialRectDrawing) {
                    self.initialCropRect.origin = point
                }
                else {
                    startMoveGesture(point)
                }
                
            case .Changed:  //Draw selection rect from scratch support
                if (self.isInitialRectDrawing) {
                    if (EMBezierPathUtils.distanceBetweenPoints(self.initialCropRect.origin, endPoint: point) >= 50) {
                        let distanceX = point.x - self.initialCropRect.origin.x
                        let distanceY = point.y - self.initialCropRect.origin.y
                        var origin = self.initialCropRect.origin
                        //Handle different movement directions
                        if (distanceX < 0) {
                            origin = CGPointMake(origin.x - abs(distanceX), origin.y)
                        }
                        if (distanceY < 0) {
                            origin = CGPointMake(origin.x, origin.y - abs(distanceY))
                        }
                        //Assign a new frame
                        self.initialCropRect = CGRectMake(origin.x, origin.y , abs(distanceX), abs(distanceY))
                        self.isInitialRectDrawing = false
                        self.cropBoxFrame = self.initialCropRect
                        self.overlayView.frame = self.cropBoxFrame
                        self.overlayView.selectionView.type = self.selectionType
                        startMoveGesture(point)
                    }
                }
                
            case .Cancelled, .Ended:
                self.delegate?.cropViewDidChangeUndoStatus?(self, canUndo: true)
                self.undoManager?.registerUndoWithTarget(self, selector: #selector(EMCropView.doRevertSelection), object: nil)
                
            default:
                break
            }
        
        if (!self.isInitialRectDrawing) {
            updateCropBoxFrameWithGesturePoint(point)
        }
    }
    
    internal func doubleTapGestureRecognized(gesture: UITapGestureRecognizer) {
        self.overlayView.setBoundsIndicatorsLayersHidden(true)
        //Clear selection path
        self.overlayView.selectionView .clear(true) { (_:(Bool)) -> Void in
            //Reload
            self.beginFreeSelectionIfNeeded()
        }
    }
    
    override func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        if (gestureRecognizer == self.doubleTapHandler) {
            return true
        }
        if (gestureRecognizer != self.gridPanGestureRecognizer) {
            return false
        }
        
        let tapPoint = gestureRecognizer.locationInView(self)
        
        let frame = self.overlayView.frame
        
        //let innerFrame = CGRectInset(frame, 22.0, 22.0)
        let outerFrame = CGRectInset(frame, -22.0, -22.0)
        
        if (!self.isFreeSelectionMode() && self.isInitialRectDrawing) {
            return CGRectContainsPoint(self.innerImageRect, tapPoint)
        }
        
        if (/*CGRectContainsPoint(innerFrame, tapPoint) ||*/ !CGRectContainsPoint(outerFrame, tapPoint)) {
            return false
        }
        
        return true
    }
    
    //MARK: - Orientation change handling
    
    var pathBackup: UIBezierPath?
    
    func onOrientationWillChange() {
        
        //Backup Current "Selection Path" value
        if self.overlayView.selectionView.selectionIsPaused || self.overlayView.selectionView.type == .Polygon {
            pathBackup = self.overlayView.cropPath.copy() as? UIBezierPath
        }
        else {
            pathBackup = nil
        }
        
        //Hide overlay view and it's layers
        self.overlayView.selectionHidden = true
        
        UIView.animateWithDuration(kEMInitialImageAnimationDuration, animations: {
            self.imageView.alpha = 0.0
            self.overlayView.alpha = 0.0
        })
    }
    
    func onOrientationDidChange() {
        
        self.layoutInitialImage()
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
            //Wait for rotation to be finished
            NSThread.sleepForTimeInterval(0.3)
            dispatch_async(dispatch_get_main_queue()) { () -> Void in
                
//                if TARGET_IPHONE_SIMULATOR == 1 {
                    self.layoutInitialImage()
//                }
                self.layoutInitialImage()

            }
            //Wait for layout animations to be completed
            NSThread.sleepForTimeInterval(kEMInitialImageAnimationDuration)
            dispatch_async(dispatch_get_main_queue()) { () -> Void in
                
                //Restore selection path and overlay view layers
                if let path = self.pathBackup {
                    self.beginFreeSelectionIfNeeded()
                    self.overlayView.selectionView.selectionPath = path
                    self.overlayView.selectionView.adjustInitialPointPosition()
                    
                }
                self.overlayView.selectionHidden = false
                self.pathBackup = nil
                
                UIView.animateWithDuration(kEMInitialImageAnimationDuration, animations: {
                    self.imageView.alpha = 1.0
                    self.overlayView.alpha = 1.0
                })
            }
        }
    }
    
    //MARK: - View Layout
    
    func layoutInitialImage() {
        UIView.beginAnimations(nil, context: nil)
        UIView.setAnimationBeginsFromCurrentState(true)
        UIView.setAnimationDuration(kEMInitialImageAnimationDuration)
        
        let imageSize = self.imageSize
        let bounds = self.contentBounds //NOTE: Uses cropRegionInsets
        
        //work out the max and min scale of the image
        let scale = min(CGRectGetWidth(bounds)/imageSize.width, CGRectGetHeight(bounds)/imageSize.height)
        let scaledSize = CGSizeMake(floor(imageSize.width * scale), floor(imageSize.height * scale))
        
        //Set imageView frame
        self.imageView.frame = self.contentBounds
        
        //Relayout the image in the scroll view
        func adjustFrameOrigin( frame: CGRect) -> CGRect {
            return CGRectMake(bounds.origin.x + floor((CGRectGetWidth(bounds) - frame.size.width) * 0.5),
                              bounds.origin.y + floor((CGRectGetHeight(bounds) - frame.size.height) * 0.5),
                              frame.size.width,
                              frame.size.height)
        }
        var frame = CGRectZero
        if (CGRectEqualToRect(frame, self.cropBoxFrame)) {
            frame.size = scaledSize
            frame = adjustFrameOrigin(frame)
            frame = CGRectMake(frame.origin.x, frame.origin.y, frame.size.width/2, frame.size.height/2)
            if (self.usePreDefinedSelectionFrame) {
                self.cropBoxFrame = frame
                self.isInitialRectDrawing = false
            }
            else {
                self.isInitialRectDrawing = true
                self.overlayView.frame = CGRectZero
            }
        }
        else {
            frame = self.cropBoxFrame
            frame = adjustFrameOrigin(frame)
            self.cropBoxFrame = frame
        }
        
        //adjust 'cropRegionInsets' to fit CropView
        //NOTE: Uses contentBounds
        let orientation: UIInterfaceOrientation = UIApplication.sharedApplication().statusBarOrientation
        let rect = self.innerImageRect
        if (UIInterfaceOrientationIsPortrait(orientation)) {
            self.cropRegionInsets = UIEdgeInsetsMake(rect.origin.y, //Top
                0, //Left
                CGRectGetHeight(bounds) - CGRectGetMaxY(rect), //Bottom
                0) //Right
        }
        else {
            self.cropRegionInsets = UIEdgeInsetsMake(0, //Top
                rect.origin.x, //Left
                0, //Bottom
                CGRectGetWidth(bounds) - CGRectGetMaxX(rect)) //Right
        }
        
        UIView.commitAnimations()
    }
    
    private func updateCropBoxFrameWithGesturePoint(point: CGPoint) {
        var frame = self.cropBoxFrame
        let originFrame = self.cropOriginFrame ?? CGRectZero
        let contentFrame = self.contentBounds
        
        var aPoint = point
        aPoint.x = max(contentFrame.origin.x, point.x)
        aPoint.y = max(contentFrame.origin.y, point.y)
        
        //The delta between where we first tapped, and where our finger is now
        var xDelta = ceil(aPoint.x - self.panOriginPoint!.x)
        var yDelta = ceil(aPoint.y - self.panOriginPoint!.y)

        //Current aspect ratio of the crop box in case we need to clamp it
        let aspectRatio: CGFloat = (originFrame.size.width / originFrame.size.height)
        
        var aspectHorizontal = false, aspectVertical = false
        
        switch (self.tappedEdge) {
            
            case .Center:
                frame.origin.x = originFrame.origin.x + xDelta
                frame.origin.y = originFrame.origin.y + yDelta

            case .Left:
                if (self.aspectLockEnabled) {
                    aspectHorizontal = true
                    xDelta = max(xDelta, 0)
                    let scaleOrigin = CGPointMake(CGRectGetMaxX(originFrame), CGRectGetMidY(originFrame))
                    frame.size.height = frame.size.width / aspectRatio
                    frame.origin.y = scaleOrigin.y - (frame.size.height * 0.5)
                }
                
                frame.origin.x = originFrame.origin.x + xDelta
                frame.size.width = originFrame.size.width - xDelta

            case .Right:
                if (self.aspectLockEnabled) {
                    aspectHorizontal = true
                    let scaleOrigin = CGPointMake(CGRectGetMinX(originFrame), CGRectGetMidY(originFrame))
                    frame.size.height = frame.size.width / aspectRatio
                    frame.origin.y = scaleOrigin.y - (frame.size.height * 0.5)
                    frame.size.width = originFrame.size.width + xDelta
                    frame.size.width = min(frame.size.width, contentFrame.size.height * aspectRatio)
                }
                else {
                    frame.size.width = originFrame.size.width + xDelta
                }
                
            case .Bottom:
                if (self.aspectLockEnabled) {
                    aspectVertical = true
                    let scaleOrigin = CGPointMake(CGRectGetMidX(originFrame), CGRectGetMinY(originFrame))
                    frame.size.width = frame.size.height * aspectRatio
                    frame.origin.x = scaleOrigin.x - (frame.size.width * 0.5)
                    frame.size.height = originFrame.size.height + yDelta
                    frame.size.height = min(frame.size.height, contentFrame.size.width / aspectRatio)
                }
                else {
                    frame.size.height = originFrame.size.height + yDelta
                }

            case .Top:
                if (self.aspectLockEnabled) {
                    aspectVertical = true
                    yDelta = max(0,yDelta);
                    let scaleOrigin = CGPointMake(CGRectGetMidX(originFrame), CGRectGetMaxY(originFrame))
                    frame.size.width = frame.size.height * aspectRatio
                    frame.origin.x = scaleOrigin.x - (frame.size.width * 0.5)
                    frame.origin.y = originFrame.origin.y + yDelta
                    frame.size.height = originFrame.size.height - yDelta
                }
                else {
                    frame.origin.y = originFrame.origin.y + yDelta
                    frame.size.height = originFrame.size.height - yDelta
                }

            case .TopLeft:
                if (self.aspectLockEnabled) {
                    xDelta = max(xDelta, 0)
                    yDelta = max(yDelta, 0)
                    
                    var distance = CGPointZero
                    distance.x = 1.0 - (xDelta / CGRectGetWidth(originFrame))
                    distance.y = 1.0 - (yDelta / CGRectGetHeight(originFrame))
                    
                    let scale = (distance.x + distance.y) * 0.5
                    
                    frame.size.width = ceil(CGRectGetWidth(originFrame) * scale)
                    frame.size.height = ceil(CGRectGetHeight(originFrame) * scale)
                    frame.origin.x = originFrame.origin.x + (CGRectGetWidth(originFrame) - frame.size.width)
                    frame.origin.y = originFrame.origin.y + (CGRectGetHeight(originFrame) - frame.size.height)
                    
                    aspectVertical = true
                    aspectHorizontal = true
                }
                else {
                    frame.origin.x   = originFrame.origin.x + xDelta
                    frame.size.width = originFrame.size.width - xDelta
                    frame.origin.y   = originFrame.origin.y + yDelta
                    frame.size.height = originFrame.size.height - yDelta
                }

            case .TopRight:
                if (self.aspectLockEnabled) {
                    xDelta = max(xDelta, 0)
                    yDelta = max(yDelta, 0)
                    
                    var distance = CGPointZero
                    distance.x = 1.0 - ((-xDelta) / CGRectGetWidth(originFrame))
                    distance.y = 1.0 - ((yDelta) / CGRectGetHeight(originFrame))
                    
                    var scale = (distance.x + distance.y) * 0.5
                    scale = min(1.0, scale)
                    
                    frame.size.width = ceil(CGRectGetWidth(originFrame) * scale)
                    frame.size.height = ceil(CGRectGetHeight(originFrame) * scale)
                    frame.origin.y = CGRectGetMaxY(originFrame) - frame.size.height
                    
                    aspectVertical = true
                    aspectHorizontal = true
                }
                else {
                    frame.size.width  = originFrame.size.width + xDelta
                    frame.origin.y = originFrame.origin.y + yDelta
                    frame.size.height = originFrame.size.height - yDelta
                }

            case .BottomLeft:
                if (self.aspectLockEnabled) {
                    var distance = CGPointZero
                    distance.x = 1.0 - (xDelta / CGRectGetWidth(originFrame))
                    distance.y = 1.0 - (-yDelta / CGRectGetHeight(originFrame))
                    
                    let scale = (distance.x + distance.y) * 0.5
                    
                    frame.size.width = ceil(CGRectGetWidth(originFrame) * scale)
                    frame.size.height = ceil(CGRectGetHeight(originFrame) * scale)
                    frame.origin.x = CGRectGetMaxX(originFrame) - frame.size.width
                    
                    aspectVertical = true
                    aspectHorizontal = true
                }
                else {
                    frame.size.height = originFrame.size.height + yDelta
                    frame.origin.x = originFrame.origin.x + xDelta
                    frame.size.width  = originFrame.size.width - xDelta
                }

            case .BottomRight:
                if (self.aspectLockEnabled) {
                    
                    var distance = CGPointZero
                    distance.x = 1.0 - ((-1 * xDelta) / CGRectGetWidth(originFrame))
                    distance.y = 1.0 - ((-1 * yDelta) / CGRectGetHeight(originFrame))
                    
                    let scale = (distance.x + distance.y) * 0.5
                    
                    frame.size.width = ceil(CGRectGetWidth(originFrame) * scale)
                    frame.size.height = ceil(CGRectGetHeight(originFrame) * scale)
                    
                    aspectVertical = true
                    aspectHorizontal = true
                }
                else {
                    frame.size.height = originFrame.size.height + yDelta
                    frame.size.width = originFrame.size.width + xDelta
                }
                
                
            case .None:
                break
            }
        
        //Work out the limits the box may be scaled before it starts to overlap itself
        var minSize = CGSizeZero
        minSize.width = kEMCropViewMinimumBoxSize
        minSize.height = kEMCropViewMinimumBoxSize
        
        var maxSize = CGSizeZero;
        maxSize.width = CGRectGetWidth(contentFrame)
        maxSize.height = CGRectGetHeight(contentFrame)
        
        //clamp the box to ensure it doesn't go beyond the bounds we've set
        if (self.aspectLockEnabled && aspectHorizontal) {
            maxSize.height = contentFrame.size.width / aspectRatio
            minSize.width = kEMCropViewMinimumBoxSize * aspectRatio
        }
        
        if (self.aspectLockEnabled && aspectVertical) {
            maxSize.width = contentFrame.size.height * aspectRatio
            minSize.height = kEMCropViewMinimumBoxSize / aspectRatio
        }
        
        //Clamp the minimum size
        frame.size.width  = max(frame.size.width, minSize.width)
        frame.size.height = max(frame.size.height, minSize.height)
        
        //Clamp the maximum size
        frame.size.width  = min(frame.size.width, maxSize.width)
        frame.size.height = min(frame.size.height, maxSize.height)
        
        frame.origin.x = max(frame.origin.x, CGRectGetMinX(contentFrame))
        frame.origin.x = min(frame.origin.x, CGRectGetMaxX(contentFrame) - minSize.width)
        
        frame.origin.y = max(frame.origin.y, CGRectGetMinY(contentFrame))
        frame.origin.y = min(frame.origin.y, CGRectGetMaxY(contentFrame) - minSize.height)
        
        //Handle frame resizing while dragging
        if (!self.resizeCropBoxOnDrag) {
            if (frame.origin.x + frame.size.width > contentFrame.size.width + contentFrame.origin.x) {
                frame.origin.x = contentFrame.size.width - frame.size.width + contentFrame.origin.x
            }
            
            if (frame.origin.y + frame.size.height > contentFrame.size.height + contentFrame.origin.y) {
                frame.origin.y = contentFrame.size.height - frame.size.height + contentFrame.origin.y
            }
        }
        else {
            if (frame.origin.x == contentFrame.origin.x) {
                let delta = self.prevPoint.x - aPoint.x
                if (delta > 0) {
                    frame.size.width -= delta
                }
            }
            if (frame.origin.y == contentFrame.origin.y) {
                let delta = self.prevPoint.y - aPoint.y
                if (delta > 0) {
                    frame.size.height -= delta
                }
            }
            self.prevPoint = aPoint
        }
        
        self.cropBoxFrame = frame
    }
    
    //MARK: - CLSelectionShapeViewDelegate
    
    func selectionShapeViewDidFailPanDrawingWithReason(selView: EMSelectionShapeView, reason: EMSelectionFailureReason) {
        //complain to delegate
        self.delegate?.cropViewDidFailSelectionWithReason?(self, reason: reason)
    }
    
    func selectionShapeViewDidCompleteSelectionWithPath(selView: EMSelectionShapeView, path: UIBezierPath) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
            NSThread.sleepForTimeInterval(0.5)
            dispatch_async(dispatch_get_main_queue()) { () -> Void in
                //Re-enable move & resize for cropView
                self.overlayView.userInteractionEnabled = false
                
                //Disable Selection Path auto-resize
//                self.overlayView.selectionView.autoAdjustBezierPathOnResize = false
                
                //Fit overlayView to crop BezierParh
                let aPath = path.copy()
                
                let frame = self.convertRect(aPath.bounds, fromView: selView)
                self.overlayView.frame = frame
                self.cropBoxFrame = frame
                
                UIView.animateWithDuration(kEMInitialImageAnimationDuration, animations: { () -> Void in
                    self.overlayView.setBoundsIndicatorsLayersHidden(false)
                    }, completion: { (Bool) -> Void in
                        self.overlayView.selectionView.autoAdjustBezierPathOnResize = true
                        self.delegate?.cropViewDidCompleteFreeSelection?(self)
                })
            }
        }
    }
    
    func selectionShapeViewDidPauseFreeSelectionAtPoint(selView: EMSelectionShapeView, point: CGPoint) {
        self.delegate?.cropViewDidPauseFreeSelection?(self)
    }
    
    func selectionShapeViewDidResumeFreeSelectionAtPoint(selView: EMSelectionShapeView, point: CGPoint) {
        self.delegate?.cropViewDidResumeFreeSelection?(self)
    }
    
    func selectionShapeViewDidAddPolygonPoint(selView: EMSelectionShapeView, point: CGPoint) {
        self.delegate?.cropViewDidChangeUndoStatus?(self, canUndo: true)
    }

    //MARK: - Undo
    
    func undo() {
        self.overlayView.selectionView.undoManager?.undo()
        self.undoManager?.undo()
    }
    
    func canUndo() -> Bool {
        let can = self.overlayView.selectionView.undoManager?.canUndo
        return ((self.undoManager?.canUndo == true && cropOriginsStack.count > 0) || can == true)
    }
    
    internal func doRevertSelection() {
        if (cropOriginsStack.count == 0) {
            NSLog("cropOriginsStack is empty!")
            return
        }
        let frame = NSValue(nonretainedObject: cropOriginsStack.lastObject).CGRectValue()
        cropOriginsStack.removeLastObject()
        self.cropBoxFrame = frame
        //self.delegate?.cropViewDidChangeUndoStatus(self, canUndo: self.canUndo())
    }
    
    private func _addCropOriginToUndo(originFrame: CGRect) {
        if (cropOriginsStack.count > 10) {
            cropOriginsStack.removeObjectAtIndex(0)
        }
        cropOriginsStack.addObject(NSValue.init(CGRect: originFrame))
    }
}




