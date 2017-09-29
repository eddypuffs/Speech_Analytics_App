//
//  histogramTableViewCell.swift
//  Speech Analytics
//
//  Created by Abdo Salem on 4/18/17.
//  Copyright © 2017 Abdo Salem. All rights reserved.
//

import UIKit
import AudioKit

class histogramTableViewCell: UITableViewCell {

    @IBOutlet weak var audioInputPlot: EZAudioPlot!
    var plot: AKNodeOutputPlot!
    @IBOutlet weak var numOccurences: UILabel!
    @IBOutlet weak var duration: UILabel!
    var player: AKAudioPlayer?
    var startTime: Double = 0
    var endTime: Double = 0
    var tape: AKAudioFile!
    var patterns: Bool = false
    
    @IBOutlet weak var patternName: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        player?.completionHandler = finishedPlaying
        
        if patterns{
            do{
                try player?.replace(file: tape!)
            } catch { print("Errored replacing tape")}
        }
        
        if !AudioKit.engine.isRunning {
            AudioKit.start()
        }

        if patterns { player?.play() }
        else{ player?.play(from: startTime, to: endTime, when: 0) }
    }
    
    func finishedPlaying(){
        AudioKit.stop()
    }

}
