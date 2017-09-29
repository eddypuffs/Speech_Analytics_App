//
//  PrevSessTableViewController.swift
//  Speech Analytics
//
//  Created by Abdo Salem on 4/6/17.
//  Copyright © 2017 Abdo Salem. All rights reserved.
//

import UIKit
import os.log

class PrevSessTableViewController: UITableViewController { 

    @IBOutlet weak var navBar: UINavigationBar!
    var speechNames: [String] = []
    var speechDurations: [Double] = []
    var speechDates: [Double] = []
    var speechStats: [Stats] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        loadData()
        navBar.bounds = CGRect(x: 0, y: 15, width: navBar.bounds.width, height: navBar.bounds.height + 15)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    // Return count of elements
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return speechNames.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "SpeechTableViewCell", for: indexPath) as? SpeechTableViewCell else {
            fatalError("The dequeued cell is not an instance of SpeechTableViewCell.")
        }
        
        
        cell.speechName.text = speechNames[indexPath.row]
        cell.speechDuration.text = String(format:"%02d", Int(speechDurations[indexPath.row]) / 60) + ":" + String(format:"%02d", Int(speechDurations[indexPath.row]) % 60)
        let d = Date(timeIntervalSince1970: speechDates[indexPath.row])
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/YYYY"
        cell.speechDate.text = formatter.string(from: d)
                
        let stat = speechStats[indexPath.row]
        if cell.chartDataItems.count == 0 {
            cell.chartDataItems.append(PieChartItem(value: CGFloat(stat.percentNeither), color: UIColor(red: 241/255.0, green: 131/255.0, blue: 29/255.0, alpha: 1), description: "None"))
            cell.chartDataItems.append(PieChartItem(value: CGFloat(stat.percentMonotone), color: UIColor(red: 228/255.0, green: 26/255.0, blue: 106/255.0, alpha: 1), description: "Monotone"))
            cell.chartDataItems.append(PieChartItem(value: CGFloat(stat.percentSilent), color: UIColor(red: 46/255.0, green: 175/255.0, blue: 176/255.0, alpha: 1), description: "Quite"))            
        }
        
        cell.pieChart.delegate = cell
        cell.pieChart.dataSource = cell
        
        let maxRadius = min(cell.pieChart.frame.width, cell.pieChart.frame.height) / 2
        cell.pieChart.innerRadius = CGFloat(maxRadius*0.5)
        cell.pieChart.outerRadius = CGFloat(maxRadius*0.8)
        cell.pieChart.selectedPieOffset = CGFloat(maxRadius*0.25)
        cell.pieChart.reloadData()
        
        let numScore: Int = Int((stat.percentNeither - (stat.numStutters*0.01/speechDurations[indexPath.row]))*100)
        
        cell.speechScore.text = "\(numScore)" + "%"

        return cell
    }

    // Override to support editing the table view. No insertions
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            let documentsUrl =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            
            do {
                // Get the directory contents urls (including subfolders urls)
                let directoryContents = try FileManager.default.contentsOfDirectory(at: documentsUrl, includingPropertiesForKeys: nil, options: [])
                
                // Check which filename to delete
                let deletedNames = [speechNames[indexPath.row] + "wave.plist",speechNames[indexPath.row] + "event.plist",speechNames[indexPath.row] + "stats.plist"]
                
                print(directoryContents[0].path,directoryContents[0].lastPathComponent,deletedNames[0])
                let myFiles = directoryContents.filter{ $0.lastPathComponent == deletedNames[0] || $0.lastPathComponent ==  deletedNames[1] || $0.lastPathComponent == deletedNames[2]}
                
                print(myFiles)
                for file in myFiles {
                    do {
                        try FileManager.default.removeItem(at: file)
                    }
                    catch let error as NSError {
                        print("Ooops! Something went wrong: \(error)")
                    }
                }
                
                let sourcePath = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(speechNames[indexPath.row] + ".caf")
                do{
                    try FileManager().removeItem(at: sourcePath)
                } catch let error as NSError {
                    print("Couldn't delete \(sourcePath) cause \(error)")
                }

                
                speechNames.remove(at: indexPath.row)
                speechDurations.remove(at: indexPath.row)
                speechStats.remove(at: indexPath.row)
                speechDates.remove(at: indexPath.row)
                
                
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
        
        guard let prevSessionViewController = segue.destination as? PrevSessionViewController else {
            return
        }
        
        guard let selectedSpeechCell = sender as? SpeechTableViewCell else {
            fatalError("Unexpected sender: \(sender)")
        }
        
        guard let indexPath = tableView.indexPath(for: selectedSpeechCell) else {
            fatalError("The selected cell is not being displayed by the table")
        }
        
        prevSessionViewController.currSpeech = Speech(name: speechNames[indexPath.row], duration: speechDurations[indexPath.row], date: speechDates[indexPath.row], stats: speechStats[indexPath.row])
        
    }
    
    func loadData() {
        let documentsUrl =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            // Get the directory contents urls (including subfolders urls)
            let directoryContents = try FileManager.default.contentsOfDirectory(at: documentsUrl, includingPropertiesForKeys: nil, options: [])
            
            
            let myFiles = directoryContents.filter{ $0.path.contains("stats.plist") }
            speechNames = myFiles.map{ $0.deletingPathExtension().lastPathComponent }

            for i in 0..<speechNames.count{
                speechNames[i] = speechNames[i].substring(to: speechNames[i].index(speechNames[i].endIndex, offsetBy: -5))
            }
            
            print("File list:", speechNames)
            
            
            for file in myFiles{
                let loadedStats = NSArray(contentsOf: file) as! [Double]
                speechDurations.append(loadedStats[4])
                speechDates.append(loadedStats[5])
                
                let stat = Stats(percentNeither: loadedStats[0], percentMonotone: loadedStats[1], percentSilent: loadedStats[2], numStutters: loadedStats[3])
                speechStats.append(stat)
            }
            
            

        } catch let error as NSError {
            print("A7a")
        }
    }
    
    func getScore(numericScore: Double) -> String {
        if numericScore >= 0.93 { return "A"}
        else if numericScore >= 0.9 {return "A-"}
        else if numericScore >= 0.87 {return "B+"}
        else if numericScore >= 0.85 { return "B"}
        else if numericScore >= 0.80 { return "B-"}
        else if numericScore >= 0.75 { return "C+"}
        else if numericScore >= 0.70 { return "C"}
        else if numericScore >= 0.65 { return "C-"}
        else if numericScore >= 0.60 { return "D"}
        else { return "F"}
    }
}

