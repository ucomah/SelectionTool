//
//  EMCropOverlayView.swift
//
//  Created by Evgeniy Melkov on 04.03.16.
//  Copyright © 2016 CoLocalization Research Software. All rights reserved.
//

import Foundation
import UIKit

@objc class EMCropOverlayView: UIView {
    
    private(set) var selectionView = EMSelectionShapeView.init(frame: CGRectZero)
    
    var cropBoxColor = UIColor.whiteColor() {
        didSet {
            self.borderLayer.strokeColor = cropBoxColor.CGColor
        }
    }
    
    var cropBoxLineWidth: CGFloat = 0.8 {
        didSet {
            self.borderLayer.lineWidth = cropBoxLineWidth
        }
    }
    
    var resizingPointInnerColor = EM_SELECTION_SHAPE_POINT_COLOR {
        didSet {
            layoutSubviews()
        }
    }
    
    var resizingPointOuterColor = UIColor.whiteColor() {
        didSet {
            layoutSubviews()
        }
    }
    
    var cropPath: UIBezierPath {
        get {
            return self.selectionView.selectionPath
        }
    }
    
    func setBoundsIndicatorsLayersHidden(hidden: Bool) {
        if let sublayers = self.layer.sublayers {
            for layer in sublayers {
                if layer is CAShapeLayer {
                    layer.hidden = hidden
                }
            }
        }
    }
    
    private
    
    var topRightCirclePoint: CAShapeLayer?
    var topLeftCirclePoint: CAShapeLayer?
    var topCenterCirclePoint: CAShapeLayer?
    
    var leftCenterCirclePoint: CAShapeLayer?
    var rightCenterCirclePoint: CAShapeLayer?
    
    var bottomRightCirclePoint: CAShapeLayer?
    var bottomLeftCirclePoint: CAShapeLayer?
    var bottomCenterCirclePoint: CAShapeLayer?
    
    var borderLayer = CAShapeLayer()
    
    //MARK: - Overrides
    
    internal
    
    override var frame: CGRect {
        didSet {
            
            CATransaction.begin()
            CATransaction.setValue(true, forKey: kCATransactionDisableActions)
        
            self.alpha = CGRectEqualToRect(CGRectZero, frame) ? 0.0 : 1.0
            
            if CGRectEqualToRect(CGRectZero, selectionView.frame) {
                selectionView.frame = CGRectMake(0, 0, frame.size.width, frame.size.height)
            }

            borderLayer.frame = CGRectMake(0, 0, frame.size.width, frame.size.height)
            borderLayer.position = CGPointMake(frame.size.width/2, frame.size.height/2)
            borderLayer.path = UIBezierPath.init(rect: borderLayer.frame).CGPath
            borderLayer.lineWidth = self.cropBoxLineWidth
            borderLayer.strokeColor = self.cropBoxColor.CGColor
            
            topRightCirclePoint?.position = CGPointMake(frame.size.width, 0)
            topLeftCirclePoint?.position = CGPointMake(0, 0)
            topCenterCirclePoint?.position = CGPointMake(frame.size.width/2, 0)
            
            leftCenterCirclePoint?.position = CGPointMake(0, frame.size.height/2)
            rightCenterCirclePoint?.position = CGPointMake(frame.size.width, frame.size.height/2)
            
            bottomRightCirclePoint?.position = CGPointMake(frame.size.width, frame.size.height)
            bottomLeftCirclePoint?.position = CGPointMake(0, frame.size.height)
            bottomCenterCirclePoint?.position = CGPointMake(frame.size.width/2, frame.size.height)
            
            CATransaction.commit()
            
            selectionView.frame = self.bounds
            
            self.layoutSubviews()
            selectionView.layoutSubviews()
        }
    }
    
    //MARK: - LifeCycle
    
    convenience init() {
        self.init(frame: CGRectZero)
    }
    
    override init(frame: CGRect) {
        
        super.init(frame: frame)
        
        self.frame = frame
        
        self.backgroundColor = UIColor.clearColor()
        
        self.borderLayer.fillColor = UIColor.clearColor().CGColor
        self.layer.addSublayer(borderLayer)
        
        self.userInteractionEnabled = true
        
        selectionView.backgroundColor = UIColor.clearColor()
        self.addSubview(selectionView)
        
        topRightCirclePoint = self.newCircleShapeLayer()
        self.layer.addSublayer(topRightCirclePoint!)
        topLeftCirclePoint = self.newCircleShapeLayer()
        self.layer.addSublayer(topLeftCirclePoint!)
        topCenterCirclePoint = self.newCircleShapeLayer()
        self.layer.addSublayer(topCenterCirclePoint!)
        
        leftCenterCirclePoint = self.newCircleShapeLayer()
        self.layer.addSublayer(leftCenterCirclePoint!)
        rightCenterCirclePoint = self.newCircleShapeLayer()
        self.layer.addSublayer(rightCenterCirclePoint!)
        
        bottomRightCirclePoint = self.newCircleShapeLayer()
        self.layer.addSublayer(bottomRightCirclePoint!)
        bottomLeftCirclePoint = self.newCircleShapeLayer()
        self.layer.addSublayer(bottomLeftCirclePoint!)
        bottomCenterCirclePoint = self.newCircleShapeLayer()
        self.layer.addSublayer(bottomCenterCirclePoint!)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    //MARK: - Utils
    
    private func newCircleShapeLayer() -> CAShapeLayer {
        let layer = CAShapeLayer()
        var frame = CGRectMake(0, 0, 16, 16)
        layer.frame = frame
        layer.fillColor = self.resizingPointOuterColor.CGColor
        layer.path = UIBezierPath.init(ovalInRect: frame).CGPath
        
        let sublayer = CAShapeLayer()
        frame = CGRectMake(CGRectGetWidth(layer.frame) / 8,
            CGRectGetHeight(layer.frame) / 8,
            CGRectGetWidth(layer.frame) / 2,
            CGRectGetHeight(layer.frame) / 2)
        sublayer.frame = frame
        sublayer.fillColor = self.resizingPointInnerColor.CGColor
        sublayer.path = UIBezierPath.init(ovalInRect: sublayer.frame).CGPath
        layer.addSublayer(sublayer)
        return layer
    }
    
    var selectionHidden: Bool {
        set {
            self.borderLayer.hidden = newValue
            self.selectionView.selectionHidden = newValue
            for layer in self.layer.sublayers! {
                layer.hidden = newValue
            }
        }
        get {
            return self.borderLayer.hidden && self.selectionView.selectionHidden
        }
    }
}