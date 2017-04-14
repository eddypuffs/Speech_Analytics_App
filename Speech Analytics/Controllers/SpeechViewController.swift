//
//  SpeechViewController.swift
//  Speech Analytics
//
//  Created by Abdo Salem on 2/20/17.
//  Copyright © 2017 Abdo Salem. All rights reserved.
//

import UIKit
import AudioKit
import os.log

class SpeechViewController: UIViewController, EZMicrophoneDelegate, ARPieChartDelegate, ARPieChartDataSource {
    
    // Audio Elements
    var mic: AKMicrophone!
    var tracker: AKFrequencyTracker!
    var micBooster: AKBooster!
    var plot: AKNodeOutputPlot!
    var recorder: AKNodeRecorder?
    var player: AKAudioPlayer?
    var delay: AKDelay?
    


    // UI Elements
    @IBOutlet weak var audioInputPlot: EZAudioPlot!
    @IBOutlet var switchRecord: UISwitch!
    @IBOutlet var speechEventLabel: UILabel!
    @IBOutlet var timeEventLabel: UILabel!
    var uiTimer: Timer = Timer()
    let uiUpdateInterval: TimeInterval = 0.01 // 10 ms
    
    // UI Features
    var clockCounter: Double = 0
    var eventDisplayDelay: Double = 0
    
    // Options
    let enableMonotonyDetection = true
    let enableStutterDetection = true
    let enableLongPauseDetection = true
    
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
    var stutterSignalSize = 0.180
    let stutterSampleRate: Float = 2000 // 2 KHz
    let stutterThreshold: Float = 0.70
    var stutterTimer: Timer = Timer()
    let signalPaddingEnabled = true
    
    // Moving timeline (after recording is done)
    let panRec = UIPanGestureRecognizer()
    let tapRec = UITapGestureRecognizer()
    var currPan: Int = 0
    var currTime: Double = 0
    var sampleRateTimer: Timer = Timer()
    let plotResolution: Int = 4000
    let plotSampleRate: TimeInterval = 2000
    let plotSpeed: Int32 = 4
    var ampArray: [Float] = [] // used to fill the plot later. Also for long pause detection
    
    // Audio Signal Data
    let audioTotalStoredSignalSize = 1
    var audioRingBuff: RingBuffer<Float>! // store upto 680 ms of the signal at once time
    var currBuffIndex: Int = 0
    let buffSize: Int = 1024 // this is a constant in AKNodeOutputPlot
    var audioTimer: Timer = Timer()
    let audioSampleRate: TimeInterval = 0.02321995465 // Time it takes to renew the buffer with 1024 samples at 44 KHz
    
    // Speech Session Object: Needed for saving data and stats
    

    //We create a new session to be saved
    var currentSession: SpeechSession = SpeechSession(name: "NEW SPEECH", audioFilePath: "/PATH/TO/AUDIO/FILE")!
    
    // Speech Events
    var currEvent: SpeechEventType!
    var eventArray: [SpeechEventType] = []

    let bgcolorEvents: [SpeechEventType: UIColor] = [SpeechEventType.none: ColorPresets.White,
                                                     SpeechEventType.stutter: ColorPresets.White,
                                                     SpeechEventType.monotony:ColorPresets.White,
                                                     SpeechEventType.longPause:ColorPresets.White]
    
    let fgcolorEvents: [SpeechEventType: UIColor] = [SpeechEventType.none: ColorPresets.Orange,
                                                     SpeechEventType.stutter: ColorPresets.Purple,
                                                     SpeechEventType.monotony: ColorPresets.Red,
                                                     SpeechEventType.longPause: ColorPresets.Blue]


    var detectedEvent: [SpeechEventType:Bool] = [SpeechEventType.none:true,
                                                 SpeechEventType.stutter:false,
                                                 SpeechEventType.monotony:false,
                                                 SpeechEventType.longPause:false]
    
    
    // Stats
    var eventOccurences: [SpeechEventType: Double] = [SpeechEventType.stutter:0,
                                                      SpeechEventType.longPause:0,
                                                      SpeechEventType.monotony:0]
    var scoreDataItems: [PieChartItem] = []
    var silenceDataItems: [PieChartItem] = []
    var monotonyDataItems: [PieChartItem] = []
    
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
        let speechSpeed = UserDefaults.standard.double(forKey: "SpeechSpeed")
        
        if speechSpeed == 2.0 {
            stutterSignalSize = 0.065
        }
        else if speechSpeed == 0.0 {
            stutterSignalSize = 0.160
        }
        else {
            stutterSignalSize = 0.105
        }
        
        // Add panning gesture recognizer
        panRec.addTarget(self, action: #selector(SpeechViewController.handlePan))
        self.view.addGestureRecognizer(panRec)
        tapRec.numberOfTapsRequired = 2
        tapRec.addTarget(self, action: #selector(SpeechViewController.viewTapped))
        self.view.addGestureRecognizer(tapRec)
        
        
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
            
            currTime = Double((currPan) * (clockCounter) / (ampArray.count - plotResolution/2)) //+ (plotSampleRate/plotResolution) introduce a 0.5 second delay so that voice matches plot. It scrolls back to make up for the plotResolution/2 thing.
            
        }
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
            ampArray.removeAll()
            audioRingBuff = RingBuffer<Float>(count: Int(audioTotalStoredSignalSize*stutterSampleRate))
            freqHistogram = [Int](repeating: 0, count: histogramRange)
            eventArray.removeAll()
            scoreDataItems.removeAll()
            monotonyDataItems.removeAll()
            silenceDataItems.removeAll()
            eventOccurences[SpeechEventType.longPause] = 0.0
            eventOccurences[SpeechEventType.monotony] = 0.0
            eventOccurences[SpeechEventType.stutter] = 0.0
            
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
            uiTimer = Timer.scheduledTimer(timeInterval: uiUpdateInterval, target: self, selector: #selector(SpeechViewController.updateUI), userInfo: nil, repeats: true)
            
            sampleRateTimer = Timer.scheduledTimer(timeInterval: 1/plotSampleRate, target: self, selector: #selector(SpeechViewController.updateAmpandFreqArrays), userInfo: nil, repeats: true)
            
            if enableMonotonyDetection {
                monotonyTimer = Timer.scheduledTimer(timeInterval: 1/monotonySampleRate, target: self, selector: #selector(SpeechViewController.detectMonotony), userInfo: nil, repeats: true)
            }
            
            if enableLongPauseDetection {
                pauseTimer = Timer.scheduledTimer(timeInterval: pauseDetectionInterval, target: self, selector: #selector(SpeechViewController.detectPause), userInfo: nil, repeats: true)
            }
            
            if enableStutterDetection {
                audioTimer = Timer.scheduledTimer(timeInterval: audioSampleRate, target: self, selector: #selector(SpeechViewController.updateAudioArray), userInfo: nil, repeats: true)
            }
            
        }
        else{
            do { try player?.reloadFile() }
            catch { print("Errored reloading.") }
            
            let recordedDuration = (player != nil) ? player?.audioFile.duration  : 0
            if recordedDuration! > 0.0 {
                recorder?.stop()
                
                /*
                player?.audioFile.exportAsynchronously(name: "TempTestFile.m4a", baseDir: .documents, exportFormat: .m4a) {_, error in
                    if error != nil {
                        print("Export Failed \(error)")
                    } else {
                        print("Export succeeded")
                    }
                }
                */
            }
        
            mic.stop()
            AudioKit.stop()
            
            // Invalidate timers
            if enableMonotonyDetection { monotonyTimer.invalidate() }
            if enableLongPauseDetection{ pauseTimer.invalidate()    }
            if enableStutterDetection  { stutterTimer.invalidate()
                audioTimer.invalidate()    }
            sampleRateTimer.invalidate()
            
            // Setup charts and stats
            setupStats()
            setupPlot()
            
            // Reset variables for next iteration
            dominantFreq = 1
            monotonyCycles = 0
            
            
            //ADDED
            
            //Present prompt for saving
            let ac = UIAlertController(title: "Enter name for speech:", message: nil, preferredStyle: .alert)
            ac.addTextField()
            
            let submitAction = UIAlertAction(title: "Submit", style: .default) { [unowned ac] _ in
                let speechname = ac.textFields![0].text
                let audiofilename = speechname!.appending(".caf")
                self.saveSession(sessionName: speechname! , audioFileName: audiofilename)
                //Switch to different screen
                self.goToPlaybackView()

            }
            ac.addAction(submitAction)
            present(ac, animated: true)
            
            //ENDADDED
        }
    }
    
    func setupPlot() {
        if switchRecord.isOn {
            plot = AKNodeOutputPlot(mic, frame: audioInputPlot.bounds)
            plot.plotType = .rolling
            plot.gain = 1
            plot.backgroundColor = UIColor(white: 0.0, alpha: 0.0)
            audioInputPlot.backgroundColor = bgcolorEvents[SpeechEventType.none]
            plot.shouldFill = true
            plot.shouldMirror = true
            plot.color = fgcolorEvents[SpeechEventType.none]
            plot.setRollingHistoryLength(plot.rollingHistoryLength()/plotSpeed)
            audioInputPlot.addSubview(plot)
            audioInputPlot.sendSubview(toBack: plot)
            
            statView.isHidden = true
            timelineCursor.isHidden = true
        }
        else {
            let pad = [Float](repeating: 0.0, count: plotResolution/2)
            ampArray = pad + ampArray + pad
            let eventpad = [SpeechEventType](repeating: SpeechEventType.none, count: plotResolution/2)
            eventArray = eventpad + eventArray + eventpad
            
            currPan = ampArray.count < plotResolution ? 0: ampArray.count - plotResolution - 1
            plot.plotType = .buffer
            plot.color = fgcolorEvents[SpeechEventType.none]
            audioInputPlot.backgroundColor = bgcolorEvents[SpeechEventType.none]
            plot.backgroundColor = UIColor(white: 0.0, alpha: 0.0)
        }
    }
    
    func setupStats() {
        // Shrink plot
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
        let percentSilent = CGFloat(eventOccurences[SpeechEventType.longPause]! / clockCounter)
        silenceDataItems.append( PieChartItem(value: percentSilent, color: fgcolorEvents[SpeechEventType.longPause]!, description: "Quite" ))
        silenceDataItems.append( PieChartItem(value: 1 - percentSilent, color: emptyChartColor, description: "" ))
        silenceDataLabel.text = "\(Int(percentSilent*100))" + "%"
        silenceChart.reloadData()
        
        
        let percentMonotone = CGFloat(eventOccurences[SpeechEventType.monotony]! / clockCounter)
        monotonyDataItems.append( PieChartItem(value: percentMonotone, color: fgcolorEvents[SpeechEventType.monotony]!, description: "Monotone" ))
        monotonyDataItems.append( PieChartItem(value: 1 - percentMonotone, color: emptyChartColor, description: "" ))
        monotonyDataLabel.text = "\(Int(percentMonotone*100))" + "%"
        monotonyChart.reloadData()
        
        let percentNeither = CGFloat(1.0 - percentSilent - percentMonotone)
        scoreDataItems.append( PieChartItem(value: percentNeither , color: fgcolorEvents[SpeechEventType.none]!, description: "None"))
        scoreDataItems.append( PieChartItem(value: 1 - percentNeither , color: emptyChartColor, description: "" ))
        scoreDataLabel.text = "\(Int(percentNeither*100))" + "%"
        scoreChart.reloadData()
        

        timeDataLabel.text = String(format:"%02d", Int(clockCounter) / 60) + ":" + String(format:"%02d", Int(clockCounter) % 60)
        
        stutterDataLabel.text = "\(Int(eventOccurences[SpeechEventType.stutter]!))"

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
            for event in EventGlobals.priorityEvents {
                if detectedEvent[event]! {
                    currEvent = event
                    eventDisplayDelay += EventGlobals.displayDelay[event]!
                    break
                }
            }
            
            audioInputPlot.backgroundColor = bgcolorEvents[currEvent]
            plot.color = fgcolorEvents[currEvent]
            speechEventLabel.text = EventGlobals.textEvents[currEvent]
            speechEventLabel.textColor = fgcolorEvents[currEvent]
            timeEventLabel.textColor = fgcolorEvents[currEvent]
    
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
            speechEventLabel.text = EventGlobals.textEvents[eventArray[currPan+(plotResolution/2)]]
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
        eventArray.append(currEvent)
    }
    
    func updateAudioArray() {
        if( plot.audioSignal?[0] != nil) {
            
            let numElements = Int((stutterSampleRate/AKSettings.sampleRate)*buffSize)
            let strideSize = Int(buffSize/numElements)
            
            for i in 0..<numElements {
                audioRingBuff.write(element: plot.audioSignal?[i*strideSize] ?? 0)
            }
        }
        
        if audioRingBuff.isFull && !stutterTimer.isValid {
            detectStutter()
            stutterTimer = Timer.scheduledTimer(timeInterval: (stutterSignalSize * AKSettings.sampleRate * audioSampleRate / buffSize), target: self, selector: #selector(SpeechViewController.detectStutter), userInfo: nil, repeats: true)
        }
    }
    
    func detectPause() {
        // Check if we're quite in this cycle
        if tracker.amplitude < pauseThreshold {
            pauseCounter += pauseDetectionInterval
            
            // If we've been quite long enough, update stats and detectedEvent array
            if(pauseCounter >= EventGlobals.eventDuration[SpeechEventType.longPause]!){
                
                
                //ADDED
                if (detectedEvent[SpeechEventType.longPause]! == false){
                    
                    //Initialize a new speech event to be added to Event array
                    let newEvent:SpeechEvent = SpeechEvent(
                        etype: SpeechEventType.longPause,
                        filler: FillerType.none,
                        timeStart: uiTimer.timeInterval,
                        timeDuration: EventGlobals.eventDuration[SpeechEventType.longPause]!)
                    currentSession.events.append(newEvent)
                }
                else{
                    //If last event is already a long pause, extend the event
                    currentSession.events.last?.timeDuration += pauseDetectionInterval
                }
                //ENDADDED
                
                //REMOVE
                eventOccurences[SpeechEventType.longPause]! += detectedEvent[SpeechEventType.longPause]! ? pauseDetectionInterval:EventGlobals.eventDuration[SpeechEventType.longPause]!
                //ENDREMOVE
                
                
                detectedEvent[SpeechEventType.longPause] = true
            }
            else{
                detectedEvent[SpeechEventType.longPause] = false
            }
        }
        else{
            pauseCounter = 0
            detectedEvent[SpeechEventType.longPause] = false
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
            if monotonyCycles >= EventGlobals.eventDuration[SpeechEventType.monotony]! {
                
                
                //ADDED
                if !(detectedEvent[SpeechEventType.monotony]!){
                    //Initialize a new speech event to be added to Event array
                    let newEvent:SpeechEvent = SpeechEvent(
                        etype: SpeechEventType.monotony,
                        filler: FillerType.none,
                        timeStart: uiTimer.timeInterval,
                        timeDuration: EventGlobals.eventDuration[SpeechEventType.monotony]!
                    )
                    
                    currentSession.events.append(newEvent)
                }
                else{
                    //If last event is already a long pause, extend the event
                    currentSession.events.last?.timeDuration += monotonyWindowSize                 }
                //ENDADDED
                
                //REMOVE
                eventOccurences[SpeechEventType.longPause]! += detectedEvent[SpeechEventType.longPause]! ? pauseDetectionInterval:EventGlobals.eventDuration[SpeechEventType.longPause]!
                //ENDREMOVE

            }
            else{
                detectedEvent[SpeechEventType.monotony] = false
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
        if !audioRingBuff.isFull {
            return
        }
        
        // Get x and y signals
        var xSignal: [Float] = audioRingBuff.readChunk(count: Int(stutterSampleRate*stutterSignalSize)) as! [Float]
        var ySignal: [Float] = audioRingBuff.peekChunk(count: Int(stutterSampleRate*(audioTotalStoredSignalSize-stutterSignalSize))) as! [Float]
        
        // Get the sum of squares of x and y
        var normX: Float = 0
        for x in xSignal { normX += x*x }
        
        
        var normY: Float = 0
        
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
        

        detectedEvent[SpeechEventType.stutter] = false
        for i in 0..<result.count {
            let currPt = abs(result[i] / sqrtf(normY*normX))
            
            if currPt > stutterThreshold && currPt < 1{
                
                
                //ADDED
                if (detectedEvent[SpeechEventType.stutter]! == false){
                    
                    //Initialize a new speech event to be added to Event array
                    let newEvent:SpeechEvent = SpeechEvent(
                        etype: SpeechEventType.stutter,
                        filler: FillerType.none,
                        timeStart: uiTimer.timeInterval,
                        timeDuration: EventGlobals.eventDuration[SpeechEventType.stutter]!)
                    
                    currentSession.events.append(newEvent)
                }
                else{
                    //If last event is already a stutter, extend the event
                    currentSession.events.last?.timeDuration += EventGlobals.eventDuration[SpeechEventType.stutter]!
                }
                
                detectedEvent[SpeechEventType.stutter] = true
                
                break
            }
            
            normY -= ySignal[i]*ySignal[i]
            normY += ySignal[i+xSignal.count]*ySignal[i+xSignal.count]
        }
    }
    
    func saveSession(sessionName:String, audioFileName: String){
        
        //Save audio file to directory
        
        let audioFile = recorder?.audioFile
        let sourcepath = URL(fileURLWithPath: (audioFile?.url.absoluteString)!)
        let destinationpath = FileStorageGlobals.AudioFilesURL.appendingPathComponent(audioFileName)
        
        print("Copying file from " + (sourcepath.absoluteString) + " into " + (destinationpath.absoluteString))
        
        let fileManager = FileManager()
        do {
            try fileManager.copyItem(at: sourcepath, to: destinationpath)
        }
        catch let error as NSError {
            print("Failed to copy file into Documents directory: \(error)")
        }

        
        
        //Change the filename and file path of the speech session
        
        currentSession.audioFilePath = destinationpath.absoluteString
        currentSession.name = sessionName
        
        
        //Save Speech Session
        
        let isSuccessfulSave = NSKeyedArchiver.archiveRootObject(currentSession, toFile: FileStorageGlobals.SpeechesURL.appendingPathComponent(sessionName).path)
        if isSuccessfulSave {
            os_log("Speech object succesfully saved.", log: OSLog.default, type: .debug)
        } else {
            os_log("Failed to save speech.", log: OSLog.default, type: .error)
        }
    }
    
    func goToPlaybackView(){
        let newView = self.storyboard?.instantiateViewController(withIdentifier: "PlaybackViewController") as! PlaybackViewController
        
        newView.session = currentSession
        
        
        self.navigationController?.pushViewController(newView, animated: true)
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
    
}
