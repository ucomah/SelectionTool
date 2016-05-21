# SelectionTool
An image selection and cropping tool which provides different ways of image crop paths building. 
Fully written in Swift.

**Plans for expanding, or what code already exists and can be added to this app in near future:**

1. Filters
2. Histogram & Scattergram
3. Smooth Rotation and Flip
4. Drawing with finger e.g. "Brush" tool
5. Auto-enhance image
6. Brightness, contrast tuning
7. Export to JPG, PNG, TIFF, PDF
8. "Square crop" tool - the copy of iOS basic one
9. Pretty color selection tool 
10. Any pixel-by-pixel work is possible for Mac OS and iOS (thanks to existing library)
11. Image pretty resize using scale or pre-defined sizes (like in other apps)


**Known bugs:**

1. Adjust a Free selection mode initial point size for iPhone
2. ImageUtils: Trim tool - make it use a clousre for pixels enumeration
3. Rotation bugs if image is smaller then crop box frame
4. CameraRoll portrait images getting rotated to landscape on Main screen reload