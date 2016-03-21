//
//  EMSelectionShapeView.swift
//
//  Created by Evgeniy Melkov on 04.03.16.
//  Copyright © 2016 CoLocalization Research Software. All rights reserved.
//

import Foundation
import UIKit

@objc enum EMSelectionShapeViewType: Int {
    case Rectangle = 0,
    Circle, Polygon, Lasso
}

@objc enum EMSelectionFailureReason: Int {
    case PathCrossed = 0,
    TouchEnded, OutOfBorder
}

let EM_SELECTION_SHAPE_POINT_COLOR = UIColor.init(red: 0.3, green: 0.4, blue: 0.8, alpha: 1.0)

@objc protocol EMSelectionShapeViewDelegate {
    optional func selectionShapeViewDidFailPanDrawingWithReason(selView: EMSelectionShapeView, reason: EMSelectionFailureReason)
    /// Called when user locks Lasso or Polygon
    optional func selectionShapeViewDidCompleteSelectionWithPath(selView: EMSelectionShapeView, path: UIBezierPath)
    optional func selectionShapeViewDidPauseFreeSelectionAtPoint(selView: EMSelectionShapeView, point: CGPoint)
    optional func selectionShapeViewDidResumeFreeSelectionAtPoint(selView: EMSelectionShapeView, point: CGPoint)
    optional func selectionShapeViewDidAddPolygonPoint(selView: EMSelectionShapeView, point: CGPoint)
}


@objc class EMSelectionShapeView: UIView, UIGestureRecognizerDelegate {
    
    
    var delegate: EMSelectionShapeViewDelegate?
    var type: EMSelectionShapeViewType {
        didSet {
            setup()
        }
    }
    var enableTestIndicators: Bool = false
    
    /// BezierPath line color.
    var lineColor: UIColor
    /// BezierPath line width.
    var lineWidth: CGFloat
    /// Color of initial selection point. If not specified, EM_SELECTION_SHAPE_POINT_COLOR will be used
    var shapePointColor: UIColor?
    /// Circle layer with initialPoint of BazierPath used to close path.
    var initialPointLayer: CAShapeLayer? {
        get {
            return self.firstPointShape
        }
    }
    /// Indicates if BezierPath of selection should be automatically resized when view changes it's frame. Default is 'true'.
    var autoAdjustBezierPathOnResize: Bool
    /// Indicates if user can pause lasso selection by ending tap and continue existing selection path with next tap. Default is 'true'.
    var allowGesturePauseForLasso: Bool
    /// Indicates if Lasso selection is paused
    private(set) var selectionIsPaused: Bool
    
    var selectionPath: UIBezierPath {
        get {
            return aPath
        }
        set {
            aPath = newValue
            layoutSubviews()
        }
    }
    
    private
    
    /// Main BezierPath of shape
    var aPath: UIBezierPath
    /// Indicates if BezierPath is closed
    var pathIsClosed: Bool
    /// Main shape layer where path is actually being drawed
    var shapeLayer: CAShapeLayer
    /// Gesture recognizer for polygon building
    var tapGestureRecognizer: UITapGestureRecognizer?
    /// Gesture recognizer for Lasso building
    var panGestureRecognizer: UIPanGestureRecognizer?
    /// Layer which displays the first point in Lasso and Polygon mode.
    var firstPointShape: CAShapeLayer?
    /// A frame of 'firstPointShape'
    var firstPointFrame: CGRect
    /// Indicates if current point left 'firstPointShape' area
    var shapeCanBeLocked: Bool
    
    var selectionHidden: Bool {
        didSet {
            self.shapeLayer.hidden = selectionHidden
            self.firstPointShape?.hidden = selectionHidden
        }
    }
    
    let _localObserver = "panGestureRecognizer.state"
    let _k_DashAnimationKey = "dashAnimation"
    
    //MARK: - Test stuff
    
    /// TEST layer indicating an intersection
    var intersectionLayer: CAShapeLayer?
    /// TEST layer representing a line of PanGesture with current point, last point in path and initial point
    var pointsLayer: CAShapeLayer?
    /// TEST layer presenting current origin of startPoint
    var testLayer: CAShapeLayer?
    ///Used for undo manager
    var prevPath: UIBezierPath?
    
    //MARK: - Path related
    
    private func drawPathWithPointsUsingLayer(points: NSArray, layer: CAShapeLayer) {
        if (points.count < 2) {
            return
        }
        
        if (layer.superlayer != nil) {
            self.layer .addSublayer(layer)
        }
        
        func pointFromId(pointObj: AnyObject) -> CGPoint {
            if (pointObj is NSString) {
                return CGPointFromString(pointObj as! String)
            }
            else if (pointObj is NSValue) {
                return NSValue(nonretainedObject: pointObj).CGPointValue()
            }
            return CGPointZero
        }
        
        let path = UIBezierPath()
        
        for obj in points {
            let point = pointFromId(obj)
            if !CGPointEqualToPoint(point, CGPointZero) {
                path .moveToPoint(point)
            }
            let idx = points.indexOfObject(obj)
            if idx == points.count-1 {
                break
            }
            let obj2: AnyObject = points.objectAtIndex(idx+1)
            let point2 = pointFromId(obj2)
            if CGPointEqualToPoint(point2, CGPointZero) {
                path .addLineToPoint(point2)
            }
        }
        
        path.closePath()
        
        layer.path = path.CGPath
    }
    
    func resetPath() {
        aPath = UIBezierPath.init()
        pathIsClosed = false
    }
    
    private func closePath(sender: AnyObject) {
        if (pathIsClosed) {
            return
        }
        aPath.closePath()
        pathIsClosed = true
        shapeCanBeLocked = false
        firstPointFrame = CGRectZero
        firstPointShape?.hidden = true
        selectionIsPaused = false
    }
    
    private func _clear() {
        intersectionLayer?.removeFromSuperlayer()
        pointsLayer?.removeFromSuperlayer()
        
        resetPath()
        shapeLayer.path = nil
        shapeLayer.hidden = false
        
        firstPointShape?.removeFromSuperlayer()
        firstPointShape = nil
        
        testLayer?.removeFromSuperlayer()
        testLayer = nil
        
        
        startAnimation()
    }

    internal func clear(animated: Bool, completion: (((Bool)) -> Void)?) {
        
        func doWork(finished: Bool) {
            self._clear()
            completion?(finished)
        }
        
        if (animated) {
            UIView.animateWithDuration(0.2, animations: { () -> Void in
                self.shapeLayer.hidden = true
                }, completion: { (finished: Bool) -> Void in
                    doWork(finished)
            })
            return
        }
        self.shapeLayer.hidden = true
        doWork(true)
    }

    private func placeInitialShapeAtPoint(point: CGPoint) {
        let aShapeLayer = firstPointShape ?? CAShapeLayer()
        firstPointFrame = CGRectMake(point.x, point.y, 30, 30)
        firstPointFrame.origin.x = point.x - firstPointFrame.size.width / 2;
        firstPointFrame.origin.y = point.y - firstPointFrame.size.height / 2;
        aShapeLayer.frame = firstPointFrame
        //layer.position = point

        if aShapeLayer.superlayer == nil {
            self.layer.addSublayer(aShapeLayer)
        }
        
        //Blue point in the center
        if (aShapeLayer.sublayers?.count == 0 || aShapeLayer.sublayers == nil) {
            let fillColor = self.lineColor
            let strokeColor = UIColor.whiteColor()
            
            let backShape = CAShapeLayer()
            backShape.fillColor = fillColor.CGColor
            backShape.strokeColor = strokeColor.CGColor
            backShape.lineWidth = self.lineWidth
            backShape.frame = CGRectMake(0, 0, CGRectGetWidth(aShapeLayer.frame), CGRectGetHeight(aShapeLayer.frame))
            backShape.path = UIBezierPath.init(ovalInRect: backShape.frame).CGPath
            aShapeLayer.addSublayer(backShape)
            
            let sublayer = CAShapeLayer()
            let frame = CGRectMake(CGRectGetWidth(aShapeLayer.frame) / 8, CGRectGetHeight(aShapeLayer.frame) / 8,
                CGRectGetWidth(aShapeLayer.frame) / 2,
                CGRectGetHeight(aShapeLayer.frame) / 2)
            sublayer.frame = frame
            sublayer.fillColor = self.shapePointColor?.CGColor ?? EM_SELECTION_SHAPE_POINT_COLOR.CGColor
            sublayer.path = UIBezierPath.init(ovalInRect: sublayer.frame).CGPath
            aShapeLayer.addSublayer(sublayer)
        }
        //Show
        aShapeLayer.hidden = false
        
        firstPointShape = aShapeLayer
    }

    
    //MARK: - Animation
    
    private func startAnimation() {
        if shapeLayer.path == nil {
            return
        }
        if (shapeLayer.animationForKey(_k_DashAnimationKey) != nil/* && firstPointShape?.animationForKey(_k_DashAnimationKey) != nil*/) {
            return
        }
        
        let dashAnimation = CABasicAnimation.init(keyPath: "lineDashPhase")
        dashAnimation.fromValue = NSNumber.init(float: 0.0)
        dashAnimation.toValue = NSNumber.init(float: 15.0)
        dashAnimation.duration = 0.55
        dashAnimation.repeatCount = Float(INT_MAX)
        
        if (shapeLayer.animationForKey(_k_DashAnimationKey) == nil) {
            shapeLayer.addAnimation(dashAnimation, forKey: _k_DashAnimationKey)
        }
//        if (firstPointShape?.animationForKey(_k_DashAnimationKey) == nil) {
//            firstPointShape?.addAnimation(dashAnimation, forKey: _k_DashAnimationKey)
//        }
    }
    
    private func stopAniamtion() {
        shapeLayer.removeAllAnimations()
        firstPointShape?.removeAllAnimations()
    }
    
    internal
    
    //MARK: - Lifecycle
    
    override init(frame: CGRect) {
        
        lineColor = UIColor.whiteColor()
        lineWidth = 3.0
        autoAdjustBezierPathOnResize = true
        allowGesturePauseForLasso = true
        selectionIsPaused = false
        aPath = UIBezierPath()
        pathIsClosed = false
        firstPointFrame = CGRectZero
        shapeCanBeLocked = false
        type = .Rectangle
        selectionHidden = false
        shapeLayer = CAShapeLayer()
        
        super.init(frame: frame)
        
        //Observer for PanGesture
        self.addObserver(self, forKeyPath: _localObserver, options: .New, context: nil)
        self.addObserver(self, forKeyPath: "shapeLayer.path", options: .New, context: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("This class does not support NSCoding")
    }
    
    deinit {
        self.removeObserver(self, forKeyPath: _localObserver)
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    private func setup() {
        
        firstPointFrame = CGRectZero
        
        //Gestures depending of type
        switch (self.type) {
            case .Lasso:
                    if (self.panGestureRecognizer != nil) {
                        self.removeGestureRecognizer(panGestureRecognizer!)
                        panGestureRecognizer = nil
                    }
                    self.panGestureRecognizer = UIPanGestureRecognizer.init(target: self, action: "panGestureRecognized:")
                    self.panGestureRecognizer!.delegate = self
                    self.panGestureRecognizer!.delaysTouchesEnded = false
                    self.addGestureRecognizer(self.panGestureRecognizer!)

            case .Polygon:
                    if (self.tapGestureRecognizer != nil) {
                        self.removeGestureRecognizer(self.tapGestureRecognizer!)
                        self.tapGestureRecognizer = nil;
                    }
                    self.tapGestureRecognizer = UITapGestureRecognizer.init(target: self, action: "tapGestureRecognized:")
                    self.tapGestureRecognizer!.delegate = self
                    self.addGestureRecognizer(self.tapGestureRecognizer!)
                
            default:
                break;
            }
        
        //Path
        self._clear()
        
        //Layer
        shapeLayer.removeFromSuperlayer()

        shapeLayer.bounds = self.bounds
        shapeLayer.position = CGPointMake(CGRectGetWidth(self.frame)/2, CGRectGetHeight(self.frame)/2)
        shapeLayer.fillColor = UIColor.clearColor().CGColor
        shapeLayer.strokeColor = self.lineColor.CGColor
        shapeLayer.lineWidth = self.lineWidth
        shapeLayer.lineJoin = kCALineJoinRound
        shapeLayer.lineDashPattern = [NSNumber.init(int: 5), NSNumber.init(int: 10)]
        
        self.applyShapeLayerPath()
        self.layer.addSublayer(shapeLayer)
        
        //TEST stuff
        if (self.enableTestIndicators) {
            intersectionLayer = CAShapeLayer()
            intersectionLayer!.bounds = self.bounds
            intersectionLayer!.position = self.center
            intersectionLayer!.fillColor = UIColor.clearColor().CGColor
            intersectionLayer!.strokeColor = UIColor.greenColor().CGColor
            intersectionLayer!.lineWidth = 2.0
            
            pointsLayer = CAShapeLayer()
            pointsLayer!.bounds = self.bounds
            pointsLayer!.position = self.center
            pointsLayer!.fillColor = UIColor.clearColor().CGColor
            pointsLayer!.strokeColor = UIColor.blueColor().CGColor
            pointsLayer!.lineWidth = 2.0
            
            NSNotificationCenter.defaultCenter().addObserverForName(EM_NOTIFICATION_INTERSECTION_DETECTED,
                object: nil,
                queue: NSOperationQueue.mainQueue(),
                usingBlock: { (note: NSNotification) -> Void in
                    let arr = note.object as! NSArray
                    if (self.intersectionLayer != nil) {
                        self.drawPathWithPointsUsingLayer(arr, layer: self.intersectionLayer!)
                    }
            })
        }
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        self.setup()
        self.startAnimation()
    }
    
    //MARK: - KVO
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if keyPath == _localObserver {
            if (self.panGestureRecognizer?.state != .Ended) {
                return
            }
            if (!self.allowGesturePauseForLasso) {
                let pathWasClosed = self.pathIsClosed
                self.closePath((self.panGestureRecognizer ?? nil)!)
                if (!pathWasClosed) {
                    self.clear(true, completion: { (_: (Bool)) -> Void in
                        self.delegate?.selectionShapeViewDidFailPanDrawingWithReason?(self, reason: .TouchEnded)
                    })
                }
            }
            else {
                if aPath.empty == true || self.pathIsClosed {
                    return
                }
                self.selectionIsPaused = true
                let point: CGPoint = (self.panGestureRecognizer?.locationInView(self))!
                self.delegate?.selectionShapeViewDidPauseFreeSelectionAtPoint?(self, point: point)
            }
            self.undoManager?.registerUndoWithTarget(self, selector: "doAddUndoAction", object: self)
        }
        else if keyPath == "shapeLayer.path" {
            #if DEBUG
            if let path = shapeLayer.path {
                print("shapeLayer.path = \(UIBezierPath.init(CGPath: path).points)")
            }
            #endif
        }
    }
    
    //MARK: - Layout and Adjustments
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.applyShapeLayerPath()
        
        self.startAnimation()
    }
    
    override var frame: CGRect {
        didSet {
            self.applyShapeLayerPath()
            if autoAdjustBezierPathOnResize {
                self.adjustBezierPathSizeToFrame()
            }
            self.adjustBezierPathOrigin()
            shapeLayer.path = aPath.CGPath
            self.startAnimation()
        }
    }
    
    private func adjustBezierPathOrigin() {
        if (aPath.empty == true) {
            return
        }
        //Adjust BezierPath position to view bounds
        let xDelta = -1*(aPath.bounds.origin.x)
        let yDelta = -1*(aPath.bounds.origin.y)
        aPath.applyTransform(CGAffineTransformMakeTranslation(xDelta, yDelta))
    }
    
    private func adjustBezierPathSizeToFrame() {
        if shapeLayer.superlayer == nil {
            return
        }
        //Adjust BezierPath frame to view frame
        //WARNING: Stopped HERE
        print("self.bounds = \(self.bounds)  shapeLayer.frame = \(shapeLayer.frame)")
        let widthDelta = CGRectGetWidth(self.bounds) / CGRectGetWidth(shapeLayer.frame)
        let heightDelta = CGRectGetHeight(self.bounds) / CGRectGetHeight(shapeLayer.frame)
        //let scale = min(widthDelta, heightDelta)
        
        if (!isnan(widthDelta) && !isnan(heightDelta) && !isinf(widthDelta) && !isinf(heightDelta)) {
            aPath.applyTransform(CGAffineTransformMakeScale(widthDelta, heightDelta))
        }
        
        setNeedsLayout()
    }
    
    internal func adjustInitialPointPosition() {
        if (!self.selectionIsPaused || aPath.empty) {
            return
        }
        //Place point in the begging of the path
        let point: CGPoint = NSValue(nonretainedObject: aPath.points.firstObject).CGPointValue()
        self.placeInitialShapeAtPoint(point)
    }
    
    private func applyShapeLayerPath() {
        let aFrame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)
        
        switch (self.type) {
            case .Rectangle:
                aPath = UIBezierPath.init(rect: aFrame)
            
            case .Circle:
                aPath = UIBezierPath.init(ovalInRect: aFrame)
            default:
                break
        }
        
        shapeLayer.path = aPath.CGPath
        shapeLayer.frame = self.bounds
    }
    
    //MARK: - Undo
    
    internal func doAddUndoAction() {
        if (prevPath == nil || prevPath?.empty == true) {
            firstPointShape?.removeFromSuperlayer()
            firstPointShape = nil
        }
        if prevPath != nil {
            self.aPath = prevPath!
        }
        
        self.layoutSubviews()
    }
    
    //MARK: - Gesture actions & UIGestureRecognizerDelegate
    
    internal func panGestureRecognized(recognizer: UIPanGestureRecognizer) {
        if (pathIsClosed) {
            return
        }
        
        let allPoints = aPath.elements
        let point = recognizer.locationInView(self)
        let lastPointInPath: CGPoint = allPoints.last ?? CGPointZero
        let firstPointInPath: CGPoint = allPoints.first ?? CGPointZero

        //Point is out of view borders?
        if (!CGRectContainsPoint(self.frame, recognizer.locationInView(self.superview))) {
            closePath(lastPointInPath.NSValueObject)
            clear(true, completion: { (_: (Bool)) -> Void in
                self.delegate?.selectionShapeViewDidFailPanDrawingWithReason?(self, reason: .OutOfBorder)
            })
            return
        }
        //User holds his finger almost on the same place?
        if (CGPointEqualToPoint(lastPointInPath , point)) {
            //NSLog(@"Point ignored: %@", NSStringFromCGPoint(point));
            return
        }
        //Touch is out if the 'firstPointFrame' box?
        if (EMBezierPathUtils.distanceBetweenPoints(firstPointInPath, endPoint: point) > firstPointFrame.size.width * 3
            && shapeCanBeLocked == false
            && !CGSizeEqualToSize(firstPointFrame.size, CGSizeZero)
            && allPoints.count > 3) {
            self.shapeCanBeLocked = true
            //NSLog(@"Unlocking Shape with distance %f", [self distanceBetween:firstPointInPath and:point]);
        }
        //User locked a path?
        if ((CGPointEqualToPoint(point, firstPointInPath) ||
            CGRectContainsPoint(firstPointFrame, point)) &&
            self.shapeCanBeLocked &&
            allPoints.count > 3)
        {
            aPath.addLineToPoint(firstPointInPath)
            aPath.moveToPoint(firstPointInPath)
            closePath(firstPointShape!)
            shapeLayer.path = aPath.CGPath
            self.delegate?.selectionShapeViewDidCompleteSelectionWithPath?(self, path: aPath)
            return
        }
        
        //TEST: Indicate a few main points in path
        if (self.enableTestIndicators && pointsLayer != nil) {
            drawPathWithPointsUsingLayer([NSStringFromCGPoint(firstPointInPath),
                NSStringFromCGPoint(point),
                NSStringFromCGPoint(lastPointInPath)], layer: pointsLayer!)
        }
        
        //Newly added touch point intersects existing BezierPath?
        if (!pathIsClosed &&
            EMBezierPathUtils.lineWithPointsIntersectsPath(point, point2: lastPointInPath, path: aPath) &&
            allPoints.count > 3)
        {
            closePath(lastPointInPath.NSValueObject)
            clear(true, completion: { (_:(Bool)) -> Void in
                self.delegate?.selectionShapeViewDidFailPanDrawingWithReason?(self, reason: .PathCrossed)
            });
            return
        }
        
        //Selection was resumed?
        if (self.selectionIsPaused) {
            self.selectionIsPaused = false
            self.delegate?.selectionShapeViewDidResumeFreeSelectionAtPoint?(self, point: point)
        }
        
        switch (recognizer.state) {
            case .Began:
                prevPath = self.aPath.copy() as? UIBezierPath //For undo
                
                if (allPoints.count == 0) { //Initial (first) point
                    self.placeInitialShapeAtPoint(point)
                }
                else if (self.allowGesturePauseForLasso) {
                    aPath.addLineToPoint(point)
                    break
                }
                aPath.moveToPoint(point)
                
                NSLog("Moved to \(NSStringFromCGPoint(point))")
                break
                
            case .Changed:
                aPath.addLineToPoint(point)
                NSLog("Line to \(NSStringFromCGPoint(point))")
                break
                
            case .Ended: //This state is handled by the KVO
                NSLog("UIGestureRecognizerStateEnded")
                break
                
            default:
                NSLog("Unhandled UIGestureRecognizerState = \(recognizer.state)")
                break;
            }
        
        shapeLayer.path = aPath.CGPath
    }
    
    internal func tapGestureRecognized(recognizer: UITapGestureRecognizer) {
    
        if (recognizer.state == .Began || pathIsClosed) {
            return
        }
        
        let point = recognizer.locationInView(self)
        
        let containsPoint = aPath.containsPoint(point)
        let intersects = EMBezierPathUtils.newPointIntersectsPathWithPoints(point, pathPoints: aPath.points)
        if (containsPoint || intersects) {
            closePath(recognizer)
            self.delegate?.selectionShapeViewDidCompleteSelectionWithPath?(self, path: aPath)
        }
        else {
            if (self.aPath.empty) {
                prevPath = self.aPath.copy() as? UIBezierPath //For undo
                aPath.moveToPoint(point)
                self.placeInitialShapeAtPoint(point)
            }
            else {
                aPath.addLineToPoint(point)
            }
            self.undoManager?.registerUndoWithTarget(self, selector: "doAddUndoAction", object: self)
            self.delegate?.selectionShapeViewDidAddPolygonPoint?(self, point: point)
        }
        
        shapeLayer.path = aPath.CGPath
    }
    
    override func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        if (gestureRecognizer != self.tapGestureRecognizer &&
            gestureRecognizer != self.panGestureRecognizer) {
            return false
        }
        
        return true
    }
}

extension CGPoint {
    var NSValueObject: NSValue {
        return NSValue.init(CGPoint: self)
    }
}