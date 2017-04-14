//
//  SettingsViewController.swift
//  Speech Analytics
//
//  Created by Abdo Salem on 3/30/17.
//  Copyright © 2017 Abdo Salem. All rights reserved.
//

import UIKit

class SettingsViewController: UIViewController {

    @IBOutlet weak var speechSpeedSlider: UISlider!
    @IBOutlet weak var speedLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let speed = UserDefaults.standard.double(forKey: "SpeechSpeed")
        speechSpeedSlider.setValue(Float(speed), animated: true)

        if speed == 0.0 {
            speedLabel.text = "Slow Speaker"
        }
        else if speed == 1.0 {
            speedLabel.text = "Medium Speaker"
        }
        else if speed == 2.0 {
            speedLabel.text = "Fast Speaker"
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func speechSpeedChanged(_ sender: UISlider) {
        
        if(sender.value <= 0.66 ){
            speechSpeedSlider.setValue(0.0, animated: true)
            speedLabel.text = "Slow speaker"
        }
        else if (sender.value >= 1.33){
            speechSpeedSlider.setValue(2.0, animated: true)
            speedLabel.text = "Fast Speaker"
        }
        else {
            speechSpeedSlider.setValue(1.0, animated: true)
            speedLabel.text = "Medium speaker"
        }
        
        UserDefaults.standard.set(speechSpeedSlider.value, forKey: "SpeechSpeed")
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
