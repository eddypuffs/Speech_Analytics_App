//
//  SpeechSession.swift
//  Speech Analytics
//
//  Created by Eduardo Nunez on 4/10/17.
//  Copyright © 2017 Eduardo Nunez. All rights reserved.
//

import Foundation
import AudioKit
import os.log

class SpeechSession: NSObject, NSCoding{
    
    //MARK: Properties
    
    var name: String //Name of speech
    var audioFilePath: String //Path to audiofile
    var events: [SpeechEvent] //Speech Events
    var audioLength: Double //Length of recording in seconds
    var date: NSDate //Date of recording
        
    
    //MARK: Types
    
    struct PropertyKey {
        static let name = "name"
        static let audioFilePath = "audioFilePath"
        static let events = "events"
        static let date = "date"
        static let audioLength = "audioLength"
    }
    
    
    //MARK: Initialization
    
    init?(name:String, audioFilePath:String, events:[SpeechEvent]){ //Constructor
        
        //BEFORE INITIALIZING: CHECK IF WAV FILE AT AUDIOFILEPATH EXISTS
        
        /* //TO BE IMPLEMENTED
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: audioFilePath) {
            print("WAV FILE AVAILABLE. PROCEDING TO INITIALIZE")
        } else {
            print("WAV FILE NOT AVAILABLE")
            return nil
        }
        */
        
        //INITIALIZING
        
        self.name = name
        self.audioFilePath = audioFilePath
        self.events = events
        self.audioLength = 100 //TO BE IMPLEMENTED
        self.date = NSDate() //Get the current date
        
    }

    //MARK: Initialization
    
    
    convenience init?(name:String, audioFilePath:String){ //Constructor with unknown number of speech events
        
        let emptyevents: [SpeechEvent] = []
        self.init(name: name, audioFilePath: audioFilePath, events: emptyevents)
    }

    
    //MARK: Decode/Encode
    
    required convenience init?(coder aDecoder: NSCoder) {
        
        // The name is required. If we cannot decode a name string, the initializer should fail.
        guard let name = aDecoder.decodeObject(forKey: PropertyKey.name) as? String else {
            os_log("Unable to decode the name for a Speech object.", log: OSLog.default, type: .debug)
            return nil
        }
        
        let audioFilePath = aDecoder.decodeObject(forKey: PropertyKey.audioFilePath) as! String
        let events = aDecoder.decodeObject(forKey: PropertyKey.events) as! [SpeechEvent]
        let audioLength = aDecoder.decodeObject(forKey: PropertyKey.audioFilePath) as! Double
        let date = aDecoder.decodeObject(forKey: PropertyKey.date) as! NSDate
        
        //Initialize
        
        self.init(name:name, audioFilePath:audioFilePath, events:events)
        self.audioLength = audioLength
        self.date = date
        
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(audioFilePath, forKey: PropertyKey.audioFilePath)
        aCoder.encode(events, forKey: PropertyKey.events)
        aCoder.encode(date, forKey: PropertyKey.date)
        aCoder.encode(audioLength, forKey: PropertyKey.audioLength)
    }
    
    func getNumberOfEventOccurences() -> [SpeechEventType: Double]{
        var eventOccurences: [SpeechEventType: Double] = [SpeechEventType.stutter:0,
                                                          SpeechEventType.longPause:0,
                                                          SpeechEventType.monotony:0]
        
        for event in events{
            if(event.etype == SpeechEventType.stutter) {eventOccurences[SpeechEventType.stutter]! += 1.0}
            if(event.etype == SpeechEventType.longPause) {eventOccurences[SpeechEventType.longPause]! += 1.0}
            if(event.etype == SpeechEventType.longPause) {eventOccurences[SpeechEventType.longPause]! += 1.0}
        }
        
        return eventOccurences;
    }
    
    
    

    func audioIsEmpty() -> Bool {
        return false
    }
    
}
