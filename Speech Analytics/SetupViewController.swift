//
//  SetupViewController.swift
//  Speech Analytics
//
//  Created by Abdo Salem on 4/29/17.
//  Copyright © 2017 Abdo Salem. All rights reserved.
//

import UIKit
import AudioKit

class SetupViewController: UIViewController, EZMicrophoneDelegate, UITextFieldDelegate  {

    @IBOutlet weak var audioInputPlot: EZAudioPlot!
    var mic: AKMicrophone!
    var tracker: AKAmplitudeTracker!
    var micBooster: AKBooster!
    var plot: AKNodeOutputPlot!
    var recorder: AKNodeRecorder?
    var player: AKAudioPlayer?
    
    @IBOutlet weak var textPrompt: UILabel!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var instructionsPrompt: UILabel!
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var specialPrompt: UILabel!
    @IBOutlet weak var backButton: UIButton!
    
    let singleTapRec = UITapGestureRecognizer()
    let pressRec = UILongPressGestureRecognizer()
    
    var setupMode: Bool = true
    var currentPhrase: Int = 0
    var currentStage: Int = 0
    
    // Pause detection algorithm
    var pauseTimer: Timer = Timer()
    var pauseCounter: Double = 0
    let pauseDetectionInterval: TimeInterval = 0.01
    let pauseThreshold: Double = 0.05    // example from playground
    var pauseDetected: Bool = true
    let pauseDuration: TimeInterval = 0.5

    // Recording stutter samples
    var ampArray: [Float] = []
    var audioArray: [Float] = []
//    let offlineSampleRate: Float = 8000 // 2 KHz
    let buffSize: Int = 1024 // this is a constant in AKNodeOutputPlot
    var sampleRateTimer: Timer = Timer()
    let plotSampleRate: TimeInterval = 2000
    let plotResolution: Int = 2000

    let recordingPrompt: String = "\"Record\" any filler words you use in a speech then give it a name and their frequency will be analyzed after every speech. Please record one filler word at a time."
    
    // Colors
    let bgcolorEvents: [Int: UIColor] = [SpeechEventType.none.rawValue:UIColor(red: 244/255.0, green: 244/255.0, blue: 244/255.0, alpha: 1),
                                         SpeechEventType.stutter.rawValue:UIColor(red: 244/255.0, green: 244/255.0, blue: 244/255.0, alpha: 1),
                                         SpeechEventType.monotony.rawValue:UIColor(red: 244/255.0, green: 244/255.0, blue: 244/255.0, alpha: 1),SpeechEventType.longPause.rawValue:UIColor(red: 244/255.0, green: 244/255.0, blue: 244/255.0, alpha: 1)]
    let fgcolorEvents: [Int: UIColor] = [SpeechEventType.none.rawValue:UIColor(red: 241/255.0, green: 131/255.0, blue: 29/255.0, alpha: 1),
                                         SpeechEventType.stutter.rawValue:UIColor(red: 127/255.0, green: 43/255.0, blue: 130/255.0, alpha: 1),
                                         SpeechEventType.monotony.rawValue:UIColor(red: 228/255.0, green: 26/255.0, blue: 106/255.0, alpha: 1),SpeechEventType.longPause.rawValue:UIColor(red: 46/255.0, green: 175/255.0, blue: 176/255.0, alpha: 1)]
    let phrases: [Int:String] = [0:"It's a pretty good day in the .... (noun).",1:"I like long walks by the .... (noun)",2:"Woah! I didn't know this place serves .... (noun)",3:"It's my lifelong dream to go visit the .... (noun)",4:"Actually, I thought that movie was .... (adjective)",5:"It's always nice to meet a fellow .... (noun)",6:"My bad, I didn't know this belongs to .... (name)"]

    // Timing 
    var timeArray: [TimeInterval] = []
    var startTime: TimeInterval = 0.0
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup UI stuff
        self.view.addGestureRecognizer(pressRec)
        self.view.addGestureRecognizer(singleTapRec)
        
        pressRec.addTarget(self, action: #selector(ViewController.triggerKeyboard))
        singleTapRec.addTarget(self, action: #selector(ViewController.dismissKeyboard))

        textField.delegate = self
        
        button.layer.cornerRadius = button.frame.height / 2
        
        // Setup AudioKit
        AKSettings.bufferLength = .medium
        
        
        mic = AKMicrophone()
        let micMixer = AKMixer(mic)
        
        tracker = AKAmplitudeTracker.init(micMixer)
        micBooster = AKBooster(tracker, gain:0)
        
        recorder = try? AKNodeRecorder(node: micMixer)
        player = try? AKAudioPlayer(file: (recorder?.audioFile)!)
        
        let mainMixer = AKMixer(player!,micBooster!)
        AudioKit.output = mainMixer
        
        plot = AKNodeOutputPlot(mic, frame: audioInputPlot.bounds)
        plot.recordingSampleRate = UserDefaults.standard.double(forKey: "OfflineSampleRate")
        plot.gain = 2
        plot.shouldFill = true
        plot.shouldMirror = true
        plot.plotType = .buffer
        plot.backgroundColor = UIColor(white: 0.0, alpha: 0.0)
        audioInputPlot.addSubview(plot)
        audioInputPlot.sendSubview(toBack: plot)
        
        AudioKit.start()

        changePlotColor(event: SpeechEventType.longPause.rawValue)
        
        if setupMode {
            textPrompt.text = "Ready"
            instructionsPrompt.text = "Hit \"Start\" button and then say any word that fits the phrase below. Try not to stutter as much as possible."
            button.setTitle("Start", for: .normal)

            currentPhrase = 1
            currentStage = 0
        }
        else{
            currentStage = 3
            textPrompt.text = "Ready"
            button.setTitle("Record", for: .normal)
            instructionsPrompt.text = recordingPrompt
            specialPrompt.text = "Eg: Try saying \"uhh\" or \"like\"."

        }
        
    }

    func triggerKeyboard(sender: UILongPressGestureRecognizer){
        if  currentStage == 3{
            textField.isHidden = false
        }
        else{
            hideKeyboard()
        }
    }

    func dismissKeyboard(sender: UITapGestureRecognizer){
        hideKeyboard()
    }
    
    func textFieldShouldReturn(_ sender: UITextField) -> Bool {
        DispatchQueue.global(qos: .background).async {
            self.backButton.isEnabled = false
            self.textPrompt.text = "Saving ..."
            if self.saveSpeech(speechName: self.textField.text!) {
                DispatchQueue.main.async {
                    self.backButton.isEnabled = true
                    self.specialPrompt.text = "\((self.textField.text)!) pattern saved successfully!"
                    self.textPrompt.text = "Saved!"
                }
            }
        }
        hideKeyboard()
        sender.resignFirstResponder()
        return true
    }
    
    func hideKeyboard() {
        textField.endEditing(true)
        textField.isHidden = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func changePlotColor(event: Int) {
        plot.color = fgcolorEvents[event]
        textPrompt.textColor = fgcolorEvents[event]
        specialPrompt.textColor = fgcolorEvents[event]
        instructionsPrompt.textColor = fgcolorEvents[event]
    }
    
    func detectPause() {
        if tracker.amplitude < pauseThreshold {
            pauseCounter += pauseDetectionInterval
            
            // If we've been quite long enough, update stats and detectedEvent array
            if(pauseCounter >= pauseDuration){
                pauseDetected = true
            }
        }
        else{
            pauseCounter = 0
            pauseDetected = false
        }

        // If we're detecting speech speed, just record time.
        if currentStage == 1 {
            if !pauseDetected {
                if textPrompt.text != "Listening" {
                    startTime = Date().timeIntervalSince1970
                }
                textPrompt.text = "Listening"
                changePlotColor(event: SpeechEventType.none.rawValue)
                
            }
            else if textPrompt.text == "Listening" && pauseDetected && currentPhrase < phrases.count{
                timeArray.append(Date().timeIntervalSince1970 - startTime - pauseDuration)
                
                textPrompt.text = "Ready"
                changePlotColor(event: SpeechEventType.longPause.rawValue)
                
                specialPrompt.text = "\(phrases[currentPhrase] ?? "")"
                currentPhrase += 1
            }
            else if currentPhrase >= phrases.count  {
                textPrompt.text = "Done!"
                specialPrompt.text = ""
                changePlotColor(event: SpeechEventType.none.rawValue)
                
                var timeTotal: TimeInterval = 0
                for time in timeArray {
                    timeTotal += time
                }
                timeTotal /= Double(timeArray.count)
                
                var speed: String = ""
                if timeTotal < 0.160 { speed = "a Fast"}
                else if timeTotal < 0.290 { speed = "a Medium"}
                else { speed = "a Slow" }
                specialPrompt.text = "\(Int(timeTotal * 1000)) ms is your average word time.\nYou're \(speed) speaker"
                UserDefaults.standard.set(Float(timeTotal/2), forKey: "SpeechSpeed")
                currentStage = 2
            }
        }
        else if currentStage == 4 {
            if !pauseDetected {
                
                // Check if we're already recording. If not, start. If so, do nothing.
                if !(recorder?.isRecording)!{
                    plot.startRecording()
                    do {
                        try recorder?.record()
                    } catch { print("Errored recording.") }
                }
                textPrompt.text = "Listening"
                changePlotColor(event: SpeechEventType.none.rawValue)

            }
            else if textPrompt.text == "Listening" && pauseDetected {
                plot.stopRecording()
                recorder?.stop()
                
                textPrompt.text = "Ready"
                changePlotColor(event: SpeechEventType.longPause.rawValue)
            }
        }
    }

    @IBAction func buttonPressed(_ sender: UIButton) {
        // Current Stage is zero when we didn't start yet
        if currentStage == 0{
            // If pressed, then we need to start. Display first text and start timer.
            textPrompt.text = "Ready"
            specialPrompt.text = "\(phrases[0] ?? "")"
            changePlotColor(event: SpeechEventType.longPause.rawValue)
            currentPhrase = 1
            
            pauseTimer = Timer.scheduledTimer(timeInterval: pauseDetectionInterval, target: self, selector: #selector(ViewController.detectPause), userInfo: nil, repeats: true)
            button.setTitle("Stop", for: .normal)
            currentStage = 1
            
        }
        // We're in the middle of the run. If pressed we need to stop and reset all variables
        else if currentStage == 1 {
            pauseTimer.invalidate()
            timeArray.removeAll()
            currentPhrase = 0
            button.setTitle("Start", for: .normal)
            currentStage = 0
        }
        // We're done. If pressed, we need to move on to recording part. Stage 2 is ready to record
        else if currentStage == 2{
            // Stop timers and recording
            pauseTimer.invalidate()
            
            button.setTitle("Record", for: .normal)
            currentStage = 3
            instructionsPrompt.text = recordingPrompt
            specialPrompt.text = "Eg: Try saying \"uhh\" or \"like\"."
            textPrompt.text = "Ready"
        }
        // We're ready to record. If pressed, start recording
        else if currentStage == 3{
            
            pauseDetected = true
            // Setup timer to detect duration of stutter as well as plot
            pauseTimer = Timer.scheduledTimer(timeInterval: pauseDetectionInterval, target: self, selector: #selector(ViewController.detectPause), userInfo: nil, repeats: true)
            sampleRateTimer = Timer.scheduledTimer(timeInterval: 1/plotSampleRate, target: self, selector: #selector(ViewController.updateAmpandFreqArrays), userInfo: nil, repeats: true)

            
            currentStage = 4
            // Prepare for stop
            button.setTitle("Save", for: .normal)
            textPrompt.text = "Recording"
        }
        // We're recording. If pressed stop.
        else if currentStage == 4 {
            if (recorder?.isRecording)! { recorder?.stop() }
            if pauseTimer.isValid {
                pauseTimer.invalidate()
            }
            if sampleRateTimer.isValid{
                sampleRateTimer.invalidate()
            }
            
            currentStage = 3
            textPrompt.text = "Ready"
            button.setTitle("Record", for: .normal)
            instructionsPrompt.text = recordingPrompt
            textField.isHidden = false

        }
    }

    func updateAmpandFreqArrays(){
        if !pauseDetected{
            ampArray.append(Float(tracker.amplitude))
        }
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        AudioKit.stop()
    }
    
    func saveSpeech(speechName: String) -> Bool {
        let directories = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        
        if let documents = directories.first {
            if let urlDocuments = NSURL(string: documents) {
                let urlSpeechWave = urlDocuments.appendingPathComponent(speechName + "StutterSampleAudio.plist")
                let urlSpeechPlot = urlDocuments.appendingPathComponent(speechName + "StutterSampleAmp.plist")
                
                if ampArray.count == 0 {
                    print("Errored removing")
                    textPrompt.text = "Failed to save. Try again."
                    return false
                }

                // Get the audio Array
                audioArray = plot.FloatChannelData
                
                // Modify the look of the ampArray
                for i in 0..<ampArray.count{ if (i % 50 < 35 ){ ampArray[i] = 0 } }

                // Trim off the quite end
                ampArray.removeLast(Int(pauseDuration/((recorder?.audioFile?.duration)! + 0.01) * ampArray.count))
                audioArray.removeLast(Int(pauseDuration/((recorder?.audioFile?.duration)! + 0.01) * audioArray.count))
                
                if ampArray.count < plotResolution{
                    let pad = [Float](repeating: 0.0, count: plotResolution - ampArray.count)
                    ampArray = pad + ampArray + pad
                }


                // Write Array to Disk
                let wave = audioArray as NSArray
                let splot = ampArray as NSArray

                if(wave.write(toFile: (urlSpeechWave?.path)!, atomically: true)){
                    if splot.write(toFile: (urlSpeechPlot?.path)!, atomically: true) {
                        print("Written successfully")
                    }
                }
                
                let audioFile = recorder?.audioFile
                let sourcepath = URL(fileURLWithPath: (audioFile?.url.absoluteString)!)
                let destinationpath = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(speechName + "StutterSample.caf")
                
                do {
                    try FileManager().copyItem(at: sourcepath, to: destinationpath)
                }
                catch let error as NSError {
                    print("Failed to copy file into Documents directory: \(error)")
                }
            }
        }
        audioArray.removeAll()
        ampArray.removeAll()
        do{
            try recorder?.reset()
        } catch{ print("Recorder failed to reset")}
        return true
    }

}
