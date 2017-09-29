import Foundation
import AudioKit

// Speech events class
enum SpeechEventType: Int{
    case stutter = 0
    case monotony = 1
    case longPause = 2
    case none = 3 
}

struct Stats{
    var percentNeither: Double = 0
    var percentMonotone: Double = 0
    var percentSilent: Double = 0
    var numStutters: Double = 0
}

struct Speech{
    var name: String = ""
    var duration: Double = 0
    var date: Double = 0
    var stats: Stats = Stats(percentNeither: 1.0, percentMonotone: 0, percentSilent: 0, numStutters: 0)
}

struct Pattern{
    var audioArray: [Float] = []
    var ampArray: [Float] = []
    var tape: AKAudioFile?
}
