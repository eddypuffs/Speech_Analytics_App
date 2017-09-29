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
    @IBOutlet weak var stutterSwitch: UISegmentedControl!
    
    @IBOutlet weak var monotonySlider: UISlider!
    @IBOutlet weak var monotonySwitch: UISegmentedControl!
    @IBOutlet weak var monotonyLabel: UILabel!
    
    @IBOutlet weak var silenceSwitch: UISegmentedControl!
    @IBOutlet weak var silenceSlider: UISlider!
    @IBOutlet weak var silenceLabel: UILabel!
    
    @IBOutlet weak var offlineSwitch: UISegmentedControl!
    @IBOutlet weak var offlineButton: UIButton!
    
    @IBOutlet weak var autoSetupButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Make the buttons look nice
        offlineButton.layer.cornerRadius = offlineButton.frame.height/4
        autoSetupButton.layer.cornerRadius = autoSetupButton.frame.height/2
        
        // Retrieve the speech speed data and change UI accordingly
        let speed = UserDefaults.standard.float(forKey: "SpeechSpeed")
        speechSpeedSlider.setValue(speed * 1000, animated: true)
        if speed >= 165 { speedLabel.text = "Slow Speaker" }
        else if speed <= 65{ speedLabel.text = "Fast Speaker" }
        else { speedLabel.text = "Medium Speaker" }
        
        // Restore other settings UI configs too
        monotonySwitch.selectedSegmentIndex = UserDefaults.standard.bool(forKey: "MonotonyEnabled") == true ? 0:1
        silenceSwitch.selectedSegmentIndex = UserDefaults.standard.bool(forKey: "SilenceEnabled") == true ? 0:1
        stutterSwitch.selectedSegmentIndex = UserDefaults.standard.bool(forKey: "StutterEnabled") == true ? 0:1
        offlineSwitch.selectedSegmentIndex = UserDefaults.standard.integer(forKey: "ProcessingType")
        
        monotonySlider.value = UserDefaults.standard.float(forKey: "MonotonyDuration")
        silenceSlider.value = UserDefaults.standard.float(forKey: "SilenceDuration")
        
        offlineButton.isEnabled = !(UserDefaults.standard.integer(forKey: "ProcessingType") == 2)

        monotonyLabel.text = "\(Int(monotonySlider.value)) sec"
        silenceLabel.text = "\(Int(silenceSlider.value)) sec"
    }
    
    @IBAction func speechSpeedChanged(_ sender: UISlider) {
        
        UserDefaults.standard.set(sender.value/1000, forKey: "SpeechSpeed")
        
        if(sender.value <= 66 ){
            speedLabel.text = "Fast speaker"
        }
        else if (sender.value >= 165){
            speedLabel.text = "Slow speaker"
        }
        else {
            speedLabel.text = "Medium speaker"
        }
    }
    @IBAction func monotonySwitched(_ sender: UISegmentedControl) {
        UserDefaults.standard.set(sender.selectedSegmentIndex == 0, forKey: "MonotonyEnabled")
        monotonySlider.isEnabled = sender.selectedSegmentIndex == 0
    }
    @IBAction func silenceSwitched(_ sender: UISegmentedControl) {
        UserDefaults.standard.set(sender.selectedSegmentIndex == 0, forKey: "SilenceEnabled")
        silenceSlider.isEnabled = sender.selectedSegmentIndex == 0

    }
    @IBAction func offlineAnalysisSwitched(_ sender: UISegmentedControl) {
        UserDefaults.standard.set(sender.selectedSegmentIndex, forKey: "ProcessingType")
        offlineButton.isEnabled = !(sender.selectedSegmentIndex == 2)
    }
    @IBAction func stutterSwitched(_ sender: UISegmentedControl) {
        UserDefaults.standard.set(sender.selectedSegmentIndex == 0, forKey: "StutterEnabled")
        speechSpeedSlider.isEnabled = sender.selectedSegmentIndex == 0
    }
    @IBAction func monotonySlid(_ sender: UISlider) {
        monotonyLabel.text = "\(Int(sender.value)) sec"
        UserDefaults.standard.set(sender.value, forKey: "MonotonyDuration")
    }
    @IBAction func silenceSlid(_ sender: UISlider) {
        silenceLabel.text = "\(Int(sender.value)) sec"
        UserDefaults.standard.set(sender.value, forKey: "SilenceDuration")
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let setupViewController = segue.destination as? SetupViewController{
            setupViewController.setupMode = true
        }
    }

    
    
}
