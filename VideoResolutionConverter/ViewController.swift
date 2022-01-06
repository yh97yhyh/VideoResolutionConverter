//
//  ViewController.swift
//  VideoResolutionConverter
//
//  Created by MZ01-KYONGH on 2022/01/04.
//

import Cocoa
import AVKit
import AVFoundation
import Photos

class ViewController: NSViewController {
    
    var projectURL: String?
    var videoURL: String?
    var outputURL: String?
    
    var assetWriter:AVAssetWriter?
    var assetReader:AVAssetReader?
    let bitrate:NSNumber = NSNumber(value:250000)

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @IBAction func clickedSelectProject(_ sender: NSButton) {
        selectProject()
        makeOutputURL()
    }
    
    @IBAction func clickedGetVideo(_ sender: NSButton) {
        getVideo()
    }
    
    @IBAction func clickedConvertResolution(_ sender: NSButton) {
        guard let videoURL = videoURL else {
            return
        }
        let url1 = URL(string: videoURL)!

        guard let outputURL = outputURL else {
            return
        }
        let url2 = URL(string: outputURL)!

        convertResolution(inputURL: url1, outputURL: url2) { (url) in
            
        }
    }
    
    func convertResolution(inputURL: URL, outputURL: URL, completion:@escaping (URL)->Void) {
        
        var audioFinished = false
        var videoFinished = false
        
        let asset = AVAsset(url: inputURL);
        
        do {
            assetReader = try AVAssetReader(asset: asset)
        } catch{
            assetReader = nil
        }
        
        guard let reader = assetReader else{
            fatalError("Could not initalize asset reader probably failed its try catch")
        }
        
        let videoTrack = asset.tracks(withMediaType: AVMediaType.video).first!
        let audioTrack = asset.tracks(withMediaType: AVMediaType.audio).first!
 
        let videoReaderSettings: [String: Any] =  [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32ARGB ]
        
        // ADJUST BIT RATE OF VIDEO HERE
        let videoSettings: [String: Any] = [
            // AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey:self.bitrate],
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoHeightKey: 480,
            AVVideoWidthKey: 720
        ]

        
        let assetReaderVideoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: videoReaderSettings)
        let assetReaderAudioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
        
        if reader.canAdd(assetReaderVideoOutput){
            reader.add(assetReaderVideoOutput)
        } else {
            fatalError("Couldn't add video output reader")
        }
        
        if reader.canAdd(assetReaderAudioOutput){
            reader.add(assetReaderAudioOutput)
        } else {
            fatalError("Couldn't add audio output reader")
        }
        
        let audioInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: nil)
        let videoInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        videoInput.transform = videoTrack.preferredTransform
        
        let videoInputQueue = DispatchQueue(label: "videoQueue")
        let audioInputQueue = DispatchQueue(label: "audioQueue")
        
        do {
            assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: AVFileType.mov)
        } catch {
            assetWriter = nil
        }
        guard let writer = assetWriter else{
            fatalError("assetWriter was nil")
        }
        
        writer.shouldOptimizeForNetworkUse = true
        writer.add(videoInput)
        writer.add(audioInput)
        
        writer.startWriting()
        reader.startReading()
        writer.startSession(atSourceTime: CMTime.zero)
        
        
        let closeWriter: (() -> Void) = {
            if (audioFinished && videoFinished){
                self.assetWriter?.finishWriting(completionHandler: {
                    
                    // self.checkFileSize(sizeUrl: (self.assetWriter?.outputURL)!, message: "The size of the file is: ")
                    
                    completion((self.assetWriter?.outputURL)!)
                    
                })
                
                self.assetReader?.cancelReading()
 
            }
        }
 
        
        audioInput.requestMediaDataWhenReady(on: audioInputQueue) {
            while(audioInput.isReadyForMoreMediaData) {
                let sample = assetReaderAudioOutput.copyNextSampleBuffer()
                if (sample != nil){
                    audioInput.append(sample!)
                } else {
                    audioInput.markAsFinished()
                    DispatchQueue.main.async {
                        audioFinished = true
                        closeWriter()
                    }
                    break
                }
            }
        }
        
        videoInput.requestMediaDataWhenReady(on: videoInputQueue) {
            while(videoInput.isReadyForMoreMediaData) {
                let sample = assetReaderVideoOutput.copyNextSampleBuffer()
                if (sample != nil){
                    videoInput.append(sample!)
                } else {
                    videoInput.markAsFinished()
                    DispatchQueue.main.async {
                        videoFinished = true
                        closeWriter()
                    }
                    break
                }
            }
 
        }
        
        
    }
    
    func checkFileSize(sizeUrl: URL, message:String) {
        let data = NSData(contentsOf: sizeUrl)!
        print(message, (Double(data.length) / 1048576.0), " mb")
    }
    
    
    private func selectProject() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        
        let status = openPanel.runModal()
        
        if status == NSApplication.ModalResponse.OK {
            guard let url = URL(string: openPanel.url!.absoluteString) else { return }
            var photosURL = url.absoluteString
            let startIdx: String.Index = photosURL.index(photosURL.startIndex, offsetBy: 7)
            projectURL = String(photosURL[startIdx...])
        }
    }
    
    private func getVideo() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = true
        
        let status = openPanel.runModal()
        
        if status == NSApplication.ModalResponse.OK {
            guard let url = URL(string: openPanel.url!.absoluteString) else {return}
            var fileURL = url.absoluteString
            let startIdx: String.Index = fileURL.index(fileURL.startIndex, offsetBy: 7)
            videoURL = String(fileURL[startIdx...])
            videoURL = "file://" + videoURL!
        }
    }
    
    private func makeOutputURL() {
        guard let projectURL = projectURL else {
            print("Failed to create projectURL")
            return
        }

        let videoFolder = projectURL + "output/"
        outputURL = "file://" + videoFolder + "video.mp4"
        
        guard let outputURL = outputURL else {
            print("Failed to create outputURL")
            return
        }
        
        do {
            if !FileManager.default.fileExists(atPath: videoFolder){
                try FileManager.default.createDirectory(atPath: videoFolder, withIntermediateDirectories: true, attributes: nil)
                print("Success to create outputURL : \(outputURL)")
            }
        } catch {
            print(error)
        }
    }

    
}

