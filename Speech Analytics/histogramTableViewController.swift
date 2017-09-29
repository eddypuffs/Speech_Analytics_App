//
//  histogramTableViewController.swift
//  Speech Analytics
//
//  Created by Abdo Salem on 4/18/17.
//  Copyright © 2017 Abdo Salem. All rights reserved.
//

import UIKit
import AudioKit

class histogramTableViewController: UITableViewController {
    
    var mic: AKMicrophone!
    var player: AKAudioPlayer?
    var recorder: AKNodeRecorder?
    var patternHistogram: [Int] = []
    var patternStartTime: [Double] = []
    var patternEndtime: [Double] = []
    var patternNames: [String] = []
    var patternArray: [Pattern] = []
    var highestIDs: [Int] = []
    var ampArray: [Float] = []
    var numPatterns: Int = 0
    var clockCounter: Double = 0
    var plotResolution: Int = 0
    
    // Stuff for state restoration
    var eventArray: [Int] = []
    var percentNeither: Double = 0
    var percentMonotone: Double = 0
    var percentSilent: Double = 0
    var numStutters: Double = 0
    
    // What are we displaying?
    var patterns: Bool = true
    

    @IBOutlet weak var navBar: UINavigationBar!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navBar.bounds = CGRect(x: 0, y: 15, width: navBar.bounds.width, height: navBar.bounds.height + 15)
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return numPatterns
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "histogramTableViewCell", for: indexPath) as? histogramTableViewCell else {
            fatalError("The dequeued cell is not an instance of histogramTableViewCell.")
        }
        
        mic = AKMicrophone()
        mic.stop()
        
        cell.plot = AKNodeOutputPlot(mic!,frame: cell.audioInputPlot.bounds)
        cell.audioInputPlot.addSubview(cell.plot)
        cell.plot.updatesEnabled = false
        cell.audioInputPlot.backgroundColor = UIColor(white: 0.0, alpha: 0.0)
        cell.plot.backgroundColor = UIColor(white: 0.0, alpha: 0.0)
        cell.plot.color = UIColor(red: 241/255.0, green: 131/255.0, blue: 29/255.0, alpha: 1)
        cell.plot.plotType = .buffer
        cell.plot.shouldFill = true
        cell.plot.shouldMirror = true
        cell.plot.gain = 5.0

        cell.player = player


        if !patterns {
            // Get num occurences and duration
            let myID = highestIDs[indexPath.row]
            let numOccurences = patternHistogram[myID]
            cell.numOccurences.text = "\(numOccurences)"

            let duration = patternEndtime[myID] - patternStartTime[myID]
            cell.duration.text = "\(Int(duration * 1000)) ms"
            
            // Get start and end index
            let startIndex = Int(patternStartTime[myID]/clockCounter * ampArray.count)
            let endIndex = Int(patternEndtime[myID]/clockCounter * ampArray.count)
            
            cell.plot.updateBuffer(&(ampArray[startIndex]), withBufferSize: UInt32(endIndex - startIndex))
            
            if patternStartTime[myID] < (player?.startTime)! {
                patternStartTime[myID] += 0.0001
            }
            
            if patternEndtime[myID] > (player?.endTime)! {
                patternEndtime[myID] -= 0.0001
            }
            
            cell.startTime = patternStartTime[myID]
            cell.endTime = patternEndtime[myID]
        }
        else{
            // Get num occurences and duration
            let numOccurences = patternHistogram[indexPath.row]
            cell.numOccurences.text = "\(numOccurences)"
            cell.patternName.text = patternNames[indexPath.row]
            cell.patternName.isHidden = false
            cell.tape = patternArray[indexPath.row].tape
            cell.duration.text = "\(Int((patternArray[indexPath.row].tape?.duration)! * 1000)) ms"
            
            cell.plot.updateBuffer(&(patternArray[indexPath.row].ampArray[0]), withBufferSize: UInt32(patternArray[indexPath.row].ampArray.count))
        }

        cell.patterns = patterns
        return cell
    }
    

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        AudioKit.stop()
        
        guard let viewController = segue.destination as? ViewController else {
            return
        }
        
        viewController.ampArray = self.ampArray
        viewController.eventArray = self.eventArray
        do {
            try self.player?.replace(file: (self.recorder?.audioFile)!)
        }catch {print("Errored replacing back tape")}
        viewController.player = self.player
        viewController.clockCounter = self.clockCounter
        viewController.eventOccurences[SpeechEventType.longPause.rawValue] = self.percentSilent
        viewController.eventOccurences[SpeechEventType.monotony.rawValue] = self.percentMonotone
        viewController.eventOccurences[SpeechEventType.stutter.rawValue] = self.numStutters
        viewController.restoreState = true
        viewController.recorder = self.recorder

        viewController.patternArray = self.patternArray
        viewController.patternNames = self.patternNames
        viewController.patternHistogram = self.patternHistogram
        viewController.patternStartTime = self.patternStartTime
        viewController.patternEndTime = self.patternEndtime
    }

}
