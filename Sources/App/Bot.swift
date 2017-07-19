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
    var message : String
    var user : User
    var chatID : String
    var callBackQueryText : String
    var callBackMessageID : String
    var callBackChatID : String
    var callBackQueryID : String

    public init(token myToken:String, droplet drop:Droplet) {
        droplet = drop
        token = myToken
        
        message = ""
        chatID = ""
        callBackQueryText = ""
        callBackChatID = ""
        callBackMessageID = ""
        user = User()
        callBackQueryID = ""
    }
    

    public func processMessage(req request:Request) throws -> JSON {
        
        message = (request.data["message", "text"]?.string ?? "").lowercased()
        user = getUser(request)
        chatID = request.data["message", "chat", "id"]?.string ?? ""
        callBackQueryText = request.data["callback_query","message", "text"]?.string ?? ""
        callBackMessageID = request.data["callback_query","message","message_id"]?.string ?? ""
        callBackChatID = request.data["callback_query","message","chat","id"]?.string ?? ""
        callBackQueryID = request.data["callback_query","id"]?.string ?? ""
        
        if !callBackQueryText.isEmpty {
            let p =  getCallBackUser(request)
            if players.add(player: p) {
                return try showList(nil)
            } else {
                return try callbackAnswer(answer: "\(p.firstName), ya estás anotado 🤙🏻")
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
                if players.remove(player: p) {
                    return try showList("‼️ Se bajó \(p.completeName())")
                } else {
                    return try showList("🤦🏻‍♂️ No estás anotado, \(p.firstName)\n¡Anotate! 👇🏻")
                }
                
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

            default:
                return try JSON(node: [
                    "message": "Está vacío"])
            }
        }
    }
    
    func newList() throws -> JSON {
        let j1 = User(id: "1", firstName: "Jugador", lastName: "1", alias: "j1")
        let j2 = User(id: "2", firstName: "Jugador", lastName: "2", alias: "j2")
        let j3 = User(id: "3", firstName: "Jugador", lastName: "3", alias: "j3")
        let j4 = User(id: "4", firstName: "Jugador", lastName: "4", alias: "j4")
        let j5 = User(id: "5", firstName: "Jugador", lastName: "5", alias: "j5")
        let j6 = User(id: "6", firstName: "Jugador", lastName: "6", alias: "j6")
//        let j7 = User(id: "7", firstName: "Jugador", lastName: "7", alias: "j7")
        players = Players(list: [j1, j2, j3, j4, j5, j6], maxPlayers: 6)
        return try showList(nil)
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
    
    var players = Players(list: [], maxPlayers: 6)
    
    func showList(_ extra:String?) throws -> JSON {
        let title = players.list.count > 0 ? "Para este jueves somos *\(players.list.count)*" : "Anótensennn para jugar"
        let extraMessage = "\n\n*\(extra ?? "")*"
        let messageComplete = title + players.show() + extraMessage
        
        if !message.isEmpty {
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
            
        } else {
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
}

struct Players {
    
    var list : [User]
    var maxPlayers : Int

    mutating func add(player:User) -> Bool {
        if !list.contains(where: { $0.id == player.id }) {
            list.append(player)
            return true
        } else { return false }
    }
    
    mutating func remove(player:User) -> Bool {
        if list.contains(where: { $0.id == player.id }),
            let idx = list.index(where: { $0.id == player.id }) {
            list.remove(at: idx)
            return true
        } else { return false }
    }
    
    func show() -> String {
        var listMessage = "\n"
        for (index,player) in list.enumerated() {
            if (index + 1) == self.maxPlayers + 1 {
                listMessage.append("\n\n_Comen banco:_ \n")
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
