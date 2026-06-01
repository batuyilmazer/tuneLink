import ActivityKit
import Foundation

struct TuneLinkActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var friendName: String
        var track: String
        var artist: String
        var albumArtURL: URL?
        var isPlaying: Bool
    }
}
