import Foundation

/// A recorded hand-tracking session, saved as JSON from the app's Debug window.
///
/// Recordings are plain data, so the same files can test a port of the brain
/// written in another language: replay the frames, compare the commands.
public struct Recording: Sendable, Codable, Equatable {
    /// What replaying this recording through the brain must produce.
    /// Leave a field nil to not check it.
    public struct Expectation: Sendable, Codable, Equatable {
        public var leftClicks: Int?
        public var rightClicks: Int?
        public var drags: Int?
        public var scrolls: Int?
        public var zooms: Int?
        public var spaceSwitches: Int?
        /// For "resting hand" recordings: no command at all may be produced.
        public var noCommands: Bool?

        public init(leftClicks: Int? = nil, rightClicks: Int? = nil, drags: Int? = nil, scrolls: Int? = nil,
                    zooms: Int? = nil, spaceSwitches: Int? = nil, noCommands: Bool? = nil) {
            self.leftClicks = leftClicks
            self.rightClicks = rightClicks
            self.drags = drags
            self.scrolls = scrolls
            self.zooms = zooms
            self.spaceSwitches = spaceSwitches
            self.noCommands = noCommands
        }
    }

    public var version: Int
    public var note: String?
    public var frames: [HandFrame]
    public var expect: Expectation?

    public init(version: Int = 1, note: String? = nil, frames: [HandFrame], expect: Expectation? = nil) {
        self.version = version
        self.note = note
        self.frames = frames
        self.expect = expect
    }
}

/// Counts what a stream of commands did, for checking against an `Expectation`.
public struct CommandSummary: Sendable, Equatable {
    public var leftClicks = 0
    public var rightClicks = 0
    public var drags = 0
    public var scrolls = 0
    public var zooms = 0
    public var spaceSwitches = 0
    public var total = 0

    public init(_ commands: [Command]) {
        total = commands.count
        var movedWhileLeftDown = false
        var leftDown = false
        var scrolling = false
        for command in commands {
            switch command {
            case .buttonDown(.left, _):
                leftDown = true
                movedWhileLeftDown = false
            case .buttonUp(.left, _):
                if leftDown { movedWhileLeftDown ? (drags += 1) : (leftClicks += 1) }
                leftDown = false
            case .buttonUp(.right, _):
                rightClicks += 1
            case .move, .moveTo:
                if leftDown { movedWhileLeftDown = true }
            case .scroll(_, _, let phase):
                if phase == .began, !scrolling { scrolls += 1; scrolling = true }
                if phase == .ended { scrolling = false }
            case .zoom:
                zooms += 1
            case .switchSpace:
                spaceSwitches += 1
            case .buttonDown(.right, _):
                break
            }
        }
    }

    public func mismatches(against e: Recording.Expectation) -> [String] {
        var problems: [String] = []
        func check(_ name: String, _ actual: Int, _ expected: Int?) {
            if let expected, actual != expected { problems.append("\(name): expected \(expected), got \(actual)") }
        }
        check("leftClicks", leftClicks, e.leftClicks)
        check("rightClicks", rightClicks, e.rightClicks)
        check("drags", drags, e.drags)
        check("scrolls", scrolls, e.scrolls)
        check("zooms", zooms, e.zooms)
        check("spaceSwitches", spaceSwitches, e.spaceSwitches)
        if e.noCommands == true, total > 0 { problems.append("noCommands: got \(total) commands") }
        return problems
    }
}
