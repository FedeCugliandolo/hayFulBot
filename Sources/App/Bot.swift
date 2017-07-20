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
    var chatID = ""
    
    // callback TODO: struct for callbacks?
    var callBackQueryText = ""
    var callBackMessageID = ""
    var callBackChatID = ""
    var callBackQueryID = ""
    var callBackQueryData = ""
    var callBackQueryDataType = CallbackType.Juego
    
    public init(token myToken:String, droplet drop:Droplet) {
        droplet = drop
        token = myToken
    }
    
    
    public func processMessage(req request:Request) throws -> JSON {
        
        message = request.data["message", "text"]?.string ?? ""
        user = getUser(request)
        chatID = request.data["message", "chat", "id"]?.string ?? ""
        
        
        callBackQueryText = request.data["callback_query","message", "text"]?.string ?? ""
        callBackMessageID = request.data["callback_query","message","message_id"]?.string ?? ""
        callBackChatID = request.data["callback_query","message","chat","id"]?.string ?? ""
        callBackQueryID = request.data["callback_query","id"]?.string ?? ""
        callBackQueryData = request.data["callback_query","data"]?.string ?? ""
        callBackQueryDataType = callBackQueryData == "cancel" ? CallbackType.Cancel : callBackQueryData.lowercased().contains("baja") ? CallbackType.Baja : CallbackType.Juego
        
        if !callBackQueryText.isEmpty { // callback Query
            
            switch callBackQueryDataType {
            
            case .Baja:
                let userData = callBackQueryData.commaSeparatedArray()
                let pID = players.list.filter { $0.id == userData[1] }
                let pCompleteName = players.list.filter { $0.completeName() == userData[2] }
                return try removePlayer(pID.count == 1 ? pID[0] : pCompleteName[0], pID.count > 1)
                
            case .Cancel:
                return try showList(nil)

            default:
                let p =  getCallBackUser(request)
                if players.add(player: p) {
                    return try showList(nil)
                } else {
                    return try callbackAnswer(answer: "\(p.firstName), ya estás anotado 🤙🏻")
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
                
            case _ where message.lowercased().contains("iniesta"):
                return try JSON(node: [
                    "method": "sendDocument",
                    "chat_id": chatID,
                    "caption": "¿¿Pidieron a Iniesta??",
                    "document": "CgADAQADZwwAAkeJSwABykG1j0MYfQoC",
                    "disable_notification": true,
                    ])
                
            case "/lista" , "/lista@hayfulbot":
                return try showList(nil)
                
            case "/nuevalista":
                return try newList()
                
            case "/mebajo":
                let p = getUser(request)
                return try removePlayer(p , nil)
                
            case _ where message.lowercased().contains("/canchade"):
                if let max = Int(message.lowercased().replacingOccurrences(of: "/canchade", with: "").trim()) {
                    players.maxPlayers = max * 2
                }
                return try self.showList("Hasta \(players.maxPlayers) titulares")
                
            case "/golazo":
                return try JSON(node: [
                    "method": "sendDocument",
                    "chat_id": chatID,
                    "caption": "¿¿Pidieron a Iniesta??",
                    "document": "CgADAQADDQADC3xwR9T4eWaEHnjMAg",
                    "disable_notification": true,
                    ])
                
            case _ where message.lowercased().hasPrefix("/juega "):
                let playersArray = message.replacingOccurrences(of: "/juega ", with: "", options: .caseInsensitive, range: message.range(of: message)).trim().commaSeparatedArray()
                if playersArray.count > 0 {
                    for p in playersArray {
                        let newPlayer = User(id: "falopa", firstName: p, lastName: "(invitado por \(getUser(request).firstName))", alias: "p")
                        players.addGuest(player: newPlayer)
                    }
                } else { return try showList("\(getUser(request).firstName) NO estás anotando a nadie 🤔") }
                return try showList("Gracias \(getUser(request).firstName) por agregar jugadores 🙌🏻")
                
            case "/baja":
                return try showBajaKeyboard()
            
            default:
                if message.hasPrefix("/") {
                    return try showList("El comando *\(message)* no existe...")
                } else {
                    return try JSON(node: [
                        "message": "Está vacío"])
                }
            }
        }
    }
    
    func newList() throws -> JSON {
//        let j1 = User(id: "1", firstName: "Jugador", lastName: "1", alias: "j1")
//        let j2 = User(id: "2", firstName: "Jugador", lastName: "2", alias: "j2")
//        let j3 = User(id: "3", firstName: "Jugador", lastName: "3", alias: "j3")
//        let j4 = User(id: "4", firstName: "Jugador", lastName: "4", alias: "j4")
//        let j5 = User(id: "5", firstName: "Jugador", lastName: "5", alias: "j5")
//        let j6 = User(id: "6", firstName: "Jugador", lastName: "6", alias: "j6")
        //        let j7 = User(id: "7", firstName: "Jugador", lastName: "7", alias: "j7")
        players = Players(list: [], maxPlayers: 12)
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
                      firstName: request.data["message","from","first_name"]?.string ?? "",
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
    
    var players = Players(list: [], maxPlayers: 12)
    
    func showList(_ extra:String?) throws -> JSON {
        let title = players.list.count > 0 ? "Para este jueves somos *\(players.list.count)*" : "Anótensennn para jugar"
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
    
    func makeCancelButton(textoAlternativo:String?) throws -> [JSON] {
        var json = JSON()
        try json.set("text", textoAlternativo ?? "Cancelar")
        try json.set("callback_data", "cancel")
        let array = [json]
        return array
    }
    
    func getPlayersJSON () throws -> [[JSON]] {
        var jsonArray = [[JSON()]]
        for p in players.list {
            jsonArray.append(try makeBajaButton(player: p))
        }
        jsonArray.remove(at: 0)
        jsonArray.insert(try makeCancelButton(textoAlternativo: "LISTO"), at: 0)
        return jsonArray
    }
}

struct Players {
    
    var list : [User]
    var maxPlayers : Int
    
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
                listMessage.append("\n\n_Pueden ir a filmar:_ \n")
            }
            listMessage.append("\n" + " \(index + 1). " + player.firstName + " " + player.lastName)
        }
        return listMessage
    }
}

struct User {
    var id : String = ""
    var firstName : String = ""
    var lastName : String = ""
    var alias:String = ""
    
    public func completeName() -> String { return "\(firstName) " + " \(lastName)" }
}

enum CallbackType: String {
    case Juego = "juego"
    case Cancel = "cancel"
    case Baja = "baja"
}
