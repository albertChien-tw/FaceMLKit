//
//  ViewController.swift
//  FaceMLKit
//
//  Created by dabechen on 2018/5/16.
//  Copyright © 2018年 Dabechen. All rights reserved.
//

import UIKit
import AVFoundation
import Firebase
import Vision
import CoreML

class ViewController: UIViewController,AVCaptureVideoDataOutputSampleBufferDelegate {
    
    //MARK : Property
    enum DectionType:Int{
        case mlKit
        case coreML
    }
    var type:DectionType = DectionType.mlKit
    var faceSublayer = CALayer()
    
    lazy var captureSession:AVCaptureSession = {
        let session  = AVCaptureSession()
        session.sessionPreset = .photo
        
        guard let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ,let input = try? AVCaptureDeviceInput.init(device: front) else{return session}
        session.addInput(input)
        return session
    }()
    
    lazy var faceDetector = Vision.vision().faceDetector(options: faceDetectionOptions())
    
    var videoPreviewLayer:AVCaptureVideoPreviewLayer!
    
    var frameCount = 0
    
    //MARK : LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let deviceOutput = AVCaptureVideoDataOutput()
        
        deviceOutput.setSampleBufferDelegate(self, queue: DispatchQueue.init(label: "output"))
        deviceOutput.videoSettings = [
            ((kCVPixelBufferPixelFormatTypeKey as NSString) as String): NSNumber(value: kCVPixelFormatType_32BGRA)
        ]
        deviceOutput.alwaysDiscardsLateVideoFrames = true
        captureSession.addOutput(deviceOutput)
        
        captureSession.startRunning()
        videoPreviewLayer = AVCaptureVideoPreviewLayer.init(session: self.captureSession)
        videoPreviewLayer.frame = view.bounds
        
        self.view.layer.addSublayer(faceSublayer)
        view.layer.insertSublayer(videoPreviewLayer, at: 0)
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    @IBAction func segmentAction(_ sender: Any) {
        guard let segment = sender as? UISegmentedControl else {
            return
        }
        self.type = DectionType(rawValue: segment.selectedSegmentIndex)!
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func faceDetectionOptions()->VisionFaceDetectorOptions{
        let options = VisionFaceDetectorOptions()
        options.modeType = .accurate
        options.landmarkType = .all
        options.minFaceSize = CGFloat(0.1)
        options.isTrackingEnabled = true
        return options
    }
    
    func faceDection(_ sampleBuffer:CMSampleBuffer){
        //guard  let image = CameraUtil.imageFromSampleBuffer(sampleBuffer: buffer)else{return}
        guard let image = sampleBuffer.toUIImage(),let buffer:CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else{return}
        
        let viImage = image.toVisionImage()
        
        faceDetector.detect(in: viImage) { (faces, error) in
            self.clearFrames()
            guard error == nil ,let faces = faces, !faces.isEmpty else{return}
            
            faces.forEach({ (face) in
                
                let height = CVPixelBufferGetWidth(buffer)
                let width = CVPixelBufferGetHeight(buffer)
                let scale = self.videoPreviewLayer.frame.scaleImage(to: CGSize.init(width: width, height: height))
                
                let faceFrame = face.frame.scale(viewSize: self.videoPreviewLayer.frame, imageSize: image.size, scale: scale)
                
                self.drawFrame(faceFrame)
                let landMarkTypes: [FaceLandmarkType] = [.leftEye,.rightEye,.noseBase]
                
                for type in landMarkTypes {
                    if let landmark = face.landmark(ofType: type) {
                        let x = CGFloat(landmark.position.x) * scale + faceFrame.origin.x - face.frame.origin.x * scale
                        let y = CGFloat(landmark.position.y) * scale + faceFrame.origin.y - face.frame.origin.y * scale
                        let layer = CALayer()
                        layer.frame = CGRect.init(origin: CGPoint.init(x: x - faceFrame.width * 0.085, y: y - faceFrame.height * 0.1), size: CGSize.init(width: faceFrame.width * 0.15, height: faceFrame.height * 0.15))
                        layer.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                        layer.cornerRadius = layer.frame.width / 2
                        let image = UIImage.init(named: type.rawValue)
                        if let _ = image?.size{
                            layer.backgroundColor = UIColor.clear.cgColor
                            layer.frame =  CGRect.init(x: x - faceFrame.width * 0.175, y: y - faceFrame.height * 0.175, width: faceFrame.width * 0.35 , height: faceFrame.height * 0.35)
                            layer.contents = image?.cgImage
                        }
                        
                        self.faceSublayer.addSublayer(layer)
                    } else {
                        print("No landmark of type: \(type.rawValue) has been detected")
                    }
                }
                // self.drawFrame(faceFrame)
                
            })
        }
        
    }
    
    func proccess(every: Int, callback: () -> Void) {
        frameCount = frameCount + 1
        
        if(frameCount % every == 0) {
            callback()
        }
    }
    
    func clearFrames() {
        if faceSublayer.sublayers != nil {
            for sublayer in faceSublayer.sublayers! {
                guard let faceLayer = sublayer as CALayer? else {
                    fatalError("Error in layers")
                }
                faceLayer.removeFromSuperlayer()
            }
        }
    }
    
    func drawFrame(_ rect: CGRect) {
        let bpath: UIBezierPath = UIBezierPath(rect: rect)
        
        let rectLayer: CAShapeLayer = CAShapeLayer()
        rectLayer.path = bpath.cgPath
        rectLayer.strokeColor = UIColor.yellow.cgColor
        rectLayer.fillColor = UIColor.clear.cgColor
        rectLayer.lineWidth = 3
        
        faceSublayer.addSublayer(rectLayer)
    }
    
    
    fileprivate func handleCoreML(_ buffer: CVPixelBuffer) {
        let request = VNDetectFaceRectanglesRequest.init { (request, error) in
            DispatchQueue.main.async {
                self.clearFrames()
                guard let results = request.results as? [VNFaceObservation] else { return }
                
                for face in results {
                   
                    let scaledHight = self.view.frame.width / self.videoPreviewLayer.frame.size.width * self.videoPreviewLayer.frame.size.height
                    
                    let w = face.boundingBox.size.width * self.videoPreviewLayer.frame.size.width
                    let h = scaledHight * face.boundingBox.height
                    let x = face.boundingBox.origin.x * self.videoPreviewLayer.frame.size.width
                    let y = scaledHight * (1 - face.boundingBox.origin.y) - h
                    
                    let faceRect = CGRect(x: x, y: y, width: w, height: h)
                    
                    let outline = CALayer()
                    outline.frame = faceRect
                    outline.borderWidth = 2.0
                    outline.borderColor = UIColor.green.cgColor
                    
                    self.faceSublayer.addSublayer(outline)
                }
            }
        }
        
        try? VNImageRequestHandler(cvPixelBuffer: buffer, options: [:]).perform([request])
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
      
        switch self.type{
        case .coreML:

            guard let buffer:CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {return}
            handleCoreML(buffer)
        case .mlKit:
           
            DispatchQueue.main.async {
                self.proccess(every: 10, callback: {
                    connection.videoOrientation = .portrait
                    connection.isVideoMirrored = true
                    self.faceDection(sampleBuffer)
                })
            }
            
        }
 
    }
    
    func drawFaceboundingBox(face : VNFaceObservation)->CGRect {
        
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -self.view.frame.height)
        
        let translate = CGAffineTransform.identity.scaledBy(x: self.view.frame.width, y: self.view.frame.height)
        
        // The coordinates are normalized to the dimensions of the processed image, with the origin at the image's lower-left corner.
        let facebounds = face.boundingBox.applying(translate).applying(transform)
        
        return facebounds
    }
    
    func convertPointsForFace(_ landmark: VNFaceLandmarkRegion2D?, _ boundingBox: CGRect) {
        
        if let points = landmark?.normalizedPoints {
            let convertedPoints = convert(points)
            
            let faceLandmarkPoints = convertedPoints.map { (point: (x: CGFloat, y: CGFloat)) -> (x: CGFloat, y: CGFloat) in
                let pointX = point.x * boundingBox.width + boundingBox.origin.x
                let pointY = point.y * boundingBox.height + boundingBox.origin.y
                
                return (x: pointX, y: pointY)
            }
            for point in faceLandmarkPoints{
                let layer = CALayer()
                layer.frame = CGRect.init(x: point.x - 10, y: point.y
                     - 10, width: 20, height: 20)
                layer.backgroundColor = #colorLiteral(red: 1, green: 0.1491314173, blue: 0, alpha: 1)
                faceSublayer.addSublayer(layer)
            }
            
        }
    }
    func convert(_ points: [CGPoint]) -> [(x: CGFloat, y: CGFloat)] {
        var convertedPoints = [(x: CGFloat, y: CGFloat)]()
        for p in points{
            convertedPoints.append((CGFloat(p.x),CGFloat(p.y)))
        }
        
        return convertedPoints
    }
    
}


extension CGRect{
    
    func scaleImage(to :CGSize)->CGFloat{
        let imageSize = to
        let viewSize = self
        // Find resolution for the view and image
        let rView = viewSize.width / viewSize.height
        let rImage = imageSize.width / imageSize.height
        // Define scale based on comparing resolutions
        var scale: CGFloat
        if rView > rImage {
            scale = viewSize.height / imageSize.height
        } else {
            scale = viewSize.width / imageSize.width
        }
        return scale
    }
    
    func scale(viewSize:CGRect,imageSize:CGSize,scale:CGFloat)->CGRect{
        let width = self.size.width * scale
        let height = self.size.height * scale
        print(viewSize,imageSize)
        // Calculate scaled feature frame top-left point
        let imageWidthScaled = imageSize.width * scale
        let imageHeightScaled = imageSize.height * scale
        
        let imagePointXScaled = (viewSize.width - imageWidthScaled)  / 2
        let imagePointYScaled = (viewSize.height - imageHeightScaled)  / 2
        
        let x = imagePointXScaled + self.origin.x * scale
        let y = imagePointYScaled + self.origin.y * scale
        
        // Define a rect for scaled feature frame
        let featureRectScaled = CGRect(x: x,
                                       y: y,
                                       width: width,
                                       height: height)
        return featureRectScaled
    }
}

extension CMSampleBuffer {
    
    // Converts a CMSampleBuffer to a UIImage
    //
    // Return: UIImage from CMSampleBuffer
    func toUIImage() -> UIImage? {
        if let pixelBuffer = CMSampleBufferGetImageBuffer(self) {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            let imageRect = CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
            
            if let image = context.createCGImage(ciImage, from: imageRect) {
                
                return UIImage.init(cgImage: image)
                
            }
            
        }
        return nil
    }
    
}
extension CGRect {
    func scaled(to size: CGSize) -> CGRect {
        return CGRect(
            x: self.origin.x * size.width,
            y: self.origin.y * size.height,
            width: self.size.width * size.width,
            height: self.size.height * size.height
        )
    }
}

