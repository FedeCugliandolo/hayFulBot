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
    var callBackQuery : String
    var callBackMessageID : String
    var callBackChatID : String

    public init(token myToken:String, droplet drop:Droplet) {
        droplet = drop
        token = myToken
        
        message = ""
        chatID = ""
        callBackQuery = ""
        callBackChatID = ""
        callBackMessageID = ""
        user = User()
    }
    

    public func processMessage(req request:Request) throws -> JSON {
        
        message = (request.data["message", "text"]?.string ?? "").lowercased()
        user = getUser(request)
        chatID = request.data["message", "chat", "id"]?.string ?? ""
        callBackQuery = request.data["callback_query","message", "text"]?.string ?? ""
        callBackMessageID = request.data["callback_query","message","message_id"]?.string ?? ""
        callBackChatID = request.data["callback_query","message","chat","id"]?.string ?? ""
        
        if !callBackQuery.isEmpty {
            players.add(player: getCallBackUser(request))

            //                return try JSON(node: [
            //                    "method": "sendMessage",
            //                    "chat_id": self.chatID,
            //                    "text": "\(self.user.firstName), tené paciencia que ya llega la lista 2.0 ⚽️. #FPF",
            //                    ])

            return try showList()
        
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
                return try showList()
                
            case "/nuevalista":
                return try newList()
            
            case "/mebajo":
                players.remove(player: getUser(request))
                return try showList()
                
            case _ where message.lowercased().contains("/canchade"):
                if let max = Int(message.lowercased().replacingOccurrences(of: "/canchade", with: "").trim()) {
                    players.maxPlayers = max * 2
                }
                self.droplet.post(self.token) { request in
                    return try self.showList()
                }
                
                return try JSON(node: [
                    "method": "sendMessage",
                    "chat_id": chatID,
                    "text": "Ahora jugamos \(players.maxPlayers)",
                    ])
                
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
        let j7 = User(id: "7", firstName: "Jugador", lastName: "7", alias: "j7")
        players = Players(list: [j1, j2, j3, j4, j5, j6, j7], maxPlayers: 10)
        return try showList()
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
    
    var players = Players(list: [], maxPlayers: 10)
    
    func showList() throws -> JSON {
        let title = players.list.count > 0 ? "Para este jueves somos:" : "Anótensennn para jugar"
        let messageComplete = title + players.show()
        
        if !message.isEmpty {
        return try JSON(node: [
            "method": "sendMessage",
            "chat_id": chatID,
            "text": messageComplete,
            "reply_markup": try JSON(node: [
                "inline_keyboard": try JSON (node: [
                    try JSON (node: [
                        try JSON (node: [
                            "text": "Juego! ⚽️",
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
                "reply_markup": try JSON(node: [
                    "inline_keyboard": try JSON (node: [
                        try JSON (node: [
                            try JSON (node: [
                                "text": "Juego! ⚽️",
                                "callback_data": "juego"
                                ]),
                            ])
                        ])
                    ]),
                ])
        }
    }
}

struct Players {
    
    var list : [User]
    var maxPlayers : Int

    mutating func add(player:User) {
        if !list.contains(where: { $0.id == player.id }) {
            list.append(player)
        } else {
            // TODO: mensaje para el que se re-anota
            print("Ya está en la lista")
        }
    }
    
    mutating func remove(player:User) {
        if list.contains(where: { $0.id == player.id }),
            let idx = list.index(where: { $0.id == player.id }) {
            list.remove(at: idx)
        }
    }
    
    func show() -> String {
        var listMessage = "\n"
        for (index,player) in list.enumerated() {
            if (index + 1) == self.maxPlayers + 1 {
                listMessage.append("\n\nComen banco:\n")
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
}
