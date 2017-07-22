//
//  Bot.swift
//  hayFulBot
//
//  Created by Fede Cugliandolo on 7/16/17.
//
//

import Vapor

public class Bot {
    var droplet : Droplet
    var token: String
    var message = ""
    var user = User()
    var chatID  = ""
    var players = Players(list: [], maxPlayers: 12, capitanes:[])
    
    // callback TODO: struct for callbacks?
    var callBackQueryText = ""
    var callBackMessageID = ""
    var callBackChatID = ""
    var callBackQueryID = ""
    var callBackQueryData = ""
    var callBackQueryDataType = CallbackType.Juego
    var callBackUser = User()
    
    public init(token myToken:String, droplet drop:Droplet) {
        droplet = drop
        token = myToken
    }
    
    public func processMessage(req request:Request) throws -> JSON {
        
        message = request.data["message", "text"]?.string ?? ""
        user = getUser(request)
        chatID = request.data["message", "chat", "id"]?.string ?? ""
        
        callBackUser = getCallBackUser(request)
        callBackQueryText = request.data["callback_query","message", "text"]?.string ?? ""
        callBackMessageID = request.data["callback_query","message","message_id"]?.string ?? ""
        callBackChatID = request.data["callback_query","message","chat","id"]?.string ?? ""
        callBackQueryID = request.data["callback_query","id"]?.string ?? ""
        callBackQueryData = request.data["callback_query","data"]?.string ?? ""
        
        switch callBackQueryData {
        
        case _ where callBackQueryData.contains(CallbackType.Baja.rawValue):
            callBackQueryDataType = .Baja
            
        case _ where callBackQueryData.contains(CallbackType.Cancel.rawValue):
            callBackQueryDataType = .Cancel
            
        case _ where callBackQueryData.contains(CallbackType.Cancha.rawValue):
            callBackQueryDataType = .Cancha
            
        case _ where callBackQueryData.contains(CallbackType.Capitanes.rawValue):
            callBackQueryDataType = .Capitanes
            
        default:
            callBackQueryDataType = .Juego
        }
        
        if !callBackQueryText.isEmpty { // callback Query
            
            switch callBackQueryDataType {
            
            case .Baja:
                let userData = callBackQueryData.commaSeparatedArray() // 0.baja , 1.ID, 2.name
                let pID = players.list.filter { $0.id == userData[1] }
                let pCompleteName = players.list.filter { $0.completeName() == userData[2] }
                if pID.count == 1 || pCompleteName.count > 0 {
                    return try removePlayer(pID.count == 1 ? pID[0] : pCompleteName[0], pID.count > 1)
                } else {
                    return try showList("⚠️ \(user.firstName) checá que haya quedado bien eliminado")
                }
                
            case .Cancel:
                return try showList(nil)

            case .Cancha:
                players.maxPlayers = (Int (callBackQueryData.replacingOccurrences(of: CallbackType.Cancha.rawValue, with: ""))!) * 2
                return try self.showList("Hasta \(players.maxPlayers) titulares")
                
            case .Capitanes:
                if (callBackQueryData.replacingOccurrences(of: CallbackType.Capitanes.rawValue, with: "")) == "Si" {
                    players.capitanes = []
                }
                return try processCaptains()
                
            default: // .Juego
                if players.add(player: callBackUser) {
                    return try showList(nil)
                } else {
                    return try callbackAnswer(answer: "\(callBackUser.firstName), ya estás anotado 🤙🏻")
                }
            }
            
        } else {
            
            switch message {
                
            case "/hola":
                return try JSON(node: [
                    "method": "sendMessage",
                    "chat_id": chatID,
                    "text": "Hola @\(user.alias)! Bienvenido a HayFulBot =)",
                    ])
                
            case "/lista" , "/lista@hayfulbot":
                return try showList(nil)
                
            case "/nuevalista":
                return try newList()
                
            case "/mebajo":
                return try removePlayer(user , nil)
                
            case _ where message.lowercased().hasPrefix("/canchade"):
                return try showOneRowKeyboard(withQuestion: "¿De cuánto es la cancha?", options: [5,6,8,11], action: .Cancha)
                
            case "/golazo":
                return try JSON(node: [
                    "method": "sendDocument",
                    "chat_id": chatID,
                    "caption": "¿¿Pidieron a Iniesta??",
                    "document": "CgADAQADDQADC3xwR9T4eWaEHnjMAg",
                    "disable_notification": true,
                    ])
                
            case _ where message.lowercased().hasPrefix("/juega "):
                let playersArray = message.replacingOccurrences(of: "/juega ",
                                                                with: "",
                                                                options: .caseInsensitive,
                                                                range: message.range(of: message)).trim().commaSeparatedArray()
                if playersArray.count > 0 {
                    for p in playersArray {
                        guard p.trim() != "" else {continue}
                        let newPlayer = User(id: "falopa", firstName: p, lastName: "·", alias: p + "Guest")
                        players.addGuest(player: newPlayer)
                    }
                } else { return try showList("\(user.firstName) NO estás anotando a nadie 🤔") }
                return try showList("Gracias \(user.firstName) por agregar jugadores 🙌🏻")
                
            case "/baja":
                return try showBajaKeyboard()
                
            case "/capitanes":
                return try processCaptains()
            
            case _ where message.lowercased().hasPrefix("/nuevoscapitanes"):
                if players.capitanes.count > 0 {
                    return try showOneRowKeyboard(withQuestion: "Capitanes acutales:\n\(players.showCaptains())\n\n¿Reasignar capitanes?", options: ["Si", "No"], action: .Capitanes)
                } else {
                    return try processCaptains()
                }
                
            case _ where message.lowercased().contains("iniesta"):
                return try JSON(node: [
                    "method": "sendDocument",
                    "chat_id": chatID,
                    "caption": "¿¿Pidieron a Iniesta??",
                    "document": "CgADAQADZwwAAkeJSwABykG1j0MYfQoC",
                    "disable_notification": true,
                    ])
            
            default:
                if message.hasPrefix("/") {
                    return try showList("\(user.firstName), ese comado no existe...")
                } else {
                    return try JSON(node: [
                        "message": "Está vacío"])
                }
            }
        }
    }
    
    func processCaptains() throws -> JSON {
        if setCapitanes() || players.capitanes.count > 0  {
            return try showList("\(user.firstName), los capitanes son:\n" + players.showCaptains())
        } else {
            return try showList("\(user.firstName), falta completar la lista de titulares para sortear *_capitanes_*")
        }
    }
    
    func newList() throws -> JSON {
        players = Players(list: [], maxPlayers: 12,  capitanes:[])
        return try showList(nil)
    }
    
    func removePlayer(_ player:User, _ byName: Bool?) throws -> JSON {
        if players.remove(player: player, byName) {
            return try showList("‼️ Se bajó \(player.completeName())")
        } else {
            return try showList("🤦🏻‍♂️ No estás anotado, \(player.firstName)\n¡Anotate! 👇🏻")
        }
    }
    
    func getUser (_ request:Request) -> User {
        let u = User (id: request.data["message","from","id"]?.string ?? "",
                      firstName: request.data["message","from","first_name"]?.string ?? request.data["callback_query","from","first_name"]?.string ?? "",
                      lastName: request.data["message","from","last_name"]?.string ?? "",
                      alias: request.data["message","from","username"]?.string ?? "")
        return u
    }
    
    func getCallBackUser (_ request:Request) -> User {
        let u = User (id: request.data["callback_query","from","id"]?.string ?? "",
                      firstName: request.data["callback_query","from","first_name"]?.string ?? "",
                      lastName: request.data["callback_query","from","last_name"]?.string ?? "",
                      alias: request.data["callback_query","from","username"]?.string ?? "")
        return u
    }
    
    func showList(_ extra:String?) throws -> JSON {
        let title = players.list.count > 0 ? "Para este jueves somos *\(players.list.count)*" : "_...No somos nadie... 👨🏻‍🎤_\n\n👇🏻 ¡Anotémosnos para jugar! 👇🏻"
        let extraMessage = "\n\n*\(extra ?? "")*"
        let messageComplete = title + players.show() + extraMessage
        
        if !message.isEmpty { // mensaje comun
            return try JSON(node: [
                "method": "sendMessage",
                "chat_id": chatID,
                "text": messageComplete,
                "parse_mode": "Markdown",
                "reply_markup": try JSON(node: [
                    "inline_keyboard": try JSON (node: [
                        try JSON (node: [
                            try JSON (node: [
                                "text": "⚽️ ¡Juego!",
                                "callback_data": "juego"
                                ]),
                            ])
                        ])
                    ])
                ])
            
        } else { //calback query
            
            return try JSON(node: [
                "method": "editMessageText",
                "chat_id": self.callBackChatID,
                "message_id": self.callBackMessageID,
                "text": messageComplete,
                "parse_mode": "Markdown",
                "reply_markup": try JSON(node: [
                    "inline_keyboard": try JSON (node: [
                        try JSON (node: [
                            try JSON (node: [
                                "text": "⚽️ ¡Juego!",
                                "callback_data": "juego"
                                ]),
                            ])
                        ])
                    ]),
                ])
            
        }
    }
    
    func callbackAnswer(answer:String) throws -> JSON {
        return try JSON(node: [
            "method": "answerCallbackQuery",
            "callback_query_id": callBackQueryID,
            "text": answer,
            "show_alert": true
            ])
    }
    
    func showBajaKeyboard() throws -> JSON {
        return try JSON(node: [
            "method": "sendMessage",
            "chat_id": chatID,
            "text": "¿Quién se baja?",
            "parse_mode": "Markdown",
            "reply_markup": try JSON(node: [
                "inline_keyboard": try getPlayersJSON()
                ])
            ])
    }
    
    func makeBajaButton(player:User) throws -> [JSON] {
        var json = JSON()
        try json.set("text", player.completeName())
        try json.set("callback_data", "baja,"+"\(player.id),"+"\(player.completeName())")
        let array = [json]
        return array
    }
    
    func makeCancelButton(_ textoAlternativo:String?) throws -> [JSON] {
        var json = JSON()
        try json.set("text", textoAlternativo ?? "Cancelar")
        try json.set("callback_data", "cancel")
        let array = [json]
        return array
    }
    
    func showOneRowKeyboard(withQuestion question: String, options: [Any], action:CallbackType) throws -> JSON {
        return try JSON(node: [
            "method": "sendMessage",
            "chat_id": chatID,
            "text": question,
            "parse_mode": "Markdown",
            "reply_markup": try JSON(node: [
                "inline_keyboard": try JSON(node: [
                    try getInlineKeyboardOptions(options, callbakType: action)
                    ])
                ])
            ])
    }
    
    func getInlineKeyboardOptions(_ options: [Any], callbakType: CallbackType) throws -> [JSON] {
        var jsonArray = [JSON()]
        for op in options {
            jsonArray.append( try makeInlineKeyboardButton(text:"\(op)", data: (callbakType, "\(op)")))
        }
        jsonArray.remove(at: 0)
        return jsonArray
    }
    
    func makeInlineKeyboardButton(text: String, data: (CallbackType, String)) throws -> JSON {
        var json = JSON()
        try json.set("text", text)
        try json.set("callback_data", "\(data.0.rawValue)\(data.1)")
        return json
    }
    
    func getPlayersJSON () throws -> [[JSON]] {
        var jsonArray = [[JSON()]]
        for p in players.list {
            jsonArray.append(try makeBajaButton(player: p))
        }
        jsonArray.remove(at: 0)
        jsonArray.insert(try makeCancelButton(nil), at: 0)
        return jsonArray
    }
    
    func setCapitanes() -> Bool {
        guard players.areComplete() && players.capitanes.count == 0 else { return false }
        
        let capitanNegro = players.list[Int.random(min: 0, max: players.maxPlayers - 1)]
        var capitanBlanco = players.list[Int.random(min: 0, max: players.maxPlayers - 1)]
        while players.list.count > 1 && capitanNegro.alias == capitanBlanco.alias {
            capitanBlanco = players.list[Int.random(min: 0, max: players.maxPlayers - 1)]
        }
        
        players.capitanes = [Captain.init(team: .negro, user: capitanNegro),
                     Captain.init(team: .blanco, user: capitanBlanco)]
        return true
    }
}

struct Players {
    
    var list : [User]
    var maxPlayers : Int
    var capitanes = [Captain()]
    
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
            listMessage.append("\n" + " \(index + 1). " + player.firstName + " " + player.lastName)
        }
        return listMessage
    }
    
    func showCaptains() -> String {
        return "\(capitanes[0].team.rawValue) \(capitanes[0].user.firstName) \n\(capitanes[1].team.rawValue) \(capitanes[1].user.firstName)"
    }
}

struct User {
    var id = ""
    var firstName = ""
    var lastName = ""
    var alias = ""
    
    public func completeName() -> String { return "\(firstName) " + " \(lastName)" }
}

enum CallbackType: String {
    case Juego = "juego"
    case Cancel = "cancel"
    case Baja = "baja"
    case Cancha = "cancha"
    case Capitanes = "capitanes"
}

enum Team : String {
    case none = ""
    case negro = "👨🏿‍✈️"
    case blanco = "👨🏻‍✈️"
}

public struct Captain {
    var team : Team = .none
    var user = User()
}
