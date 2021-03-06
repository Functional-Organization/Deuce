//
//  Match.swift
//  Deuce
//
//  Created by Austin Conlon on 1/21/19.
//  Copyright © 2020 Austin Conlon. All rights reserved.
//

import Foundation

struct Match: Codable, Hashable {
    let id = UUID()
    
    var format: RulesFormats
    
    var playerOneName: String?
    var playerTwoName: String?
    
    var servicePlayer: Player! {
        didSet {
            currentSet.currentGame.currentPoint.servicePlayer = servicePlayer
        }
    }
    
    var returningPlayer: Player! {
        switch servicePlayer {
        case .playerOne:
            return .playerTwo
        case .playerTwo:
            return .playerOne
        case .none:
            return nil
        }
    }
    
    var setsWon = [0, 0] {
        didSet {
            if self.winner == nil { sets.append(Set(format: format)) }
            if (format == .alternate || format == .noAd) && setsWon == [1, 1] {
                startSupertiebreak()
            }
        }
    }
    
    var setsPlayed: Int { setsWon.sum }
    
    var sets: [Set]
    /// Number of sets required to win the match. In a best-of 3 set series, the first to win 2 sets wins the match. In a best-of 5 it's 3 sets, and in a 1 set match it's of course 1 set.
    var numberOfSetsToWin: Int
    
    var winner: Player? {
        get {
            if setsWon[0] >= numberOfSetsToWin { return .playerOne }
            if setsWon[1] >= numberOfSetsToWin { return .playerTwo }
            return nil
        }
    }
    
    var state: MatchState = .playing
    var date: Date!
    
    var currentSet: Set {
        get { sets.last! }
        set { sets[sets.count - 1] = newValue }
    }
    
    var undoStack = Stack<Match>()
    
    var totalGamesPlayed: Int {
        var totalGamesPlayed = 0
        for set in sets { totalGamesPlayed += set.gamesPlayed }
        return totalGamesPlayed
    }
    
    var isSupertiebreak: Bool {
        switch format {
        case .alternate, .noAd:
            if setsWon == [1, 1] { return true }
        default:
            return false
        }
        return false
    }
    
    var playerOneServicePointsPlayed: Int!
    var playerTwoServicePointsPlayed: Int!
    
    var playerOneServicePointsWon: Int!
    var playerTwoServicePointsWon: Int!
    
    var playerOneBreakPointsPlayed: Int!
    var playerTwoBreakPointsPlayed: Int!
    
    var playerOneBreakPointsWon: Int!
    var playerTwoBreakPointsWon: Int!
    
    var allPointsPlayed: [Point] {
        get {
            var allPointsPlayed = [Point]()
            for set in sets {
                for game in set.games {
                    for point in game.points where point.winner != nil {
                        allPointsPlayed.append(point)
                    }
                }
            }
            return allPointsPlayed
        }
    }
    
    var teamOnePointsWon: Int {
        var teamOnePointsWon = 0
        
        for point in allPointsPlayed {
            if point.winner == .playerOne {
                teamOnePointsWon += 1
            }
        }
        return teamOnePointsWon
    }
    
    var teamTwoPointsWon: Int {
        var teamTwoPointsWon = 0
        for point in allPointsPlayed {
            if point.winner == .playerTwo {
                teamTwoPointsWon += 1
            }
        }
        return teamTwoPointsWon
    }
    
    var notes = "Notes"
    
    // MARK: - Initialization
    init(format: Format) {
        self.format = RulesFormats(rawValue: format.name)!
        if self.format == .noAd {
            Game.noAd = true
        } else {
            Game.noAd = false
        }
        self.numberOfSetsToWin = format.minimumSetsToWinMatch
        sets = [Set(format: self.format)]
        
        playerOneServicePointsPlayed = 0
        playerTwoServicePointsPlayed = 0
        
        playerOneServicePointsWon = 0
        playerTwoServicePointsWon = 0
        
        playerOneBreakPointsPlayed = 0
        playerTwoBreakPointsPlayed = 0
        
        playerOneBreakPointsWon = 0
        playerTwoBreakPointsWon = 0
    }
    
    // MARK: - Methods
    mutating func scorePoint(for player: Player) {
        undoStack.push(self)
        
        switch player {
        case .playerOne:
            currentSet.currentGame.pointsWon[0] += 1
        case .playerTwo:
            currentSet.currentGame.pointsWon[1] += 1
        }
        
        if currentSet.currentGame.isDeuce {
            currentSet.currentGame.pointsWon[0] = 3
            currentSet.currentGame.pointsWon[1] = 3
        }
        
        checkWonGame()
        updateService()
    }
    
    private mutating func checkWonGame() {
        if let gameWinner = currentSet.currentGame.winner {
            switch gameWinner {
            case .playerOne:
                currentSet.gamesWon[0] += 1
            case .playerTwo:
                currentSet.gamesWon[1] += 1
            }
            
            checkWonSet()
        }
    }
    
    private mutating func checkWonSet() {
        if let setWinner = currentSet.winner {
            switch setWinner {
            case .playerOne:
                self.setsWon[0] += 1
            case .playerTwo:
                self.setsWon[1] += 1
            }
            
            checkWonMatch()
        }
    }
    
    private mutating func checkWonMatch() {
        if self.winner != nil {
            self.state = .finished
        }
    }
    
    mutating func stop() {
        date = Date()
        calculateStatistics()
    }
    
    /// Updates the state of the service player and side of the court which they are serving on.
    private mutating func updateService() {
        if currentSet.currentGame.pointsWon == [0, 0] {
            toggleServicePlayer()
        } else {
            if currentSet.currentGame.isTiebreak && currentSet.currentGame.pointsWon.sum.isOdd {
                toggleServicePlayer()
                currentSet.currentGame.serviceSide = .adCourt
            } else {
                toggleServiceCourt()
            }
        }
    }
    
    private mutating func toggleServiceCourt() {
        switch currentSet.currentGame.serviceSide {
        case .deuceCourt:
            currentSet.currentGame.serviceSide = .adCourt
        case .adCourt:
            currentSet.currentGame.serviceSide = .deuceCourt
        }
    }
    
    private mutating func toggleServicePlayer() {
        switch servicePlayer {
        case .playerOne:
            servicePlayer = .playerTwo
        case .playerTwo:
            servicePlayer = .playerOne
        case .none:
            break
        }
    }
    
    mutating func startSupertiebreak() {
        currentSet.currentGame.isTiebreak = true
        currentSet.currentGame.numberOfPointsToWin = 10
        currentSet.numberOfGamesToWin = 1
        currentSet.marginToWin = 1
    }
    
    func isChangeover() -> Bool {
        if currentSet.currentGame.isTiebreak && (currentSet.currentGame.pointsPlayed % 6 == 0) && currentSet.currentGame.pointsPlayed > 0 {
            return true
        } else if setsPlayed >= 1 &&
                  currentSet.gamesPlayed == 0 &&
                  currentSet.currentGame.pointsPlayed == 0 {
            if sets[setsPlayed - 1].gamesPlayed.isOdd {
                return true
            }
        } else if currentSet.currentGame.pointsPlayed == 0 {
            return currentSet.gamesPlayed.isOdd
        }
        return false
    }
    
    func playerWithMatchPoint() -> Player? {
        if let playerWithSetPoint = currentSet.playerWithSetPoint() {
            switch playerWithSetPoint {
            case .playerOne:
                if self.setsWon[0] == numberOfSetsToWin - 1 {
                    return .playerOne
                }
            case .playerTwo:
                if self.setsWon[1] == numberOfSetsToWin - 1 {
                    return .playerTwo
                }
            }
        }
        return nil
    }
    
    func isMatchPoint() -> Bool {
        playerWithMatchPoint() != nil ? true : false
    }
    
    mutating func undo() {
        if let previousMatch = undoStack.topItem {
            self = previousMatch
        }
    }
    
    // MARK: - Statistics
    
    func totalGamesWon(by player: Player) -> Int {
        var totalGamesWon = 0
        for set in sets {
            switch player {
            case .playerOne:
                totalGamesWon += set.gamesWon[0]
            case .playerTwo:
                totalGamesWon += set.gamesWon[1]
            }
        }
        return totalGamesWon
    }
    
    private mutating func calculateStatistics() {
        calculateServicePointsWon()
        calculateServicePointsPlayed()
        calculateBreakPointsWon()
        calculateBreakPointsPlayed()
    }
    
    private mutating func calculateServicePointsWon() {
        for point in allPointsPlayed {
            switch (point.servicePlayer, point.winner) {
            case (.playerOne, .playerOne):
                self.playerOneServicePointsWon += 1
            case (.playerTwo, .playerTwo):
                self.playerTwoServicePointsWon += 1
            default:
                break
            }
        }
    }
    
    private mutating func calculateServicePointsPlayed() {
        for point in allPointsPlayed {
            switch point.servicePlayer {
            case .playerOne:
                playerOneServicePointsPlayed += 1
            case .playerTwo:
                playerTwoServicePointsPlayed += 1
            default:
                break
            }
        }
    }
    
    private mutating func calculateBreakPointsWon() {
        for point in allPointsPlayed where point.isBreakpoint {
            switch (point.winner, point.returningPlayer) {
            case (.playerOne, .playerOne):
                playerOneBreakPointsWon += 1
            case (.playerTwo, .playerTwo):
                playerTwoBreakPointsWon += 1
            default:
                break
            }
        }
    }
    
    private mutating func calculateBreakPointsPlayed() {
        for set in sets {
            for game in set.games {
                for point in game.points where point.isBreakpoint {
                    switch (point.returningPlayer!, game.playerWithGamePoint()) {
                    case (.playerOne, .playerOne):
                        playerOneBreakPointsPlayed += 1
                    case (.playerTwo, .playerTwo):
                        playerTwoBreakPointsPlayed += 1
                    default:
                        break
                    }
                }
            }
        }
    }
}

// MARK: - Decoding
extension Match {
    enum CodingKeys: String, CodingKey {
        case setsWon = "score"
        case sets
        case date
        case format = "rulesFormat"
        case numberOfSetsToWin
        case playerOneName
        case playerTwoName
        case playerOneServicePointsPlayed
        case playerTwoServicePointsPlayed
        case playerOneServicePointsWon
        case playerTwoServicePointsWon
        case playerOneBreakPointsPlayed
        case playerTwoBreakPointsPlayed
        case playerOneBreakPointsWon
        case playerTwoBreakPointsWon
        case notes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        setsWon = try container.decode(Array.self, forKey: .setsWon)
        sets = try container.decode(Array.self, forKey: .sets)
        date = try container.decode(Date.self, forKey: .date)
        format = try container.decode(RulesFormats.self, forKey: .format)
        numberOfSetsToWin = try container.decode(Int.self, forKey: .numberOfSetsToWin)
        playerOneName = try container.decodeIfPresent(String.self, forKey: .playerOneName)
        playerTwoName = try container.decodeIfPresent(String.self, forKey: .playerTwoName)
        playerOneServicePointsPlayed = try container.decodeIfPresent(Int.self, forKey: .playerOneServicePointsPlayed)
        playerTwoServicePointsPlayed = try container.decodeIfPresent(Int.self, forKey: .playerTwoServicePointsPlayed)
        playerOneServicePointsWon = try container.decodeIfPresent(Int.self, forKey: .playerOneServicePointsWon)
        playerTwoServicePointsWon = try container.decodeIfPresent(Int.self, forKey: .playerTwoServicePointsWon)
        playerOneBreakPointsPlayed = try container.decodeIfPresent(Int.self, forKey: .playerOneBreakPointsPlayed)
        playerTwoBreakPointsPlayed = try container.decodeIfPresent(Int.self, forKey: .playerTwoBreakPointsPlayed)
        playerOneBreakPointsWon = try container.decodeIfPresent(Int.self, forKey: .playerOneBreakPointsWon)
        playerTwoBreakPointsWon = try container.decodeIfPresent(Int.self, forKey: .playerTwoBreakPointsWon)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? "Notes"
    }
}

enum MatchState: String, Codable {
    case notStarted
    case playing
    case finished
}

enum Player: String, Codable {
    case playerOne
    case playerTwo
}

enum Court: String, Codable {
    case deuceCourt
    case adCourt
}

enum SetType: String, Codable {
    case tiebreak
    case superTiebreak
    case advantage
}

struct Stack<Element: Codable & Hashable>: Codable, Hashable {
    var items = [Element]()
    
    mutating func push(_ item: Element) {
        items.append(item)
    }
    
    mutating func pop() {
        items.removeLast()
    }
    
    var topItem: Element? {
        items.isEmpty ? nil : items[items.count - 1]
    }
}

extension Int {
    var isEven: Bool  { self % 2 == 0 }
    var isOdd: Bool { !isEven }
}

extension Array where Element == Int {
    var sum: Int { return self.reduce(0, +) }
}

extension Match {
    /// Mock data.
    static func random() -> Match {
        var match = Match(format: formatData.randomElement()!)
        match.servicePlayer = .playerOne
        while match.state != .finished {
            switch Bool.random() {
            case true:
                match.scorePoint(for: .playerOne)
            case false:
                match.scorePoint(for: .playerTwo)
            }
        }
        match.stop()
        return match
    }
}
