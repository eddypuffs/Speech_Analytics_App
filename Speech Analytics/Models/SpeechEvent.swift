import Foundation
import AudioKit

class SpeechEvent: NSObject, NSCoding{
        
    //MARK: Parameters
    
    var etype: SpeechEventType
    var filler: FillerType
    var timeStart:Double
    var timeDuration:Double

    init(etype:SpeechEventType, filler:FillerType, timeStart:Double, timeDuration:Double){ //Constructor
        self.etype = etype;
        self.filler = filler;
        self.timeStart = timeStart;
        self.timeDuration = timeDuration;
    }
    
    
    //MARK: Encoding/Decoding
    
    struct PropertyKey {
        static let etype = "etype"
        static let filler = "filler"
        static let timeStart = "timeStart"
        static let timeEnd = "timeEnd"
    }
    
    func encode(with coder: NSCoder){
        coder.encode(etype.rawValue, forKey: "etype")
        coder.encode(filler.rawValue, forKey: "filler")
        coder.encode(timeStart, forKey: "timeStart")
        coder.encode(timeDuration, forKey: "timeEnd")
    }
    
    required convenience init(coder decoder: NSCoder){
        self.init(etype: SpeechEventType.none ,filler: FillerType.none, timeStart: 0, timeDuration: 0.0);
        self.etype = decoder.decodeObject(forKey: "etype") as! SpeechEventType
        self.filler = decoder.decodeObject(forKey: "filler") as! FillerType
        self.timeStart = decoder.decodeObject(forKey: "timeStart") as! Double
        self.timeDuration = decoder.decodeObject(forKey: "timeEnd") as! Double
    }


}
