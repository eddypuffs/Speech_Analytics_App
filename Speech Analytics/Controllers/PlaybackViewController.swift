//
//  PlaybackViewController.swift
//  Speech Analytics
//
//  Created by Eduardo Nunez on 4/12/17.
//  Copyright © 2017 Abdo Salem. All rights reserved.
//

import UIKit

class PlaybackViewController: UIViewController {

    @IBOutlet weak var SpeechNameLabel: UILabel!
    @IBOutlet weak var AudioFilePathLabel: UILabel!
    
    var session: SpeechSession? = nil;
    
    override func viewDidLoad() {
        super.viewDidLoad()

        SpeechNameLabel.text = session?.name
        AudioFilePathLabel.text = session?.audioFilePath
        
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
