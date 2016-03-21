//
//  EMBezierPathUtils.swift
//
//  Created by Evgeniy Melkov on 04.03.16.
//  Copyright © 2016 CoLocalization Research Software. All rights reserved.
//

import Foundation
import UIKit

let EM_NOTIFICATION_INTERSECTION_DETECTED = "EM_NOTIFICATION_INTERSECTION_DETECTED"

@objc class EMBezierPathUtils: NSObject {
    
    static func checkLineIntersection(p1: CGPoint, p2: CGPoint, p3: CGPoint, p4: CGPoint) -> Bool {
        var denominator = (p4.y - p3.y) * (p2.x - p1.x) - (p4.x - p3.x) * (p2.y - p1.y)
        var ua = (p4.x - p3.x) * (p1.y - p3.y) - (p4.y - p3.y) * (p1.x - p3.x)
        var ub = (p2.x - p1.x) * (p1.y - p3.y) - (p2.y - p1.y) * (p1.x - p3.x)
        if (denominator < 0) {
            ua = -ua
            ub = -ub
            denominator = -denominator
        }
        return (ua > 0.0 && ua <= denominator && ub > 0.0 && ub <= denominator);
    }
    
    static func pointsAreStraightLine(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> Bool {
        let xSide = (p3.x - p1.x) / (p2.x - p1.x);
        let ySide = (p3.y - p1.y) / (p2.y - p1.y);
        return roundf(Float(xSide)) == roundf(Float(ySide));
    }
    
    static func newPointIntersectsPathWithPoints(point: CGPoint, pathPoints: NSArray) -> Bool {
        //Check if 'pathPoints' has at least 3 points already
        if (pathPoints.count < 3) {
            return false
        }
        
        //Enumerate array by checking if next 3 points
        let arr: NSMutableArray = pathPoints.mutableCopy() as! NSMutableArray
        
        repeat {
            
            let point1: CGPoint = arr.objectAtIndex(arr.count-1).CGPointValue
            let point2: CGPoint = arr.objectAtIndex(arr.count-2).CGPointValue
            let point3: CGPoint = arr.objectAtIndex(arr.count-3).CGPointValue
            
            if (self.checkLineIntersection(point, p2: point1, p3: point2, p4: point3)) {
                /*
                NSLog(@"Intersection detected for %@ with points: %@, %@, %@",
                NSStringFromCGPoint(point),
                NSStringFromCGPoint(point1),
                NSStringFromCGPoint(point2),
                NSStringFromCGPoint(point3));
                */
                let obj = [NSStringFromCGPoint(point),
                    NSStringFromCGPoint(point1),
                    NSStringFromCGPoint(point2),
                    NSStringFromCGPoint(point3)]
                NSNotificationCenter.defaultCenter().postNotificationName(EM_NOTIFICATION_INTERSECTION_DETECTED, object: obj)
                return true
            }
            
            arr.removeObjectAtIndex(arr.count-1)
            
        } while arr.count >= 3
    
        return false
    }
    
    static func lineWithPointsIntersectsPath(point1: CGPoint, point2: CGPoint, path: UIBezierPath) -> Bool {
        //Check input
        
        if (CGPointEqualToPoint(point1, point2)) {
            return false
        }
        let maxItemsNeeded = 2;
        //Check if 'pathPoints' has at least 2 points already
        let pointsArr: NSMutableArray = NSArray(array: path.points).mutableCopy() as! NSMutableArray
        if (pointsArr.count < maxItemsNeeded) {
            return false
        }
        repeat {
            let point3: CGPoint = pointsArr.objectAtIndex(pointsArr.count-1).CGPointValue
            let point4: CGPoint = pointsArr.objectAtIndex(pointsArr.count-2).CGPointValue
            
            if (self.checkLineIntersection(point1, p2: point2, p3: point3, p4: point4)) {
                let obj = [NSStringFromCGPoint(point1),
                    NSStringFromCGPoint(point2),
                    NSStringFromCGPoint(point3),
                    NSStringFromCGPoint(point4)]
                NSNotificationCenter.defaultCenter().postNotificationName(EM_NOTIFICATION_INTERSECTION_DETECTED, object: obj)
                return true
            }
        
            pointsArr.removeObjectAtIndex(pointsArr.count-1)
        
        } while pointsArr.count >= maxItemsNeeded
        
        return false
    }
    
    static func bezierPathContainsPoint(bezierPath: UIBezierPath, point: CGPoint) -> Bool {
        let bezierRect = bezierPath.bounds;
        
        if ( bezierRect.origin.x < point.x && bezierRect.origin.x + bezierRect.size.width > point.x &&
            bezierRect.origin.y < point.y && bezierRect.origin.y + bezierRect.size.height > point.y ) {
            return true
        }
        return false
    }
    
    static func distanceBetweenPoints(startPoint: CGPoint, endPoint: CGPoint) -> CGFloat {
//        let xDist = (startPoint.x - endPoint.x)
//        let yDist = (startPoint.y - endPoint.y)
//        let distance = sqrt((xDist * xDist) + (yDist * yDist));
//        return distance;
        return sqrt(pow(endPoint.x - startPoint.x, 2) + pow(endPoint.y - startPoint.y, 2));
    }
    
    
    static func pathByAdjustingPathToFitFrame(inPath: UIBezierPath, targetFrame: CGRect) -> UIBezierPath {
        /* Thanks to:
        http://stackoverflow.com/questions/15643626/scale-cgpath-to-fit-uiview
        */
        if (inPath.isZeroPath) {
            return UIBezierPath.init(rect: CGRectZero)
        }
        // I'm assuming that the view and original shape layer is already created
        let boundingBox: CGRect = CGPathGetBoundingBox(inPath.CGPath)
        
        let boundingBoxAspectRatio = CGRectGetWidth(boundingBox) / CGRectGetHeight(boundingBox)
        let viewAspectRatio = CGRectGetWidth(targetFrame) / CGRectGetHeight(targetFrame)
        
        var scaleFactor: CGFloat = 1.0
        if (boundingBoxAspectRatio > viewAspectRatio) {
            // Width is limiting factor
            scaleFactor = CGRectGetWidth(targetFrame) / CGRectGetWidth(boundingBox)
        } else {
            // Height is limiting factor
            scaleFactor = CGRectGetHeight(targetFrame) / CGRectGetHeight(boundingBox)
        }
        
        // Scaling the path ...
        var scaleTransform: CGAffineTransform = CGAffineTransformIdentity
        // Scale down the path first
        scaleTransform = CGAffineTransformScale(scaleTransform, scaleFactor, scaleFactor)
        // Then translate the path to the upper left corner
        scaleTransform = CGAffineTransformTranslate(scaleTransform, -CGRectGetMinX(boundingBox), -CGRectGetMinY(boundingBox))
        
        // If you want to be fancy you could also center the path in the view
        // i.e. if you don't want it to stick to the top.
        // It is done by calculating the heigth and width difference and translating
        // half the scaled value of that in both x and y (the scaled side will be 0)
        let scaledSize = CGSizeApplyAffineTransform(boundingBox.size, CGAffineTransformMakeScale(scaleFactor, scaleFactor))
        let centerOffset = CGSizeMake((CGRectGetWidth(targetFrame) - scaledSize.width) / (scaleFactor * 2.0),
            (CGRectGetHeight(targetFrame) - scaledSize.height) / (scaleFactor * 2.0))
        scaleTransform = CGAffineTransformTranslate(scaleTransform, centerOffset.width, centerOffset.height)
        
        //Check if scale is ok
        if (isinf(scaleTransform.a) || isnan(scaleTransform.a)) {
            return inPath
        }
        
        // End of "center in view" transformation code
        if let scaledPath = CGPathCreateCopyByTransformingPath(inPath.CGPath, &scaleTransform) {
            let path = UIBezierPath.init(CGPath: scaledPath)
            return path;
        }
        
        return inPath
    }
}

/// http://stackoverflow.com/questions/24274913/equivalent-of-or-alternative-to-cgpathapply-in-swift
extension CGPath {
    func forEach(@noescape body: @convention(block) (CGPathElement) -> Void) {
        typealias Body = @convention(block) (CGPathElement) -> Void
        func callback(info: UnsafeMutablePointer<Void>, element: UnsafePointer<CGPathElement>) {
            let body = unsafeBitCast(info, Body.self)
            body(element.memory)
        }
        //print(sizeofValue(body))
        let unsafeBody = unsafeBitCast(body, UnsafeMutablePointer<Void>.self)
        CGPathApply(self, unsafeBody, callback)
    }
}



extension UIBezierPath {
    
    var elements: [CGPoint] {
        var pathElements = [CGPoint]()
        withUnsafeMutablePointer(&pathElements) { elementsPointer in
            CGPathApply(self.CGPath, elementsPointer) { (userInfo, nextElementPointer) in
                let nextElement: CGPathElement = nextElementPointer.memory
                let elementsPointer = UnsafeMutablePointer<[CGPoint]>(userInfo)
                elementsPointer.memory.append(nextElement.points.memory)
            }
        }
        return pathElements
    }

    var elementsArray: NSArray {
        var pathElements = NSMutableArray()
        withUnsafeMutablePointer(&pathElements) { elementsPointer in
            CGPathApply(self.CGPath, elementsPointer) { (userInfo: UnsafeMutablePointer<Void>, nextElementPointer: UnsafePointer<CGPathElement>) -> Void in
                
                let element = nextElementPointer.memory
                var points: UnsafeMutablePointer<CGPoint> = element.points
                let elementsPointer = UnsafeMutablePointer<NSMutableArray>(userInfo)
                
                func value(with index: Int) -> NSValue {
                    return NSValue.init(CGPoint: points[index])
                }

                switch element.type {
                case .CloseSubpath:
                    break
                case .AddLineToPoint, .MoveToPoint:
                    elementsPointer.memory.addObject(value(with: 0))
                    break
                case .AddQuadCurveToPoint:
                    elementsPointer.memory.addObject(value(with: 1))
                    break
                case .AddCurveToPoint:
                    elementsPointer.memory.addObject(value(with: 2))
                    break
                }
            }
        }
        return pathElements
    }
    
    var points: NSArray {
        var bezierPoints: NSMutableArray = NSMutableArray()
        self.CGPath.forEach { (element: CGPathElement) -> Void in
            
            var points: UnsafeMutablePointer<CGPoint> = element.points
            
            func value(with index: Int) -> NSValue {
                return NSValue.init(CGPoint: points[index])
            }
            
            switch element.type {
            case .CloseSubpath:
                break
            case .AddLineToPoint, .MoveToPoint:
                bezierPoints.addObject(value(with: 0))
            case .AddQuadCurveToPoint:
                bezierPoints.addObject(value(with: 1))
            case .AddCurveToPoint:
                bezierPoints.addObject(value(with: 2))
            }
        }
        return bezierPoints
    }
    
    
    var isZeroPath: Bool {
        let points = self.elements
        for point in points {
            if !CGPointEqualToPoint(CGPointZero, point) {
                return false
            }
        }
        return true
//        let points = self.points
//        var zero = true
//        points.enumerateObjectsUsingBlock { (obj: AnyObject, idx: Int, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
//            if obj is NSValue {
//                let point = NSValue(nonretainedObject: obj).CGPointValue()
//                if !CGPointEqualToPoint(point, CGPointZero) {
//                    zero = false
//                    stop.memory = true
//                }
//            }
//        }
//        return zero
    }
}
