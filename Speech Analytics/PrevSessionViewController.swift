//
//  PrevSessionViewController.swift
//  Speech Analytics
//
//  Created by Abdo Salem on 4/13/17.
//  Copyright © 2017 Abdo Salem. All rights reserved.
//

import UIKit
import AudioKit

class PrevSessionViewController: UIViewController, ARPieChartDelegate, ARPieChartDataSource {
    
    // Setup AudioKit stuff
    @IBOutlet weak var audioInputPlot: EZAudioPlot!
    var plot: AKNodeOutputPlot!
    var mic: AKMicrophone!
    var micBooster: AKBooster!
    var player: AKAudioPlayer?
    var tape: AKAudioFile?

    
    // UI Elements
    @IBOutlet weak var speechNameLabel: UILabel!
    @IBOutlet weak var speechEventLabel: UILabel!
    @IBOutlet weak var timeEventLabel: UILabel!
    var uiTimer: Timer = Timer()
    let uiUpdateInterval: TimeInterval = 0.01
    
    // UI Features
    var clockCounter: Double = 0
    
    // Gesture Recognizers
    let panRec = UIPanGestureRecognizer()
    let doubleTapRec = UITapGestureRecognizer()
    
    // Moving Timeline
    var currPan: Int = 0
    var currTime: Double = 0
    let plotResolution: Int = 4000
    let plotSampleRate: TimeInterval = 2000
    var ampArray: [Float] = []
    
    // Speech Events
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

    // Stats
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
    
    
    
    // Info about current speech
    var currSpeech: Speech = Speech(name: "",duration: 0,date: 0,stats: Stats(percentNeither: 1,percentMonotone: 0,percentSilent: 0, numStutters: 0))
    
    override func viewDidLoad() {
        super.viewDidLoad()

        loadSpeech()
        
        // Setup chart delegates
        scoreChart.delegate = self
        scoreChart.dataSource = self
        monotonyChart.delegate = self
        monotonyChart.dataSource = self
        silenceChart.delegate = self
        silenceChart.dataSource = self
        
        // Add gesture recognizers
        // Pan for moving timeline
        panRec.addTarget(self, action: #selector(ViewController.handlePan))
        // Double tap to play audio
        doubleTapRec.addTarget(self, action: #selector(ViewController.viewTapped))
        doubleTapRec.numberOfTapsRequired = 2
        
        self.view.addGestureRecognizer(panRec)
        self.view.addGestureRecognizer(doubleTapRec)
        
        // Setup AudioKit
        AKSettings.bufferLength = .medium
        
        do {
            try AKSettings.setSession(category:.playback, with: .defaultToSpeaker)
        } catch { print("Errored setting category.") }
        
        // Setup audio kit for recording and plotting
        mic = AKMicrophone()
        let micMixer = AKMixer(mic)
        micBooster = AKBooster(micMixer, gain:0)
        
        
        player = try? AKAudioPlayer(file: (tape)!)//(recorder?.audioFile)!)
        player?.completionHandler = finishedPlaying
        
        let mainMixer = AKMixer(player!,micBooster!)
        mainMixer.volume = mainMixer.volume * 2
        AudioKit.output = mainMixer
        mic.stop()

        
        // Setup plot and stats
        setupPlotAndStats()

        uiTimer = Timer.scheduledTimer(timeInterval: uiUpdateInterval, target: self, selector: #selector(ViewController.updateUI), userInfo: nil, repeats: true)

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func finishedPlaying(){
        AudioKit.stop()
    }

    func loadSpeech(){
        let documentsUrl =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            // Get the directory contents urls (including subfolders urls)
            let directoryContents = try FileManager.default.contentsOfDirectory(at: documentsUrl, includingPropertiesForKeys: nil, options: [])
            
            let myFileNames = [currSpeech.name + "wave.plist",currSpeech.name + "event.plist"]
            
            let myFiles = directoryContents.filter{ $0.lastPathComponent == myFileNames[0] || $0.lastPathComponent ==  myFileNames[1]}
            
            for file in myFiles{
                if file.lastPathComponent == myFileNames[0]{ // wave
                    ampArray = NSArray(contentsOf: file) as! [Float]
                }
                else if file.lastPathComponent == myFileNames[1]{ // event
                    eventArray = NSArray(contentsOf: file) as! [Int]
                    
                }
            }
            
            clockCounter = currSpeech.duration
            
            let sourcePath = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(currSpeech.name + ".caf")
            do{
                try tape = AKAudioFile(forReading: sourcePath)
            } catch let error as NSError {
                print("Failed to load audio from \(sourcePath) cause \(error)")
            }
            
        } catch let error as NSError {
            print("A7a \(error)")
        }
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
        if(ampArray.count > plotResolution && !player!.isPlaying){
            
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
    
    func setupPlotAndStats() {
        plot = AKNodeOutputPlot(mic,frame:audioInputPlot.bounds)
        plot.updatesEnabled = false
        plot.gain = 1
        plot.shouldFill = true
        plot.shouldMirror = true

        audioInputPlot.addSubview(plot)
        audioInputPlot.sendSubview(toBack: plot)
        
        currPan = ampArray.count < plotResolution ? 0: ampArray.count - plotResolution - 1
        plot.plotType = .buffer
        plot.color = fgcolorEvents[SpeechEventType.none.rawValue]
        audioInputPlot.backgroundColor = bgcolorEvents[SpeechEventType.none.rawValue]
        plot.backgroundColor = UIColor(white: 0.0, alpha: 0.0)
        
        // Shrink plot
        plot.bounds = CGRect(x: 0, y: 0 , width: audioInputPlot.bounds.width, height: audioInputPlot.bounds.height*0.6)
        plot.transform = CGAffineTransform( translationX: 0.0, y: +(audioInputPlot.bounds.height*0.25) )
        
        
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
        percentSilent = CGFloat(currSpeech.stats.percentSilent)
        silenceDataItems.append( PieChartItem(value: percentSilent, color: fgcolorEvents[SpeechEventType.longPause.rawValue]!, description: "Quite" ))
        silenceDataItems.append( PieChartItem(value: 1 - percentSilent, color: emptyChartColor, description: "" ))
        silenceDataLabel.text = "\(Int(percentSilent*100))" + "%"
        silenceChart.reloadData()
        
    
        percentMonotone = CGFloat(currSpeech.stats.percentMonotone)
        monotonyDataItems.append( PieChartItem(value: percentMonotone, color: fgcolorEvents[SpeechEventType.monotony.rawValue]!, description: "Monotone" ))
        monotonyDataItems.append( PieChartItem(value: 1 - percentMonotone, color: emptyChartColor, description: "" ))
        monotonyDataLabel.text = "\(Int(percentMonotone*100))" + "%"
        monotonyChart.reloadData()
        
        percentNeither = CGFloat(currSpeech.stats.percentNeither)
        scoreDataItems.append( PieChartItem(value: percentNeither , color: fgcolorEvents[SpeechEventType.none.rawValue]!, description: "None"))
        scoreDataItems.append( PieChartItem(value: 1 - percentNeither , color: emptyChartColor, description: "" ))
        scoreDataLabel.text = "\(Int(percentNeither*100))" + "%"
        scoreChart.reloadData()
        
        
        timeDataLabel.text = String(format:"%02d", Int(clockCounter) / 60) + ":" + String(format:"%02d", Int(clockCounter) % 60)
        
        stutterDataLabel.text = "\(Int(currSpeech.stats.numStutters))"
        
        speechNameLabel.text = currSpeech.name
    }
    
    func updateUI() {
        
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
        timeEventLabel.textColor = fgcolorEvents[eventArray[currPan+(plotResolution/2)]]
        speechEventLabel.textColor = fgcolorEvents[eventArray[currPan+(plotResolution/2)]]
        plot.color = fgcolorEvents[eventArray[currPan+(plotResolution/2)]]
        speechNameLabel.textColor = fgcolorEvents[eventArray[currPan+(plotResolution/2)]]

        speechEventLabel.text = textEvents[eventArray[currPan+(plotResolution/2)]]
        timeEventLabel.text = String(format:"%02d",Int(displayTime)/60) + ":" + String(format:"%02d",Int(displayTime)%60)


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
