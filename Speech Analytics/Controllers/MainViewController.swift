//
//  ViewController.swift
//  Speech Analytics
//
//  Created by Abdo Salem on 2/20/17.
//  Copyright © 2017 Abdo Salem. All rights reserved.
//

import UIKit
import AudioKit

class MainViewController: UIViewController, EZMicrophoneDelegate {
    
    // Audio Elements
    @IBOutlet weak var audioInputPlot: EZAudioPlot!
    var mic: AKMicrophone!
    var tracker: AKFrequencyTracker!
    var silence: AKBooster!
    var plot: AKNodeOutputPlot!
    
    // UI elements
    @IBOutlet weak var titleElement: UIImageView!
    @IBOutlet weak var newSessionButton: UIButton!
    @IBOutlet weak var previousSessionButton: UIButton!
    @IBOutlet weak var settingsButton: UIButton!

    
    // UI properties
    let plotToScreenRatio: CGFloat =  0.7
    let plotGain: Float = 5.0
    let fgColor: UIColor = UIColor.white

    override func viewDidLoad() {
        super.viewDidLoad()
        
        settingsButton.layer.cornerRadius = settingsButton.frame.height/2
        newSessionButton.layer.cornerRadius = newSessionButton.frame.height/2
        previousSessionButton.layer.cornerRadius = previousSessionButton.frame.height/2

        AKSettings.audioInputEnabled = true
        mic = AKMicrophone()
        silence = AKBooster(mic,gain:0)
        AudioKit.output = silence
        AudioKit.start()
        setupPlot()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        AudioKit.stop()
    }
    
    func setupPlot() {
        plot = AKNodeOutputPlot(mic, frame: CGRect(x: 0, y: 0, width: audioInputPlot.bounds.width, height: audioInputPlot.bounds.height*plotToScreenRatio) )
    
        plot.backgroundColor = audioInputPlot.backgroundColor
        plot.color = UIColor(red: 228/255.0, green: 26/255.0, blue: 106/255.0, alpha: 1)
        
        plot.plotType = .buffer
        plot.gain = plotGain
        plot.shouldFill = true
        plot.shouldMirror = true
        audioInputPlot.addSubview(plot)
        
        for view in audioInputPlot.subviews {
            if view != plot {
                audioInputPlot.bringSubview(toFront: view)
            }
        }

    }
    
}
