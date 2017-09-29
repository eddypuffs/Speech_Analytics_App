//
//  PersonalTableViewController.swift
//  Speech Analytics
//
//  Created by Abdo Salem on 4/29/17.
//  Copyright © 2017 Abdo Salem. All rights reserved.
//

import UIKit
import AudioKit

class PersonalTableViewController: UITableViewController {

    var tape: AKAudioFile?
    var mic: AKMicrophone!
    var micBooster: AKBooster!
    var plot: AKNodeOutputPlot!
    var player: AKAudioPlayer?
    var recorder: AKNodeRecorder?
    
    
    var audioArray: [Float] = []
    var ampArray: [Float] = []
    var clockCounter: Double = 0
    var plotResolution: Int = 0

    var speechNames: [String] = []
    var numPatterns: Int = 0
    @IBOutlet weak var navBar: UINavigationBar!
    
    var patternArray: [Pattern] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navBar.bounds = CGRect(x: 0, y: 15, width: navBar.bounds.width, height: navBar.bounds.height + 15)

        loadPatterns()

        AKAudioFile.cleanTempDirectory()
        AKSettings.bufferLength = .medium

        // Setup audio kit for recording and plotting
        mic = AKMicrophone()
        let micMixer = AKMixer(mic)
        micBooster = AKBooster(micMixer, gain:0)
        
        recorder = try? AKNodeRecorder(node: micMixer)
        player = try? AKAudioPlayer(file: (recorder?.audioFile)!)
        
        let mainMixer = AKMixer(player!,micBooster!)
        AudioKit.output = mainMixer
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
        // #warning Incomplete implementation, return the number of rows
        return speechNames.count
    }

    func loadPatterns() {
        let documentsUrl =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            // Get the directory contents urls (including subfolders urls)
            let directoryContents = try FileManager.default.contentsOfDirectory(at: documentsUrl, includingPropertiesForKeys: nil, options: [])
            
            
            let myFiles = directoryContents.filter{ $0.path.contains("StutterSampleAudio.plist") }
            speechNames = myFiles.map{ $0.deletingPathExtension().lastPathComponent }
            
            for i in 0..<speechNames.count{
                speechNames[i] = speechNames[i].substring(to: speechNames[i].index(speechNames[i].endIndex, offsetBy: -18))
            }
            
            print("File list:", speechNames)
 
            for name in speechNames{
                let loadedWave = NSArray(contentsOf: FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(name + "StutterSampleAudio.plist")) as! [Float]
                let loadedPlot = NSArray(contentsOf: FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(name + "StutterSampleAmp.plist")) as! [Float]
                do{
                    tape = try AKAudioFile(forReading: FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(name + "StutterSample.caf"))
                } catch {print("Error")}
                
                patternArray.append(Pattern(audioArray: loadedWave, ampArray: loadedPlot, tape: tape))
            }
            
        } catch let error as NSError {
            print("A7a")
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "PersonalTableViewCell", for: indexPath) as? PersonalTableViewCell else {
            fatalError("The dequeued cell is not an instance of PersonalTableViewCell.")
        }
        
        cell.nameLabel.text = speechNames[indexPath.row]
        cell.durationLabel.text = "\(patternArray[indexPath.row].tape?.duration ?? 0.0) s";
        
        mic = AKMicrophone()
        
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
        cell.plot.updateBuffer(&(patternArray[indexPath.row].ampArray[0]), withBufferSize: UInt32(patternArray[indexPath.row].ampArray.count))
        cell.tape = patternArray[indexPath.row].tape
        cell.player = self.player
        return cell
    }

    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            let documentsUrl =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            
            do {
                // Get the directory contents urls (including subfolders urls)
                let directoryContents = try FileManager.default.contentsOfDirectory(at: documentsUrl, includingPropertiesForKeys: nil, options: [])
                
                // Check which filename to delete
                let deletedNames = [speechNames[indexPath.row] + "StutterSampleAudio.plist",speechNames[indexPath.row] + "StutterSampleAmp.plist"]
                
                let myFiles = directoryContents.filter{ $0.lastPathComponent == deletedNames[0] || $0.lastPathComponent ==  deletedNames[1]}
                
                print(myFiles)
                for file in myFiles {
                    do {
                        try FileManager.default.removeItem(at: file)
                    }
                    catch let error as NSError {
                        print("Ooops! Something went wrong: \(error)")
                    }
                }
                
                let sourcePath = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(speechNames[indexPath.row] + "StutterSample.caf")
                do{
                    try FileManager().removeItem(at: sourcePath)
                } catch let error as NSError {
                    print("Couldn't delete \(sourcePath) cause \(error)")
                }
                
                
                speechNames.remove(at: indexPath.row)
            } catch let error as NSError {
                print("A7a")
            }
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }

    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        AudioKit.stop()
        if let setupViewController = segue.destination as? SetupViewController{
            setupViewController.setupMode = false
        }
    }

}
