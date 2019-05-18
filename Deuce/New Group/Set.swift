//
//  Set.swift
//  Deuce
//
//  Created by Austin Conlon on 1/21/19.
//  Copyright © 2019 Austin Conlon. All rights reserved.
//

import Foundation

struct Set {
    var score = [0, 0]
    
    var game = Game()
    
    var games = [Game]() {
        didSet {
            game = Game()
            
            let lastServicePlayer = games.last!.servicePlayer!
            
            switch lastServicePlayer {
            case .playerOne:
                game.servicePlayer = .playerTwo
            case .playerTwo:
                game.servicePlayer = .playerOne
            }
            
            if score == [6, 6] && Set.setType == .tiebreak {
                game.isTiebreak = true
                game.tiebreakStartingServicePlayer = game.servicePlayer
            }
        }
    }
    
    static var setType: SetType = .tiebreak
    
    /// Number of games required to win the set. This is typically 6 games, but in a supertiebreak format it's 1 supertiebreakgame that replaces the 3rd set when it's tied 1 set to 1.
    var numberOfGamesToWin = 6
    
    var marginToWin: Int {
        get {
            if Set.setType == .tiebreak && (score == [7, 6] || score == [6, 7]) {
                return 1
            } else {
                return 2
            }
        }
    }
    
    var winner: Player? {
        get {
            if (score[0] >= numberOfGamesToWin) && (score[0] >= score[1] + marginToWin) {
                return .playerOne
            } else if (score[1] >= numberOfGamesToWin) && (score[1] >= score[0] + marginToWin) {
                return .playerTwo
            } else {
                return nil
            }
        }
    }
    
    var state: MatchState = .playing
    
    var isOddGameConcluded: Bool {
        get {
            if games.count % 2 == 1 {
                return true
            } else {
                return false
            }
        }
    }
    
    var isSetPoint: Bool {
        get {
            if ((score[0] >= numberOfGamesToWin - 1) && (score[0] >= score[1] + 1) && (game.score[0] >= game.numberOfPointsToWin - 1) && (game.score[0] >= game.score[1] + 1)) {
                return true
            } else if ((score[1] >= numberOfGamesToWin - 1) && (score[1] >= score[0] + 1) && (game.score[1] >= game.numberOfPointsToWin - 1) && (game.score[1] >= game.score[0] + 1)) {
                return true
            } else {
                return false
            }
        }
    }
    
    /// In an alternate match format when it's tied 1 set to 1, a 10 point "supertiebreak" game is played instead of a third set.
    var isSupertiebreak = false {
        didSet {
            if isSupertiebreak {
                numberOfGamesToWin = 1
                game.isTiebreak = true
                game.numberOfPointsToWin = 10
            }
        }
    }
    
    // MARK: Methods
    func getScore(for player: Player) -> String {
        switch player {
        case .playerOne:
            return String(self.score[0])
        case .playerTwo:
            return String(self.score[1])
        }
    }
}