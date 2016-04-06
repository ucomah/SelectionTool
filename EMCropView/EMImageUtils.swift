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
    
    //MARK: - Based on gist:3549921 ( https://gist.github.com/3549921/8abea8ac9e2450f6a38540de9724d3bf850a62df )
    /*
     * Calculates the insets of transparency around all sides of the image
     *
     * @param fullyOpaque
     *        Whether the algorithm should consider pixels with an alpha value of something other than 255 as being transparent. Otherwise a non-zero value would be considered opaque.
     */
    func transparencyInsetsRequiringFullOpacity(fullyOpaque: Bool) -> UIEdgeInsets {
        // Draw our image on that context
        let width = CGImageGetWidth(self.CGImage)
        let height = CGImageGetHeight(self.CGImage)
        let bytesPerRow = width * sizeof(UInt8)
        
        // Allocate array to hold alpha channel
        let bitmapData = calloc(width * height, sizeof(UInt8))
        // Create alpha-only bitmap context
        let contextRef = CGBitmapContextCreate(bitmapData, width, height, 8, bytesPerRow, nil, CGImageAlphaInfo.Only.rawValue)

        let rect = CGRectMake(0, 0, CGFloat(width), CGFloat(height))
        CGContextDrawImage(contextRef, rect, self.CGImage)

        // Sum all non-transparent pixels in every row and every column
        let rowSum = UnsafeMutablePointer<UInt8>(calloc(height, sizeof(UInt16)))
        let colSum = UnsafeMutablePointer<UInt8>(calloc(width, sizeof(UInt16)))
        
        // Enumerate through all pixels
        for row in 0..<height {
//            let l = UnsafeMutablePointer<UInt8>(nilLiteral: bitmapData[row*bytesPerRow])
//            print(l)
            for col in 0..<width {
                if fullyOpaque {
                    // Found non-transparent pixel
                    let l = UnsafeMutablePointer<UInt8>(nilLiteral: bitmapData[row*bytesPerRow + col])
                    if (l != nil && l.memory == UInt8.max) {
                        rowSum[row] += 1
                        colSum[col] += 1
                    }
                }
                else {
                    // Found non-transparent pixel
                    let p = UnsafeMutablePointer<Int8>(nilLiteral: bitmapData[row*bytesPerRow + col])
                    if p != nil  {
                        rowSum[row] += 1
                        colSum[col] += 1
                    }
                }
            }
        }
        
//        for i in 0..<height {
//            print("rowSum[\(i)] = \(rowSum[i])")
//        }
//        for i in 0..<width {
//            print("colSum[\(i)] = \(colSum[i])")
//        }
 
        // Initialize crop insets and enumerate cols/rows arrays until we find non-empty columns or row
        var crop = UIEdgeInsetsZero

        // Top
        for i in 0..<height {
            if rowSum[i] > 0 {
                crop.top = CGFloat(i)
                break
            }
        }
        // Bottom
        for i in (0..<height).reverse() {
            if rowSum[i] > 0 {
                crop.bottom = CGFloat( max(0, height - i - 1) )
                break
            }
        }
        // Left
        for i in 0..<width {
            if (colSum[i] > 0) {
                crop.left = CGFloat(i)
                break
            }

        }
        // Right
        for i in (0..<width).reverse() {
            if colSum[i] > 0 {
                crop.right = CGFloat(max(0, width - i - 1))
                break
            }
        }
        bitmapData.destroy()
        colSum.destroy()
        rowSum.destroy()
        
        free(bitmapData)
        free(colSum)
        free(rowSum)

        return crop;
    }
    
    /*
     * Alternative method signature allowing for the use of cropping based on semi-transparency.
     */
    func imageByTrimmingTransparentPixelsRequiringFullOpacity(fullyOpaque: Bool) -> UIImage {
        if (self.size.height < 2 || self.size.width < 2) {
            return self
        }
        var rect = CGRectMake(0, 0, self.size.width * self.scale, self.size.height * self.scale)
        let crop = self.transparencyInsetsRequiringFullOpacity(fullyOpaque)
        
        if (crop.top == 0 && crop.bottom == 0 && crop.left == 0 && crop.right == 0) {
            // No cropping needed
            return self
        }
        // Calculate new crop bounds
        rect.origin.x += crop.left
        rect.origin.y += crop.top
        rect.size.width -= crop.left + crop.right
        rect.size.height -= crop.top + crop.bottom
        
        // Crop it
        let newImage = CGImageCreateWithImageInRect(self.CGImage, rect)
        
        // Convert back to UIImage
        let img = UIImage.init(CGImage: newImage!, scale: self.scale, orientation: self.imageOrientation)
        return img
    }
    
    
    
    
    func imageByTrimmingTransparentPixels() -> UIImage {
        
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
        
        
        
        let rowSum = UnsafeMutablePointer<UInt32>(calloc(height, sizeof(UInt16)))
        let colSum = UnsafeMutablePointer<UInt32>(calloc(width, sizeof(UInt16)))
        
        let pixelBuffer = UnsafeMutablePointer<UInt32>(CGBitmapContextGetData(context))
        
        // Enumerate through all pixels
        var idx = 0
        for row in 0..<height {
            for col in 0..<width {
                
//                var pixel = pixelBuffer.memory
                
                var pixel = pixelBuffer[idx]
                
                if alpha(pixel) == 0 {
                    pixel = rgba(red: 255, green: 0, blue: 0, alpha: 255)
//                    pixelBuffer.memory = pixel
                    pixelBuffer[idx] = pixel
                    
//                    rowSum[row] += 1
//                    colSum[col] += 1
                }
//                pixelBuffer += 1
                idx += 1
            }
        }
        
        
        // Initialize crop insets and enumerate cols/rows arrays until we find non-empty columns or row
        var cropInsets = UIEdgeInsetsZero
        
        // Top
        for i in 0..<height {
            if rowSum[i] > 0 {
                cropInsets.top = CGFloat(i)
                break
            }
        }
        // Bottom
        for i in (0..<height).reverse() {
            if rowSum[i] > 0 {
                cropInsets.bottom = CGFloat( max(0, height - i - 1) )
                break
            }
        }
        // Left
        for i in 0..<width {
            if (colSum[i] > 0) {
                cropInsets.left = CGFloat(i)
                break
            }
            
        }
        // Right
        for i in (0..<width).reverse() {
            if colSum[i] > 0 {
                cropInsets.right = CGFloat(max(0, width - i - 1))
                break
            }
        }

        print(">>>", cropInsets)
        
        let outputCGImage = CGBitmapContextCreateImage(context)
        let outputImage = UIImage(CGImage: outputCGImage!, scale: self.scale, orientation: self.imageOrientation)
        
        return outputImage
        
    }
    
    
    
    ////MARK: - 
    
    //http://stackoverflow.com/questions/31661023/change-color-of-certain-pixels-in-a-uiimage
    func processPixelsInImage(inputImage: UIImage) -> UIImage {
        let inputCGImage     = inputImage.CGImage
        let colorSpace       = CGColorSpaceCreateDeviceRGB()
        let width            = CGImageGetWidth(inputCGImage)
        let height           = CGImageGetHeight(inputCGImage)
        let bytesPerPixel    = 4
        let bitsPerComponent = 8
        let bytesPerRow      = bytesPerPixel * width
        let bitmapInfo       = CGImageAlphaInfo.PremultipliedFirst.rawValue | CGBitmapInfo.ByteOrder32Little.rawValue
        
        let context = CGBitmapContextCreate(nil, width, height, bitsPerComponent, bytesPerRow, colorSpace, bitmapInfo)!
        CGContextDrawImage(context, CGRectMake(0, 0, CGFloat(width), CGFloat(height)), inputCGImage)
        
        let pixelBuffer = UnsafeMutablePointer<UInt32>(CGBitmapContextGetData(context))
        
        var currentPixel = pixelBuffer
        
        for var i = 0; i < Int(height); i++ {
            for var j = 0; j < Int(width); j++ {
                let pixel = currentPixel.memory
                if red(pixel) == 0 && green(pixel) == 0 && blue(pixel) == 0 {
                    currentPixel.memory = rgba(red: 255, green: 0, blue: 0, alpha: 255)
                }
                currentPixel++
            }
        }
        
        let outputCGImage = CGBitmapContextCreateImage(context)
        let outputImage = UIImage(CGImage: outputCGImage!, scale: inputImage.scale, orientation: inputImage.imageOrientation)
        
        return outputImage
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