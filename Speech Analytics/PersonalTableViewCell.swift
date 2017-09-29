//
//  PersonalTableViewCell.swift
//  Speech Analytics
//
//  Created by Abdo Salem on 4/29/17.
//  Copyright © 2017 Abdo Salem. All rights reserved.
//

import UIKit
import AudioKit

class PersonalTableViewCell: UITableViewCell {

    var plot: AKNodeOutputPlot!
    var player: AKAudioPlayer?
    var tape: AKAudioFile?
    var booster: AKBooster!
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var audioInputPlot: EZAudioPlot!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        player?.completionHandler = finishedPlaying
        do{
            try player?.replace(file: tape!)
        } catch { print("Errored replacing tape")}

        if !AudioKit.engine.isRunning {
            AudioKit.start()
        }
        player?.play()
    }
    
    func finishedPlaying(){
        AudioKit.stop()
    }

}
