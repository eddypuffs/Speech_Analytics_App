//
//  UIColorPresets.swift
//  Speech Analytics
//
//  Created by Eduardo Nunez on 4/10/17.
//  Copyright © 2017 Abdo Salem. All rights reserved.
//

import UIKit
import Foundation


//UI Globals

struct ColorPresets{
    
    static let White: UIColor = UIColor(red: 244/255.0, green: 244/255.0, blue: 244/255.0, alpha: 1)
    static let Orange: UIColor = UIColor(red: 241/255.0, green: 131/255.0, blue: 29/255.0, alpha: 1)
    static let Purple: UIColor = UIColor(red: 127/255.0, green: 43/255.0, blue: 130/255.0, alpha: 1)
    static let Red: UIColor = UIColor(red: 228/255.0, green: 26/255.0, blue: 106/255.0, alpha: 1)
    static let Blue: UIColor = UIColor(red: 46/255.0, green: 175/255.0, blue: 176/255.0, alpha: 1)
}


struct EventGlobals{
    
    static let textEvents: [SpeechEventType:String] = [SpeechEventType.none:"Good",
                                                       SpeechEventType.stutter:"Stutter",
                                                       SpeechEventType.monotony:"Monotonous",
                                                       SpeechEventType.longPause:"Pause"]


    static let priorityEvents: [SpeechEventType] = [SpeechEventType.stutter,
                                                    SpeechEventType.monotony,
                                                    SpeechEventType.longPause,
                                                    SpeechEventType.none]
    
    static let eventDuration: [SpeechEventType:TimeInterval] = [SpeechEventType.monotony:3,    // 3 seconds
        SpeechEventType.longPause:3,   // 3 seconds
        SpeechEventType.stutter:1,     // 1 stutter
        SpeechEventType.none:0]
    
    
    static let displayDelay: [SpeechEventType:TimeInterval] = [SpeechEventType.none:0,
                                                               SpeechEventType.stutter:1,
                                                               SpeechEventType.monotony:0,
                                                               SpeechEventType.longPause:0]

}

struct FileStorageGlobals{
    
    
    //MARK: Archiving Paths
    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    static let SpeechesURL = DocumentsDirectory
    static let AudioFilesURL = DocumentsDirectory

    
    
}


//Speech Detection Enums

enum SpeechEventType: Int
{
    case none=0,
    stutter,
    monotony,
    longPause,
    fillerWord
}

enum FillerType: Int{
    case none = 0,
    like,
    uhm ,
    so,
    what
}

