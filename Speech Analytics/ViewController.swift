//
//  ViewController.swift
//  Speech Analytics
//
//  Created by Abdo Salem on 2/20/17.
//  Copyright © 2017 Abdo Salem. All rights reserved.
//

import UIKit
import AudioKit

class ViewController: UIViewController, EZMicrophoneDelegate, ARPieChartDelegate, ARPieChartDataSource, UITextFieldDelegate {
    
    // Audio Elements
    @IBOutlet weak var audioInputPlot: EZAudioPlot!
    var mic: AKMicrophone!
    var tracker: AKFrequencyTracker!
    var micBooster: AKBooster!
    var plot: AKNodeOutputPlot!
    var recorder: AKNodeRecorder?
    var player: AKAudioPlayer?
    var tape: AKAudioFile?

    
    // UI Elements
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var speechNameTextField: UITextField!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var switchRecord: UISwitch!
    @IBOutlet var speechEventLabel: UILabel!
    @IBOutlet var timeEventLabel: UILabel!
    var uiTimer: Timer = Timer()
    let uiUpdateInterval: TimeInterval = 0.01 // 10 ms
    
    // Ui Features
    var clockCounter: Double = 0
    var eventDisplayDelay: Double = 0
    
    // Options
    var enableMonotonyDetection = true
    var enableStutterDetection = true
    var enableLongPauseDetection = true
    var offlineProcessingType: Int = 2
    
    // Monotony calculations
    var monotonyTimer: Timer = Timer()
    let monotonySampleRate: TimeInterval = 10 // 10 Hz
    let monotonyWindowSize: TimeInterval = 0.5 // 0.5 sec
    var dominantFreq: Int = 1
    var repeatedFreqCount: Int = 1
    var repeatedFreq: Int = 0
    var monotonyCycles: Double = 0
    let monotonyThresholdDiff: Int = 2
    var freqHistogram: [Int] = []
    var histogramSize: Int = 0
    let histogramRange: Int = 500
    let monotonyScale: Int = 10
    
    // Long pause calculations
    var pauseTimer: Timer = Timer()
    var pauseCounter: Double = 0
    let pauseDetectionInterval: TimeInterval = 0.1
    let pauseThreshold: Double = 0.05    // example from playground

    // Stutter calculations
    var stutterCurrentSignalSize: Double = 0.180
    var stutterSampleRate: Float = 8000 // 2 KHz
    let stutterThreshold: Float = 0.7
    var stutterTimer: Timer = Timer()
    var stutterInterval: TimeInterval = 0.3
    let signalPaddingEnabled = true
    var stutterTotalSignalSize: Double = 1
    
    // Gesture Recognizers
    let panRec = UIPanGestureRecognizer()
    let doubleTapRec = UITapGestureRecognizer()
    let singleTapRec = UITapGestureRecognizer()
    let pressRec = UILongPressGestureRecognizer()

    // Moving timeline (after recording is done)
    var currPan: Int = 0
    var currTime: Double = 0
    var sampleRateTimer: Timer = Timer()
    let plotResolution: Int = 4000
    let plotSampleRate: TimeInterval = 2000
    let plotSpeed: Int32 = 4
    var ampArray: [Float] = [] // used to fill the plot later. Also for long pause detection
    
    // Audio Signal Data
    var audioRingBuff: RingBuffer<Float>! // store upto 680 ms of the signal at once time
    var currBuffIndex: Int = 0
    let buffSize: Int = 1024 // this is a constant in AKNodeOutputPlot
    var audioTimer: Timer = Timer()
    let audioSampleRate: TimeInterval = 0.02321995465 // Time it takes to renew the buffer with 1024 samples at 44 KHz
    
    // Speech Events
    var currEvent: SpeechEventType!
    var eventArray: [Int] = []
    let bgcolorEvents: [Int: UIColor] = [SpeechEventType.none.rawValue:UIColor(red: 244/255.0, green: 244/255.0, blue: 244/255.0, alpha: 1),
                                                     SpeechEventType.stutter.rawValue:UIColor(red: 244/255.0, green: 244/255.0, blue: 244/255.0, alpha: 1),
                                                     SpeechEventType.monotony.rawValue:UIColor(red: 244/255.0, green: 244/255.0, blue: 244/255.0, alpha: 1),SpeechEventType.longPause.rawValue:UIColor(red: 244/255.0, green: 244/255.0, blue: 244/255.0, alpha: 1)]
    let fgcolorEvents: [Int: UIColor] = [SpeechEventType.none.rawValue:UIColor(red: 241/255.0, green: 131/255.0, blue: 29/255.0, alpha: 1),
                                                     SpeechEventType.stutter.rawValue:UIColor(red: 127/255.0, green: 43/255.0, blue: 130/255.0, alpha: 1),
                                                     SpeechEventType.monotony.rawValue:UIColor(red: 228/255.0, green: 26/255.0, blue: 106/255.0, alpha: 1),SpeechEventType.longPause.rawValue:UIColor(red: 46/255.0, green: 175/255.0, blue: 176/255.0, alpha: 1)]

    let textEvents: [Int:String] = [SpeechEventType.none.rawValue:"Good",
                                               SpeechEventType.stutter.rawValue:"Stutter",
                                               SpeechEventType.monotony.rawValue:"Monotonous",
                                               SpeechEventType.longPause.rawValue:"Pause"]
    let displayDelay: [Int:TimeInterval] = [SpeechEventType.none.rawValue:0,
                                                SpeechEventType.stutter.rawValue:1,
                                                SpeechEventType.monotony.rawValue:0,
                                                SpeechEventType.longPause.rawValue:0]
    var detectedEvent: [Int:Bool] = [SpeechEventType.none.rawValue:true,
                                                 SpeechEventType.stutter.rawValue:false,
                                                 SpeechEventType.monotony.rawValue:false,
                                                 SpeechEventType.longPause.rawValue:false]
    let priorityEvents: [Int] = [SpeechEventType.monotony.rawValue,
                                             SpeechEventType.longPause.rawValue,
                                             SpeechEventType.stutter.rawValue,
                                             SpeechEventType.none.rawValue]
    var eventDuration: [Int:TimeInterval] = [SpeechEventType.monotony.rawValue:3,    // 3 seconds
                                                         SpeechEventType.longPause.rawValue:3,   // 3 seconds
                                                         SpeechEventType.stutter.rawValue:1,     // 1 stutter
                                                         SpeechEventType.none.rawValue:0]
    
    // Stats
    var eventOccurences: [Int: Double] = [SpeechEventType.stutter.rawValue:0,
                                                   SpeechEventType.longPause.rawValue:0,
                                                   SpeechEventType.monotony.rawValue:0]
    var scoreDataItems: [PieChartItem] = []
    var silenceDataItems: [PieChartItem] = []
    var monotonyDataItems: [PieChartItem] = []
    var percentSilent: CGFloat = 0
    var percentMonotone: CGFloat = 0
    var percentNeither: CGFloat = 0

    @IBOutlet weak var statView: UIView!
    @IBOutlet weak var scoreChart: ARPieChart!
    @IBOutlet weak var scoreDataLabel: UILabel!
    @IBOutlet weak var monotonyChart: ARPieChart!
    @IBOutlet weak var monotonyDataLabel: UILabel!
    @IBOutlet weak var silenceChart: ARPieChart!
    @IBOutlet weak var silenceDataLabel: UILabel!
    @IBOutlet weak var stutterDataLabel: UILabel!
    @IBOutlet weak var timeDataLabel: UILabel!
    @IBOutlet weak var timelineCursor: UIImageView!
    
    // Standard Offline Processing
    var audioArray: [Float] = []
    var patternHistogram: [Int] = []
    var patternStartTime: [Double] = []
    var patternEndTime: [Double] = []
    var highestIDs: [Int] = []
    @IBOutlet weak var processingButton: UIButton!
    let numPatterns: Int = 10
    
    // Personal offline processing
    var patternNames: [String] = []
    var patternArray: [Pattern] = []
    
    // Segue state restoration
    var restoreState: Bool = false
    var currStats: Stats?
    
    override func viewDidLoad() {
        super.viewDidLoad()
       
        // Setup chart delegates
        scoreChart.delegate = self
        scoreChart.dataSource = self
        monotonyChart.delegate = self
        monotonyChart.dataSource = self
        silenceChart.delegate = self
        silenceChart.dataSource = self
        
        // Get settings
        stutterCurrentSignalSize = Double(UserDefaults.standard.float(forKey: "SpeechSpeed"))
        
        enableMonotonyDetection = UserDefaults.standard.bool(forKey: "MonotonyEnabled")
        enableLongPauseDetection = UserDefaults.standard.bool(forKey: "SilenceEnabled")
        offlineProcessingType = UserDefaults.standard.integer(forKey: "ProcessingType")
        enableStutterDetection = UserDefaults.standard.bool(forKey: "StutterEnabled")
        
        eventDuration[SpeechEventType.longPause.rawValue] = Double(UserDefaults.standard.float(forKey: "SilenceDuration"))
        eventDuration[SpeechEventType.monotony.rawValue] = Double(UserDefaults.standard.float(forKey: "MonotonyDuration"))
        
        
        // Add gesture recognizers
        // Pan for moving timeline
        panRec.addTarget(self, action: #selector(ViewController.handlePan))
        // Long Press to show keyboard
        pressRec.addTarget(self, action: #selector(ViewController.triggerKeyboard))
        // Double tap to play audio
        doubleTapRec.addTarget(self, action: #selector(ViewController.viewTapped))
        doubleTapRec.numberOfTapsRequired = 2
        // Single tap to dismiss keyboard after editing
        singleTapRec.addTarget(self, action: #selector(ViewController.dismissKeyboard))
        singleTapRec.numberOfTapsRequired = 1
        singleTapRec.require(toFail: doubleTapRec)

        self.view.addGestureRecognizer(panRec)
        self.view.addGestureRecognizer(pressRec)
        self.view.addGestureRecognizer(doubleTapRec)
        self.view.addGestureRecognizer(singleTapRec)
        
        // Setup text field
        speechNameTextField.delegate = self
        
        if restoreState{
            // Setup AudioKit
            AKSettings.bufferLength = .medium
            
            do {
                try AKSettings.setSession(category:.playback, with: .defaultToSpeaker)
            } catch { print("Errored setting category.") }
            
            // Setup audio kit for recording and plotting
            // Audiokit's already set
            mic = AKMicrophone()
            
            plot = AKNodeOutputPlot(mic, frame: audioInputPlot.bounds)
            plot.gain = 1
            plot.shouldFill = true
            plot.shouldMirror = true
            audioInputPlot.addSubview(plot)
            audioInputPlot.sendSubview(toBack: plot)
            
            // Setup plot and stats
            currPan = ampArray.count < plotResolution ? 0: ampArray.count - plotResolution - 1
            plot.plotType = .buffer
            plot.color = fgcolorEvents[SpeechEventType.none.rawValue]
            audioInputPlot.backgroundColor = bgcolorEvents[SpeechEventType.none.rawValue]
            plot.backgroundColor = UIColor(white: 0.0, alpha: 0.0)

            setupStats()
            progressBar.isHidden = false
            uiTimer = Timer.scheduledTimer(timeInterval: uiUpdateInterval, target: self, selector: #selector(ViewController.updateUI), userInfo: nil, repeats: true)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    func viewTapped(sender: UITapGestureRecognizer) {
        if (player?.isPlaying)! {
            
            currTime = (player?.playhead)!
            
            if currTime == 0 {
                currPan = 0
            }
            
            player?.stop()
            AudioKit.stop()
        }
        else {
            AudioKit.start()
            
            do {
                try player?.reloadFile()
            } catch { print("Errored reloading.") }
            
            // Continue from where we where marking in the timeline
            player!.play(from: currTime, to: 0, when: 0)
        }
    }
    
    func handlePan(sender: UIPanGestureRecognizer) {
        if(!switchRecord.isOn && ampArray.count > plotResolution && !player!.isPlaying){
            
            let dir = sender.velocity(in: self.view).x / 50000
            let newPan = currPan - Int((Float(dir) * Float(ampArray.count)))
            
            if newPan > ampArray.count - (plotResolution) - 1 {
                currPan = ampArray.count - (plotResolution) - 1
            }
            else if newPan < 0 {
                currPan = 0
            }
            else{
                currPan = newPan
            }

            currTime = Double((currPan) * (clockCounter) / (ampArray.count - plotResolution/2)) + (plotSampleRate/plotResolution)

        }
    }
    
    func triggerKeyboard(sender: UILongPressGestureRecognizer){
        if !statView.isHidden {
            speechNameTextField.isHidden = false
        }
        else{
            hideKeyboard()
        }
    }
    
    func dismissKeyboard(sender: UITapGestureRecognizer){
        hideKeyboard()
    }
   
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        DispatchQueue.global(qos: .background).async {
            self.backButton.isEnabled = false
            self.activityIndicator.startAnimating()
            self.saveSpeech(speechName: textField.text!)
            DispatchQueue.main.async {
                self.backButton.isEnabled = true
                self.activityIndicator.stopAnimating()
            }
        }
        hideKeyboard()
        textField.resignFirstResponder()
        return true
    }
    
    func hideKeyboard() {
        speechNameTextField.endEditing(true)
        speechNameTextField.isHidden = true
    }
    
    @IBAction func switchChanged(_ sender: UISwitch) {
        if(sender.isOn == true){
            currEvent = SpeechEventType.none

            if uiTimer.isValid {
                uiTimer.invalidate()
            }
            
            if plot != nil {
                plot.clear()
                plot.removeFromSuperview()
                AudioKit.stop()
            }
            
            // Clear prev data, if any
            audioArray.removeAll()
            patternHistogram.removeAll()
            patternEndTime.removeAll()
            patternStartTime.removeAll()
            ampArray.removeAll()
            freqHistogram = [Int](repeating: 0, count: histogramRange)
            eventArray.removeAll()
            scoreDataItems.removeAll()
            monotonyDataItems.removeAll()
            silenceDataItems.removeAll()
            eventOccurences[SpeechEventType.longPause.rawValue] = 0.0
            eventOccurences[SpeechEventType.monotony.rawValue] = 0.0
            eventOccurences[SpeechEventType.stutter.rawValue] = 0.0

            clockCounter = 0
            

            // Setup AudioKit
            AKAudioFile.cleanTempDirectory()
            AKSettings.bufferLength = .medium

            do {
                try AKSettings.setSession(category: .playAndRecord, with: .defaultToSpeaker)
            } catch { print("Errored setting category.") }
            
            // Setup audio kit for recording and plotting
            mic = AKMicrophone()
            let micMixer = AKMixer(mic)
            
            tracker = AKFrequencyTracker.init(micMixer)
            micBooster = AKBooster(tracker, gain:0)
            
            recorder = try? AKNodeRecorder(node: micMixer)
            player = try? AKAudioPlayer(file: (recorder?.audioFile)!)
            player?.completionHandler = finishedPlaying
            
            let mainMixer = AKMixer(player!,micBooster!)
            AudioKit.output = mainMixer
            AudioKit.start()
            setupPlot()
            
            do {
                try recorder?.record()
            } catch { print("Errored recording.") }


            // Setup Timers
            uiTimer = Timer.scheduledTimer(timeInterval: uiUpdateInterval, target: self, selector: #selector(ViewController.updateUI), userInfo: nil, repeats: true)
            
            sampleRateTimer = Timer.scheduledTimer(timeInterval: 1/plotSampleRate, target: self, selector: #selector(ViewController.updateAmpandFreqArrays), userInfo: nil, repeats: true)

            if enableMonotonyDetection {
                monotonyTimer = Timer.scheduledTimer(timeInterval: 1/monotonySampleRate, target: self, selector: #selector(ViewController.detectMonotony), userInfo: nil, repeats: true)
            }
            
            if enableLongPauseDetection {
                pauseTimer = Timer.scheduledTimer(timeInterval: pauseDetectionInterval, target: self, selector: #selector(ViewController.detectPause), userInfo: nil, repeats: true)
            }
            
            if enableStutterDetection {
                stutterInterval = Double(UserDefaults.standard.float(forKey: "SpeechSpeed") * 2)
                stutterCurrentSignalSize = stutterInterval
                stutterTotalSignalSize = stutterInterval * 2.0
                stutterTimer = Timer.scheduledTimer(timeInterval: stutterInterval, target: self, selector: #selector(ViewController.detectStutter), userInfo: nil, repeats: true)
            }

      }
      else{
            do {
                try player?.reloadFile()
            } catch { print("Errored reloading.") }
            
            let recordedDuration = player != nil ? player?.audioFile.duration  : 0
            if recordedDuration! > 0.0 {
                tape = player?.audioFile
                recorder?.stop()
                player?.audioFile.exportAsynchronously(name: "TempTestFile", baseDir: .temp, exportFormat: .m4a) {_, error in
                    if error != nil {
                        print("Export Failed \(error)")
                    } else {
                        print("Export succeeded")
                    }
                }
            }
            
            mic.stop()
            AudioKit.stop()

            // Invalidate timers
            if enableMonotonyDetection { monotonyTimer.invalidate() }
            if enableLongPauseDetection{ pauseTimer.invalidate()    }
            if enableStutterDetection  { stutterTimer.invalidate() }
            sampleRateTimer.invalidate()
            
            // Setup charts and stats
            setupStats()
            setupPlot()
            
            // Reset variables for next iteration
            dominantFreq = 1
            monotonyCycles = 0
            
            // Start offline processing
            if offlineProcessingType == 0 {
                self.progressBar.isHidden = false
                self.processingButton.isEnabled = false
                DispatchQueue.global(qos: .background).async {
                    self.findPatterns()
                    DispatchQueue.main.async {
                        self.processingButton.isEnabled = true
                        self.progressBar.progress = 1.0
                    }
                }
            }
            else if offlineProcessingType == 1 {
                self.progressBar.isHidden = false
                self.processingButton.isEnabled = false
                let previousStutterSampleRate = stutterSampleRate
                stutterSampleRate = Float(UserDefaults.standard.integer(forKey: "OfflineSampleRate"))
                DispatchQueue.global(qos: .background).async {
                    self.personalPatterns()
                    DispatchQueue.main.async {
                        self.processingButton.isEnabled = true
                        self.progressBar.progress = 1.0
                        self.stutterSampleRate = previousStutterSampleRate
                    }
                }
            }
            
        }
    }
    
    func setupPlot() {
        if switchRecord.isOn {
            plot = AKNodeOutputPlot(mic, frame: audioInputPlot.bounds)
            plot.plotType = .rolling
            plot.gain = 1
            plot.recordingSampleRate = UserDefaults.standard.double(forKey: "OfflineSampleRate")
            plot.backgroundColor = UIColor(white: 0.0, alpha: 0.0)
            audioInputPlot.backgroundColor = bgcolorEvents[SpeechEventType.none.rawValue]
            plot.shouldFill = true
            plot.shouldMirror = true
            plot.color = fgcolorEvents[SpeechEventType.none.rawValue]
            plot.setRollingHistoryLength(plot.rollingHistoryLength()/plotSpeed)
            audioInputPlot.addSubview(plot)
            audioInputPlot.sendSubview(toBack: plot)
            
            statView.isHidden = true
            timelineCursor.isHidden = true
            progressBar.isHidden = true
            
            plot.startRecording()
        }
        else {
            plot.stopRecording()
            // Put some cool touches on the moving plot
            for i in 0..<ampArray.count{
                if (i % 50 < 35 ){
                    ampArray[i] = 0
                }
            }
            
            let pad = [Float](repeating: 0.0, count: plotResolution/2)
            ampArray = pad + ampArray + pad
            let eventpad = [Int](repeating: SpeechEventType.none.rawValue, count: plotResolution/2)
            eventArray = eventpad + eventArray + eventpad
            
            currPan = ampArray.count < plotResolution ? 0: ampArray.count - plotResolution - 1
            plot.plotType = .buffer
            plot.color = fgcolorEvents[SpeechEventType.none.rawValue]
            audioInputPlot.backgroundColor = bgcolorEvents[SpeechEventType.none.rawValue]
            plot.backgroundColor = UIColor(white: 0.0, alpha: 0.0)
        }
    }
    
    func setupStats() {
        // Shrink plot
        plot.updatesEnabled = false
        plot.bounds = CGRect(x: 0, y: 0 , width: audioInputPlot.bounds.width, height: audioInputPlot.bounds.height*0.6)
        plot.transform = CGAffineTransform( translationX: 0.0, y: +(audioInputPlot.bounds.height*0.25) )

        plot.backgroundColor = UIColor(white: 0.0, alpha: 0.0)
        
        timelineCursor.isHidden = false
        audioInputPlot.bringSubview(toFront: timelineCursor)

        statView.isHidden = false
        audioInputPlot.bringSubview(toFront: statView)
        
        // Display and position charts
        let maxRadius = min(scoreChart.frame.width, scoreChart.frame.height) / 2
        scoreChart.innerRadius = CGFloat(maxRadius*0.5)
        scoreChart.outerRadius = CGFloat(maxRadius*0.8)
        scoreChart.selectedPieOffset = CGFloat(maxRadius*0.25)
        silenceChart.innerRadius = CGFloat(maxRadius*0.5)
        silenceChart.outerRadius = CGFloat(maxRadius*0.8)
        silenceChart.selectedPieOffset = CGFloat(maxRadius*0.25)
        monotonyChart.innerRadius = CGFloat(maxRadius*0.5)
        monotonyChart.outerRadius = CGFloat(maxRadius*0.8)
        monotonyChart.selectedPieOffset = CGFloat(maxRadius*0.25)

        let emptyChartColor = UIColor(red: 220/255.0, green: 220/255.0, blue: 220/255.0, alpha: 1)
        
        // Give it data
        percentSilent = CGFloat(eventOccurences[SpeechEventType.longPause.rawValue]! / clockCounter)
        silenceDataItems.append( PieChartItem(value: percentSilent, color: fgcolorEvents[SpeechEventType.longPause.rawValue]!, description: "Quite" ))
        silenceDataItems.append( PieChartItem(value: 1 - percentSilent, color: emptyChartColor, description: "" ))
        silenceDataLabel.text = "\(Int(percentSilent*100))" + "%"
        silenceChart.reloadData()
        
        
        percentMonotone = CGFloat(eventOccurences[SpeechEventType.monotony.rawValue]! / clockCounter)
        monotonyDataItems.append( PieChartItem(value: percentMonotone, color: fgcolorEvents[SpeechEventType.monotony.rawValue]!, description: "Monotone" ))
        monotonyDataItems.append( PieChartItem(value: 1 - percentMonotone, color: emptyChartColor, description: "" ))
        monotonyDataLabel.text = "\(Int(percentMonotone*100))" + "%"
        monotonyChart.reloadData()
        
        percentNeither = CGFloat(1.0 - percentSilent - percentMonotone)
        scoreDataItems.append( PieChartItem(value: percentNeither , color: fgcolorEvents[SpeechEventType.none.rawValue]!, description: "None"))
        scoreDataItems.append( PieChartItem(value: 1 - percentNeither , color: emptyChartColor, description: "" ))
        scoreDataLabel.text = "\(Int(percentNeither*100))" + "%"
        scoreChart.reloadData()
        

        timeDataLabel.text = String(format:"%02d", Int(clockCounter) / 60) + ":" + String(format:"%02d", Int(clockCounter) % 60)
        
        stutterDataLabel.text = "\(Int(eventOccurences[SpeechEventType.stutter.rawValue]!))"

    }    
    
    func updateUI() {
        if(switchRecord.isOn){

            // Adjust the timer
            clockCounter += uiUpdateInterval
            timeEventLabel.text = String(format:"%02d", Int(clockCounter) / 60) + ":" + String(format:"%02d", Int(clockCounter) % 60)
            
            // Check for delay in display
            if(eventDisplayDelay > 0)
            {
                eventDisplayDelay -= uiUpdateInterval
                return
            }
            
            
            // Check if a speech event occured and change UI accordingly
            for event in priorityEvents {
                if detectedEvent[event]! {
                    currEvent = SpeechEventType(rawValue: event)
                    eventDisplayDelay += displayDelay[event]!
                    break
                }
            }
            
            audioInputPlot.backgroundColor = bgcolorEvents[currEvent.rawValue]
            plot.color = fgcolorEvents[currEvent.rawValue]
            speechEventLabel.text = textEvents[currEvent.rawValue]
            speechEventLabel.textColor = fgcolorEvents[currEvent.rawValue]
            timeEventLabel.textColor = fgcolorEvents[currEvent.rawValue]
    
        }
        else {
            
            if player!.isPlaying {
                // Update time and shift the pan too
                currTime = (player?.playhead)! - (plotSampleRate/plotResolution)
                
                if currTime < 0 {
                    currTime = 0
                }
                
                
                currPan = Int(currTime * (ampArray.count - plotResolution/2) / clockCounter)
                
                if currPan > ampArray.count - (plotResolution) - 1 {
                    currPan = ampArray.count - (plotResolution) - 1
                }
                if currPan < 0 {
                    currPan = 0
                }

            }
            
            plot.updateBuffer(&(ampArray[currPan]), withBufferSize:UInt32(plotResolution))

            let displayTime = Double((currPan + plotResolution/2) * (clockCounter) / (ampArray.count - plotResolution/2))
            
            // Change plot and UI elements color depending on speech events
            audioInputPlot.backgroundColor = bgcolorEvents[eventArray[currPan+(plotResolution/2)]]
            plot.backgroundColor = UIColor(white: 0.0, alpha: 0.0)
            plot.color = fgcolorEvents[eventArray[currPan+(plotResolution/2)]]
            speechEventLabel.text = textEvents[eventArray[currPan+(plotResolution/2)]]
            speechEventLabel.textColor = fgcolorEvents[eventArray[currPan+(plotResolution/2)]]
            
            timeEventLabel.text = String(format:"%02d",Int(displayTime)/60) + ":" + String(format:"%02d",Int(displayTime)%60)
            timeEventLabel.textColor = fgcolorEvents[eventArray[currPan+(plotResolution/2)]]
            
        }
    }
    
    func finishedPlaying(){
        AudioKit.stop()
    }
    
    func updateAmpandFreqArrays(){
        ampArray.append(Float(tracker.amplitude))
        eventArray.append(currEvent.rawValue)
    }
    
    func detectPause() {
        // Check if we're quite in this cycle
        if tracker.amplitude < pauseThreshold {
            pauseCounter += pauseDetectionInterval
            
            // If we've been quite long enough, update stats and detectedEvent array
            if(pauseCounter >= eventDuration[SpeechEventType.longPause.rawValue]!){
                eventOccurences[SpeechEventType.longPause.rawValue]! += detectedEvent[SpeechEventType.longPause.rawValue]! ? pauseDetectionInterval:eventDuration[SpeechEventType.longPause.rawValue]!

                detectedEvent[SpeechEventType.longPause.rawValue] = true
            }
            else{
                detectedEvent[SpeechEventType.longPause.rawValue] = false
            }
        }
        else{
            pauseCounter = 0
            detectedEvent[SpeechEventType.longPause.rawValue] = false
        }
    }
    
    func detectMonotony() {
        // Don't collect samples if silent
        if tracker.amplitude < pauseThreshold {
            return
        }
        
        // Update histogram with current frequency
        let currFreq = Int(tracker.frequency)/monotonyScale
        if(currFreq < histogramRange) {
            freqHistogram[currFreq] += 1
            histogramSize += 1
            
            if repeatedFreqCount < freqHistogram[currFreq] {
                repeatedFreqCount = freqHistogram[currFreq]
                repeatedFreq = currFreq
            }
        }
        
        // If complete, do comparisons with prev iteration
        if histogramSize == Int(monotonyWindowSize*monotonySampleRate) {

            if abs(repeatedFreq - dominantFreq) < monotonyThresholdDiff {
                monotonyCycles += monotonyWindowSize
            }
            else {
                monotonyCycles = 0
            }

            // If we've been monotonous long enough, record it in stats and update detectedEvent array
            if monotonyCycles >= eventDuration[SpeechEventType.monotony.rawValue]! {
                eventOccurences[SpeechEventType.monotony.rawValue]! += detectedEvent[SpeechEventType.monotony.rawValue]! ? monotonyWindowSize:eventDuration[SpeechEventType.monotony.rawValue]!
                
                detectedEvent[SpeechEventType.monotony.rawValue] = true
            }
            else{
                detectedEvent[SpeechEventType.monotony.rawValue] = false
            }
            
            dominantFreq = repeatedFreq

            // Reset variables
            histogramSize = 0
            freqHistogram = [Int](repeating: 0, count: histogramRange)
            repeatedFreqCount = 1   // avoid singletons
            repeatedFreq = dominantFreq + monotonyThresholdDiff + 1
        }
    }

    func detectStutter(){
        if plot.FloatChannelData.count < Int(stutterTotalSignalSize * stutterSampleRate) {
            return
        }
        
        // Get x and y signals
        let startIndex = plot.FloatChannelData.count - Int(stutterTotalSignalSize * stutterSampleRate)
        var xSignal = [Float](repeating: 0, count: Int(stutterCurrentSignalSize * stutterSampleRate))
        var ySignal = [Float](repeating: 0, count: Int((stutterTotalSignalSize - stutterCurrentSignalSize) * stutterSampleRate))

        for i in 0..<xSignal.count{
            xSignal[i] = plot.FloatChannelData[startIndex + ySignal.count + i]
        }
        for i in 0..<ySignal.count{
            ySignal[i] = plot.FloatChannelData[startIndex + i]
        }
        
        // Get the sum of squares of x and y
        var normX: Float = 0
        for x in xSignal { normX += x*x }
        
        
        var normY: Float = 0
        let xPadSize = ySignal.count - xSignal.count
        // Pad the signals
        if signalPaddingEnabled {
            let xPad = repeatElement(Float(0.0), count: ySignal.count - xSignal.count)
            xSignal += xPad
            
            let yPad = repeatElement(Float(0.0), count: xSignal.count)
            ySignal = yPad + ySignal + yPad
        }
        else{
            // If the signal is padded, the norm is initially 0. Otherwise, the norm is calculated normally
            for i in 0..<xSignal.count { normY += ySignal[i] * ySignal[i] }
        }

        // Correlate the signals
        let resultSize = ySignal.count - xSignal.count - 1
        var result = [Float](repeating: 0, count: resultSize)
        vDSP_conv(ySignal, 1, xSignal, 1, &result, 1, vDSP_Length(resultSize), vDSP_Length(xSignal.count))
        
        // Go through the result
        detectedEvent[SpeechEventType.stutter.rawValue] = false
        var skipCount = 0
        for j in 0..<result.count{
            // We skipped this
            skipCount -= 1
            
            // Are we still skipping?
            if skipCount <= 0{
                let currPt = abs(result[j] / sqrtf(normY*normX))
                if currPt > stutterThreshold  && currPt < 1{
                    
                    detectedEvent[SpeechEventType.stutter.rawValue] = true
                    eventOccurences[SpeechEventType.stutter.rawValue]! += eventDuration[SpeechEventType.stutter.rawValue]!
                    // Skip rest of signal to void duplicate occurences.
                    skipCount = xSignal.count - xPadSize
                }
            }
            
            normY -= ySignal[j]*ySignal[j]
            normY += ySignal[j+xSignal.count]*ySignal[j+xSignal.count]
        }

        
    }
    
    /**
     *   MARK: ARPieChartDataSource
     */
    func numberOfSlicesInPieChart(_ pieChart: ARPieChart) -> Int {
        if (pieChart == scoreChart){
            return scoreDataItems.count
        }
        else if pieChart == monotonyChart {
            return monotonyDataItems.count
        }
        else if pieChart == silenceChart {
            return silenceDataItems.count
        }
        return 0
    }
    
    func pieChart(_ pieChart: ARPieChart, valueForSliceAtIndex index: Int) -> CGFloat {
        if (pieChart == scoreChart){
            let item: PieChartItem = scoreDataItems[index]
            return item.value
        }
        else if pieChart == monotonyChart {
            let item: PieChartItem = monotonyDataItems[index]
            return item.value
        }
        else if pieChart == silenceChart {
            let item: PieChartItem = silenceDataItems[index]
            return item.value
        }
        return 0.0
    }
    
    func pieChart(_ pieChart: ARPieChart, colorForSliceAtIndex index: Int) -> UIColor {
        if (pieChart == scoreChart){
            let item: PieChartItem = scoreDataItems[index]
            return item.color
        }
        else if pieChart == monotonyChart {
            let item: PieChartItem = monotonyDataItems[index]
            return item.color
        }
        else if pieChart == silenceChart {
            let item: PieChartItem = silenceDataItems[index]
            return item.color
        }
        return UIColor.clear
    }
    
    func pieChart(_ pieChart: ARPieChart, descriptionForSliceAtIndex index: Int) -> String {
        if (pieChart == scoreChart){
            let item: PieChartItem = scoreDataItems[index]
            return item.description ?? ""
        }
        else if pieChart == monotonyChart {
            let item: PieChartItem = monotonyDataItems[index]
            return item.description ?? ""
        }
        else if pieChart == silenceChart {
            let item: PieChartItem = silenceDataItems[index]
            return item.description ?? ""
        }
        return ""
    }
    /**
     *  MARK: ARPieChartDelegate
     */
    func pieChart(_ pieChart: ARPieChart, itemSelectedAtIndex index: Int) {
    }
    
    func pieChart(_ pieChart: ARPieChart, itemDeselectedAtIndex index: Int) {
    }
    
    func saveSpeech(speechName: String) {
        activityIndicator.startAnimating()
        backButton.isEnabled = false
        switchRecord.isEnabled = false
        let directories = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        
        if let documents = directories.first {
            if let urlDocuments = NSURL(string: documents) {
                let urlSpeechWave = urlDocuments.appendingPathComponent(speechName + "wave.plist")
                let urlSpeechEvent = urlDocuments.appendingPathComponent(speechName + "event.plist")
                let urlSpeechStats = urlDocuments.appendingPathComponent(speechName + "stats.plist")
                
                // Write Array to Disk
                let wave = ampArray as NSArray
                let event = eventArray as NSArray
                let stats = [percentNeither,percentMonotone,percentSilent,eventOccurences[SpeechEventType.stutter.rawValue]!,clockCounter,Date().timeIntervalSince1970] as NSArray

                
                if(event.write(toFile: (urlSpeechEvent?.path)!, atomically: true)){
                    if(wave.write(toFile: (urlSpeechWave?.path)!, atomically: true)){
                        if(stats.write(toFile: (urlSpeechStats?.path)!, atomically: true)){
                            activityIndicator.stopAnimating()
                            backButton.isEnabled = true
                            switchRecord.isEnabled = true
                        }
                    }
                }

                
                let audioFile = recorder?.audioFile
                let sourcepath = URL(fileURLWithPath: (audioFile?.url.absoluteString)!)
                let destinationpath = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(speechName + ".caf")
                
                do {
                    try FileManager().copyItem(at: sourcepath, to: destinationpath)
                }
                catch let error as NSError {
                    print("Failed to copy file into Documents directory: \(error)")
                }
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        AudioKit.stop()
        
        guard let histSessionViewController = segue.destination as? histogramTableViewController else {
            return
        }
        
        if offlineProcessingType == 0 {
            // Find the highest elements in the histogram
            var boolHistogram = [Bool](repeating: true, count:patternHistogram.count)
            for _ in 0..<patternHistogram.count{
                var max = -1
                var maxIndex = -1
                for j in 0..<patternHistogram.count{
                    if patternHistogram[j] > max && boolHistogram[j] {
                        max = patternHistogram[j]
                        maxIndex = j
                    }
                }
                highestIDs.append(maxIndex)
                boolHistogram[maxIndex] = false
                if highestIDs.count >= numPatterns{ break }
            }
            
            // Check how many patterns are there
            var actualPatterns: Int = 0
            for numP in 0..<highestIDs.count{
                if patternHistogram[highestIDs[numP]] > 1{
                    actualPatterns += 1
                }
            }
            histSessionViewController.numPatterns = actualPatterns
            histSessionViewController.patterns = false
        }
        else {
            histSessionViewController.numPatterns = patternArray.count
            histSessionViewController.patternArray = patternArray
            histSessionViewController.patternNames = patternNames
            print("Before segue",patternNames,patternArray.count)
            histSessionViewController.patterns = true
        }
        
        
        histSessionViewController.highestIDs = self.highestIDs
        histSessionViewController.player = self.player
        histSessionViewController.clockCounter = self.clockCounter
        histSessionViewController.plotResolution = self.plotResolution
        histSessionViewController.patternHistogram = self.patternHistogram
        histSessionViewController.patternStartTime = self.patternStartTime
        histSessionViewController.patternEndtime = self.patternEndTime
        histSessionViewController.ampArray = self.ampArray
        histSessionViewController.eventArray = self.eventArray
        histSessionViewController.percentMonotone = self.eventOccurences[SpeechEventType.monotony.rawValue]!
        histSessionViewController.percentSilent = self.eventOccurences[SpeechEventType.longPause.rawValue]!
        histSessionViewController.numStutters = self.eventOccurences[SpeechEventType.stutter.rawValue]!
        histSessionViewController.recorder = self.recorder
    }

    func findPatterns(){
        print("Started processing")
        let startingTime = Date().timeIntervalSince1970
        getAudioArray()
        
        // Current number of patterns found
        var patternID: Int = 0
        // Calculate max word length
        let minLength = Int(stutterCurrentSignalSize / clockCounter * audioArray.count) * 10// 650-1000-1600 ms depending on speaker speed
        let maxLength = Int(minLength * 1.5)  // upto 3 seconds for slow speakers and 1.3 secs for fast
        let sizeGain = Int(minLength * 0.5) // No size gains
        let signalOffset = maxLength   // jump by max length
        
        // Start Loop here over all signal by changing startIndex
        var startIndex = 0
        while startIndex <= audioArray.count - minLength - 1 {
            
            // Get initial x and y signals
            var xSignal = [Float](repeating: 0, count: minLength)
            for i in 0..<xSignal.count {
                xSignal[i] = audioArray[startIndex + i]
            }
            var ySignal = [Float](repeating: 0, count: audioArray.count - (startIndex + minLength))
            for i in 0..<ySignal.count {
                ySignal[i] = audioArray[startIndex + minLength + i]
            }
            
            if ySignal.count < xSignal.count{ break; }
            
            // Get norm of both signals initially. Y's norm is calculated internally cause it's shifting
            var normX: Float = 0
            for x in xSignal { normX += x*x }
            var normY: Float = 0
            
            // Pad x and y
            let xPad = repeatElement(Float(0.0), count: ySignal.count - xSignal.count)
            xSignal += xPad
            let yPad = repeatElement(Float(0.0), count: xSignal.count)
            ySignal = yPad + ySignal + yPad
            
            // Keep track of padding size cause it'll change
            var xPadSize = xPad.count
            var yPadSize = yPad.count
            
            // Start inner loop here over this portion by changing length
            var currLength = minLength

            // Start calculating and, upon completion, change the sizes here and adjust the norms accordingly
            while currLength <= maxLength && currLength + startIndex < audioArray.count && xPadSize > 0 && xSignal.count > sizeGain{
                
                // Calculate start and end times
                patternStartTime.append(Double(startIndex)/audioArray.count * clockCounter)
                patternEndTime.append(Double(startIndex+currLength)/audioArray.count * clockCounter)
                patternHistogram.append(1)

                // Calculate norm of Y
                for i in 0..<xPadSize{ normY += ySignal[i]*ySignal[i] }

                // Correlate the signals
                let resultSize = ySignal.count - xSignal.count - 1
                var result = [Float](repeating: 0, count: resultSize)
                vDSP_conv(ySignal, 1, xSignal, 1, &result, 1, vDSP_Length(resultSize), vDSP_Length(xSignal.count))
                
                // Use this offset to skip things, for speed
                let correlationOffset = 1
                
                // Go through the result, skip the zeros made by the xPad
                var i = xPadSize
                while i + correlationOffset < result.count{
                    // Check for correlation
                    let currPt = abs(result[i] / sqrtf(normY*normX))
                    if currPt > stutterThreshold && currPt < 1{

                        // Add to histogram
                        patternHistogram[patternID] += 1
                        
                        // Skip rest of signal to void duplicate occurences. Update normY too.
                        let oldI = i
                        i += xSignal.count - xPadSize
                        if i >= result.count { break }
                        for j in oldI..<i{
                            normY -= ySignal[j]*ySignal[j]
                            normY += ySignal[j+xSignal.count]*ySignal[j+xSignal.count]
                        }
                        continue
                    }

                    // Update norm of Y as we skip by an offset (for speed)
                    for j in i..<i+correlationOffset {
                        normY -= ySignal[j]*ySignal[j]
                        normY += ySignal[j+xSignal.count]*ySignal[j+xSignal.count]
                    }
                    i += correlationOffset
                }
                
                // Insert sizeGain elements from beggining of ySignal to end of xSignal
                xSignal.insert(contentsOf: ySignal[yPadSize..<yPadSize+sizeGain], at: xSignal.count - xPadSize)
                // Reduce the xPadding by the twice the added size (this is because we'll also remove those elements from y)
                xSignal.removeLast(2*sizeGain)
                xPadSize -= 2*sizeGain
                
                // Update norm of x with beginning of ySignal (not the padding)
                for i in 0..<sizeGain{ normX += ySignal[i+yPadSize] }

                // Remove sizeGain elements from beginning of ySignal and increase the beginning of the padding. Increase padding in the end too
                ySignal.removeSubrange(yPadSize..<yPadSize+sizeGain)
                ySignal.removeFirst(sizeGain)
                ySignal.removeLast(sizeGain)
                yPadSize -= sizeGain
                normY = 0
                
                currLength += sizeGain
                patternID += 1
            }
            startIndex += signalOffset
            DispatchQueue.main.async {
                self.progressBar.progress = Float(startIndex) / Float(self.audioArray.count)
            }
        }

        let endingTime = Date().timeIntervalSince1970

        // Eliminate smaller signals if larger ones are found BUGGY CODE FIX
//        let strides: Int = (maxLength - minLength)/sizeGain
//        if strides > 1{
//            var i = 0
//            while i+strides < patternHistogram.count {
//                for j in 0..<strides{
//                    if patternHistogram[i + strides - j] > 1{
//                        for k in (j+1)..<strides{
//                            patternHistogram[i + strides - k] = 0
//                        }
//                        break
//                    }
//                }
//                i += strides
//            }
//        }
        
        // Find the highest elements in the histogram
        var boolHistogram = [Bool](repeating: true, count:patternHistogram.count)
        for _ in 0..<patternHistogram.count{
            var max = -1
            var maxIndex = -1
            for j in 0..<patternHistogram.count{
                if patternHistogram[j] > max && boolHistogram[j] {
                    max = patternHistogram[j]
                    maxIndex = j
                }
            }
            highestIDs.append(maxIndex)
            boolHistogram[maxIndex] = false
            if highestIDs.count >= numPatterns{ break }
        }
        print("Finished processing in \(endingTime-startingTime)")
    }
    
    func personalPatterns() {
        var startTime = Date().timeIntervalSince1970
        if patternArray.count == 0 {
            loadPatterns()
        }

        print("loaded patterns in \(Date().timeIntervalSince1970 - startTime)")
        startTime = Date().timeIntervalSince1970
        getAudioArray()
        
        let offlineThreshold: Float = 0.1 // 0.23 if you're lenient
        print("Got audio array in \(Date().timeIntervalSince1970 - startTime)")
        startTime = Date().timeIntervalSince1970

        for i in 0..<patternArray.count{

            // Calculate start and end times
            patternStartTime.append(0)
            patternEndTime.append(0)
            patternHistogram.append(0)

            // Get x and y signals
            var xSignal = patternArray[i].audioArray
            var ySignal = audioArray
            // ySignal is audioArray
            
            if xSignal.count == 0 || ySignal.count == 0 {
                print("Stopped\n\n\n\n\n")
                return
            }
            print(i,xSignal.count,ySignal.count)
            
            // Get the sum of squares of x and y
            var normX: Float = 0
            for x in xSignal { normX += x*x }
            
            var normY: Float = 0
            
            let xPadSize = ySignal.count - xSignal.count
            if xPadSize < 0{
                return
            }

            // Pad the signals
            if signalPaddingEnabled {
                let xPad = repeatElement(Float(0.0), count: xPadSize)
                xSignal += xPad
                
                let yPad = repeatElement(Float(0.0), count: xSignal.count)
                ySignal = yPad + ySignal + yPad
            }
            else{
                // If the signal is padded, the norm is initially 0. Otherwise, the norm is calculated normally
                for i in 0..<xSignal.count { normY += ySignal[i] * ySignal[i] }
            }
            
            // Correlate the signals
            let resultSize = ySignal.count - xSignal.count - 1
            var result = [Float](repeating: 0, count: resultSize)
            vDSP_conv(ySignal, 1, xSignal, 1, &result, 1, vDSP_Length(resultSize), vDSP_Length(xSignal.count))


            // Go through the result
            var skipCount = 0
            for j in 0..<result.count{
                // We skipped this
                skipCount -= 1
                
                // Are we still skipping?
                if skipCount <= 0{
                    let currPt = abs(result[j] / sqrtf(normY*normX))
                    if currPt > offlineThreshold && currPt < 1{
                        if patternHistogram.count == 0 { break }
                        patternHistogram[i] += 1
                        // Skip rest of signal to void duplicate occurences.
                        skipCount = xSignal.count - xPadSize
                    }
                }
                
                normY -= ySignal[j]*ySignal[j]
                normY += ySignal[j+xSignal.count]*ySignal[j+xSignal.count]
            }
            print(i,"Finished a lap in \(Date().timeIntervalSince1970 - startTime)")
            startTime = Date().timeIntervalSince1970

            DispatchQueue.main.async {
                self.progressBar.progress = Float(i + 1) / Float(self.patternArray.count)
            }
            if switchRecord.isOn{
                print("Stopped\n\n\n\n\n")
                return
            }
        }
    }
    
    func getAudioArray() {
        audioArray = plot.FloatChannelData
    }
    
    func loadPatterns() {
        let documentsUrl =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            // Get the directory contents urls (including subfolders urls)
            let directoryContents = try FileManager.default.contentsOfDirectory(at: documentsUrl, includingPropertiesForKeys: nil, options: [])
            
            
            let myFiles = directoryContents.filter{ $0.path.contains("StutterSampleAudio.plist") }
            patternNames = myFiles.map{ $0.deletingPathExtension().lastPathComponent }
            
            for i in 0..<patternNames.count{
                patternNames[i] = patternNames[i].substring(to: patternNames[i].index(patternNames[i].endIndex, offsetBy: -18))
            }
            
            print("File list:", patternNames)
            
            for name in patternNames{
                let loadedWave = NSArray(contentsOf: FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(name + "StutterSampleAudio.plist")) as! [Float]
                let loadedPlot = NSArray(contentsOf: FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(name + "StutterSampleAmp.plist")) as! [Float]
                do{
                    tape = try AKAudioFile(forReading: FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(name + "StutterSample.caf"))
                } catch {print("Error")}

                // I could construct my own wave here
                patternArray.append(Pattern(audioArray: loadedWave, ampArray: loadedPlot, tape: tape))
            }
            
        } catch let error as NSError {
            print("A7a")
        }
    }

    
}
