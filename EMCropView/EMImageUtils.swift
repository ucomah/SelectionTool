//
//  EMImageUtils.swift
//
//  Created by Evgeniy Melkov on 05.04.16.
//  Copyright © 2016 Evgeniy Melkov. All rights reserved.
//

import UIKit


extension UIImage {
    func rotateByDegrees(degrees: CGFloat) -> UIImage {
        // calculate the size of the rotated view's containing box for our drawing space
        let rotatedViewBox = UIView.init(frame: CGRectMake(0, 0, self.size.width, self.size.height))
        let transform = CGAffineTransformMakeRotation(degrees * CGFloat(M_PI) / 180)
        rotatedViewBox.transform = transform
        let rotatedSize = rotatedViewBox.frame.size
        // Create the bitmap context
        UIGraphicsBeginImageContext(rotatedSize)
        let bitmap = UIGraphicsGetCurrentContext()
        if bitmap == nil {
            return self
        }
        // Move the origin to the middle of the image so we will rotate and scale around the center.
        CGContextTranslateCTM(bitmap, rotatedSize.width/2, rotatedSize.height/2);
        // Rotate the image context
        CGContextRotateCTM(bitmap, degrees * CGFloat(M_PI) / 180)
        // Now, draw the rotated/scaled image into the context
        CGContextScaleCTM(bitmap, 1.0, -1.0)
        CGContextDrawImage(bitmap, CGRectMake(-self.size.width / 2, -self.size.height / 2, self.size.width, self.size.height), self.CGImage)
        // Extract image
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    
    func maskToPath(path: UIBezierPath) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.size, false, 0)
        path.addClip()
        self.drawAtPoint(CGPointZero)
        let maskedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return maskedImage
    }
    
    func scaleToWidth(i_width: CGFloat) -> UIImage {
        let oldWidth = self.size.width
        let scaleFactor = i_width / oldWidth
        
        let newHeight = self.size.height * scaleFactor
        let newWidth = oldWidth * scaleFactor
        
        UIGraphicsBeginImageContext(CGSizeMake(newWidth, newHeight))
        self.drawInRect(CGRectMake(0, 0, newWidth, newHeight))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    
    
    //TODO: Pack this function's pixels enumeration in for_each closure
    
    func imageByTrimmingTransparentPixels() -> UIImage {
        if (self.size.height < 2 || self.size.width < 2) {
            return self
        }
        
        let inputCGImage = self.CGImage
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let width = CGImageGetWidth(inputCGImage)
        let height = CGImageGetHeight(inputCGImage)
        let bytesPerPixel = 4
        let bitsPerComponent = 8
        let bytesPerRow = bytesPerPixel * width
        let bitmapInfo = CGImageAlphaInfo.PremultipliedFirst.rawValue | CGBitmapInfo.ByteOrder32Little.rawValue
        
        let context = CGBitmapContextCreate(nil, width, height, bitsPerComponent, bytesPerRow, colorSpace, bitmapInfo)!
        CGContextDrawImage(context, CGRectMake(0, 0, CGFloat(width), CGFloat(height)), inputCGImage)
        
        let pixelBuffer = UnsafeMutablePointer<UInt32>(CGBitmapContextGetData(context))
        
        var maxRowPixelNumber = -1
        var maxColPixelNumber = -1
        var minRowPixelNumber = Int.max
        var minColPixelNumber = Int.max
        
        // Enumerate through all pixels
        var idx = 0
        for row in 0..<height {
            for col in 0..<width {
                let pixel = pixelBuffer[idx]
                if alpha(pixel) != 0 { //Transparent pixel
                    //pixel = rgba(red: 255, green: 0, blue: 0, alpha: 255)
                    if minRowPixelNumber > row {
                        minRowPixelNumber = row
                    }
                    if minColPixelNumber > col {
                        minColPixelNumber = col
                    }
                    if maxRowPixelNumber < row  {
                        maxRowPixelNumber = row
                    }
                    if maxColPixelNumber < col {
                        maxColPixelNumber = col
                    }
                }
                idx += 1
            }
        }
        
        var cropInsets = UIEdgeInsetsZero
        var rect = CGRectMake(0, 0, self.size.width * self.scale, self.size.height * self.scale)
        
        cropInsets = UIEdgeInsetsMake(CGFloat(minRowPixelNumber), CGFloat(minColPixelNumber),
                                      rect.size.height - CGFloat(maxRowPixelNumber), rect.size.width - CGFloat(maxColPixelNumber))
        
        if (cropInsets.top <= 0 && cropInsets.bottom <= 0 && cropInsets.left <= 0 && cropInsets.right <= 0) {
            // No cropping needed
            return self
        }
        
        // Calculate new crop bounds
        rect.origin.x += cropInsets.left
        rect.origin.y += cropInsets.top
        rect.size.width -= cropInsets.left + cropInsets.right
        rect.size.height -= cropInsets.top + cropInsets.bottom
        
        // Crop it
        let newImage = CGImageCreateWithImageInRect(inputCGImage, rect)
        
        // Convert back to UIImage
        let img = UIImage.init(CGImage: newImage!, scale: self.scale, orientation: self.imageOrientation)
        
        //Free memory
        pixelBuffer.destroy()
        
        return img
    }
    
    private
    
    func alpha(color: UInt32) -> UInt8 {
        return UInt8((color >> 24) & 255)
    }
    
    func red(color: UInt32) -> UInt8 {
        return UInt8((color >> 16) & 255)
    }
    
    func green(color: UInt32) -> UInt8 {
        return UInt8((color >> 8) & 255)
    }
    
    func blue(color: UInt32) -> UInt8 {
        return UInt8((color >> 0) & 255)
    }
    
    func rgba(red red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) -> UInt32 {
        return (UInt32(alpha) << 24) | (UInt32(red) << 16) | (UInt32(green) << 8) | (UInt32(blue) << 0)
    }
}