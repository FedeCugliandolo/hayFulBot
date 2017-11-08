//
//  Model.swift
//  hayFulBot
//
//  Created by Fede Cugliandolo on 8/1/17.
//
//

import Foundation
import FluentProvider

struct Data {
    var lists: [Int : [User]]
    var captains: [Int : [Captain]]
    var maxPlayers: [Int : Int]
}

struct Players {
    
    var list: [User] {
        get {
            return data.lists[chatID] ?? []
        }
        set (newList) {
            data.lists[chatID] = newList
        }
    }
    
    var maxPlayers: Int {
        get {
            return data.maxPlayers[chatID] ?? 10
        }
        set {
            data.maxPlayers[chatID] = newValue
        }
    }
    
    var capitanes : [Captain] {
        get {
            return data.captains[chatID] ?? []
        }
        set {
            data.captains[chatID] = newValue
        }
    }
    
    var chatID: Int
    
    private var data : Data
    
    init(chatID: Int, list: [User], maxPlayers: Int, capitanes : [Captain] = [Captain(team: .none,user: User(), chatID: 0)]) {
        self.chatID = chatID
        self.data = Data(lists: [chatID : list], captains: [chatID : capitanes], maxPlayers: [chatID : maxPlayers])
    }
    
    func areComplete () -> Bool { return list.count >= maxPlayers }
    
    mutating func addGuest(player: User) { list.append(player) }
    
    mutating func add(player:User) -> Bool {
        if !list.contains(where: { $0.id == player.id }) {
            list.append(player)
            return true
        } else { return false }
    }
    
    mutating func remove(player:User, _ byName: Bool?) -> Bool {
        if list.contains(where: { byName == true ? $0.completeName() == player.completeName() : $0.id == player.id }),
            let idx = list.index(where: { byName == true ? $0.completeName() == player.completeName() : $0.id == player.id }) {
            list.remove(at: idx)
            return true
        } else { return false }
    }
    
    func show() -> String {
        var listMessage = "\n"
        for (index,player) in list.enumerated() {
            if (index + 1) == self.maxPlayers + 1 {
                listMessage.append("\n\n_Pueden ir a filmar:_\n")
            }
            let captainTeam =  isCaptain(player).answer ? "©️\(isCaptain(player).team)": ""
            listMessage.append("\n \(index + 1). \(player.firstName) \(player.lastName) \(captainTeam)")
        }
        return listMessage
    }
    
    mutating func setCapitanes() -> Bool {
        guard areComplete() && capitanes.count == 0 else { return false }
        
        let capitanNegro = list[Int.random(min: 0, max: maxPlayers - 1)]
        var capitanBlanco = list[Int.random(min: 0, max: maxPlayers - 1)]
        while list.count > 1 && capitanNegro.alias == capitanBlanco.alias {
            capitanBlanco = list[Int.random(min: 0, max: maxPlayers - 1)]
        }
        
        capitanes = [Captain.init(team: .negro, user: capitanNegro, chatID: chatID),
                     Captain.init(team: .blanco, user: capitanBlanco, chatID: chatID)]
        return true
    }
    
    func showCaptains() -> String {
        return "\(capitanes[0].team.rawValue) \(capitanes[0].user.firstName) \n\(capitanes[1].team.rawValue) \(capitanes[1].user.firstName)"
    }
    
    func isCaptain(_ player: User) -> (answer: Bool, team: Team.RawValue) {
        guard capitanes.count > 0 else { return (false, Team.none.rawValue) }
        let cap = capitanes.filter({ $0.user.completeName() == player.completeName() })
        return (capitanes.contains(where: { $0.user.completeName() == player.completeName()}),
                cap.count > 0 ? cap[0].team.rawValue : Team.none.rawValue )
    }
}

struct User {
    var id: String
    var firstName: String
    var lastName: String
    var alias: String
    var chatID: Int
    
    public func completeName() -> String { return "\(firstName) " + " \(lastName)" }
    
    init(row: Row) throws {
        id = try row.get("id")
        firstName = try row.get("firstName")
        lastName = try row.get("lastName")
        alias = try row.get("alias")
        chatID = try row.get("chatID")
    }
    
    init(_ id: String = "", firstName: String = "", lastName: String = "", alias: String = "", chatID: Int = 0) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.alias = alias
        self.chatID = chatID
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set("id", id)
        try row.set("firstName", firstName)
        try row.set("lastName", lastName)
        try row.set("alias", alias)
        try row.set("chatID", chatID)
        return row
    }

}

enum CallbackType: String {
    case Juego = "juego"
    case Cancel = "cancel"
    case Baja = "baja"
    case Cancha = "cancha"
    case Capitanes = "capitanes"
    case NuevaLista = "nuevalista"
}

enum Team : String {
    case none = ""
    case negro = "👨🏿‍✈️"
    case blanco = "👨🏻‍✈️"
}

final class Captain: Model {
    var team : Team = .none
    var user = User()
    var chatID : Int = 0
    let storage = Storage()
    
    init(team: Team, user: User, chatID: Int) {
        self.team = team
        self.user = user
        self.chatID = chatID
    }
    
    init(row: Row) throws {
        team = try row.get("team")
        user = try row.get("user")
        chatID = try row.get("cahtID")
    }
    
    func makeRow() throws -> Row {
        var row = Row()
        try row.set("team", team)
        try row.set("user", user)
        try row.set("chatID", chatID)
        return row
    }
    
}
