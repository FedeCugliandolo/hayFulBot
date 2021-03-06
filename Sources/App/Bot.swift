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
    var chatID = 0
    var players = Players(chatID: 0, list: [], maxPlayers: 12, capitanes:[])
    
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
        chatID = request.data["message", "chat", "id"]?.int ?? request.data["callback_query", "message", "chat","id"]?.int ?? 0
        players.chatID = chatID
        
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
            
        case _ where callBackQueryData.contains(CallbackType.NuevaLista.rawValue):
            callBackQueryDataType = .NuevaLista
            
        default:
            callBackQueryDataType = .Juego
        }
        
        if !callBackQueryText.isEmpty { // callback Query
            
            switch callBackQueryDataType {
                
            case .Baja:
                let userData = callBackQueryData.commaSeparatedArray() // 0.baja , 1.ID, 2.name, 3.user.name
                let pID = players.list.filter { $0.id == userData[1] }
                let pCompleteName = players.list.filter { $0.completeName() == userData[2] }
                if pID.count == 1 || pCompleteName.count > 0 {
                    return try removePlayer(from: userData[3], to: pID.count == 1 ? pID[0] : pCompleteName[0], pID.count > 1)
                } else {
                    return try showList("⚠️ \(user.firstName) checá que haya quedado bien eliminado")
                }
                
            case .Cancel:
                return try showList(nil)
                
            case .Cancha:
                let callBackData = callBackQueryData.commaSeparatedArray() // 0.cancha 1.maxPlayers
                players.maxPlayers = (Int(callBackData[1])!) * 2
                return try self.showList("Hasta \(players.maxPlayers) titulares")
                
            case .Capitanes:
                let userData = callBackQueryData.commaSeparatedArray() // 0.capitanes, 1.answer
                if userData[1] == "Si" {
                    players.capitanes = []
                    return try processCaptains()
                } else {
                    return try showList(nil)
                }
                
            case .NuevaLista:
                let userData = callBackQueryData.commaSeparatedArray() // 0.Si , 1.nuevalista
                guard userData[1] == "Si" else { return try showList(nil) }
                return try newList()
                
            default: // .Juego
                if players.add(player: callBackUser) {
                    return try showList(nil)
                } else {
                    return try callbackAnswer(answer: "\(callBackUser.firstName), ya estás anotado 🤙🏻")
                }
            }
            
        } else {
            
            switch message {
                
            case _ where message.lowercased().hasPrefix("/lista"):
                return try showList(nil)
                
            case _ where message.lowercased().hasPrefix("/nuevalista"):
                guard players.list.count > 0 else {
                    return try newList()
                }
                return try showOneRowKeyboard(withQuestion: "\(user.firstName), estás por borrar toda la lista...\n\n*⚠️⚠️ ¿¿Estás seguro?? ⚠️⚠️*", options: ["Si", "No"], action: .NuevaLista)
                
            case _ where message.lowercased().hasPrefix("/canchade"):
                return try showOneRowKeyboard(withQuestion: "¿Cantidad de jugadores por equipo?", options: [5,6,8,11], action: .Cancha)
                
            case let command where message.lowercased().hasPrefix("/golazo"):
                return try sendGIFsFor(command)
                
            case _ where message.lowercased().hasPrefix("/juega "):
                return try addPlayers()
                
            case _ where message.lowercased().hasPrefix("/mebajo"):
                return try removePlayer(from: user.firstName, to: user, nil)
                
            case _ where message.lowercased().hasPrefix("/baja"):
                return try showBajaKeyboard()
                
            case _ where message.lowercased().hasPrefix("/capitanes"):
                return try processCaptains()
                
            case _ where message.lowercased().hasPrefix("/nuevoscapitanes"):
                if players.capitanes.count > 0 {
                    return try askForNewCaptains(nil)
                } else {
                    return try processCaptains()
                }
                
            case let commnad where message.lowercased().contains("iniesta"):
                return try sendGIFsFor(commnad)
                
            case _ where message.lowercased().hasPrefix("/messageall"):
                return try sendMessage(chatID)
                
            case _ where message.lowercased().hasPrefix("/messagehere"):
                return try sendMessage(chatID)
                
            default:
                if message.hasPrefix("/") {
                    return try showList("⚠️ \(user.firstName), ese comado no existe...")
                } else {
                    return try doNothing()
                }
            }
        }
    }
    
    func sendMessage(_ chatID: Int) throws -> JSON {
        let text = message.replacingOccurrences(of: "/messageall ",
                                                with: "",
                                                options: .caseInsensitive,
                                                range: message.range(of: message)).trim()
        
        return try JSON(node: [
            "method": "sendMessage",
            "chat_id": chatID,
            "text": text,
            "parse_mode": "Markdown"
            ])
    }
    
    func addPlayers() throws -> JSON {
        let playersArray = message.replacingOccurrences(of: "/juega ",
                                                        with: "",
                                                        options: .caseInsensitive,
                                                        range: message.range(of: message)).trim().commaSeparatedArray()
        if playersArray.count > 0 {
            for p in playersArray {
                guard p.trim() != "" else {continue}
                let newPlayer = User("falopa", firstName: p, lastName: "·", alias: p + "Guest", chatID: chatID)
                players.addGuest(player: newPlayer)
            }
        } else { return try showList("\(user.firstName) NO estás anotando a nadie 🤔") }
        return try showList("Gracias \(user.firstName) por agregar jugadores 🙌🏻")
    }
    
    func doNothing() throws -> JSON {
        return try JSON(node: [
            "message": "Está vacío"]
        )
    }
    
    func muyPronto() throws -> JSON {
        return try JSON(node: [
            "method": "sendMessage",
            "chat_id": chatID,
            "text": "HayFulBot estará activo muy pronto para usarlo públicamente... ⚽️",
            ])
    }
    
    
    func sendGIFsFor(_ command: String) throws -> JSON {
        let GIFs = [(key: "iniesta", caption: "¿Pidieron a Iniesta?", file: "CgADAQADZwwAAkeJSwABykG1j0MYfQoC"),
                    (key: "golazo", caption: "¡Golazo de Iniesta!", file: "CgADAQADDQADC3xwR9T4eWaEHnjMAg")]
        let idx = GIFs.index(where: { command.lowercased().contains($0.key) })
        
        guard idx != nil else { return try doNothing() }
        return try JSON(node: [
            "method": "sendDocument",
            "chat_id": chatID,
            "caption": GIFs[idx!].caption,
            "document": GIFs[idx!].file,
            "disable_notification": true,
            ])
    }
    
    func askForNewCaptains(_ question: String?) throws -> JSON {
        let questionMessage = question ?? "Capitanes actuales:\n\n\(players.showCaptains())\n\n¿Reasignar capitanes?"
        return try showOneRowKeyboard(withQuestion: questionMessage, options: ["Si", "No"], action: .Capitanes)
    }
    
    func processCaptains() throws -> JSON {
        if players.setCapitanes() || players.capitanes.count == 2  {
            return try showList("\(user.firstName), los capitanes son:\n\n" + players.showCaptains())
        } else {
            return try showList("\(user.firstName), falta completar la lista de titulares para sortear *_capitanes_*")
        }
    }
    
    func newList() throws -> JSON {
        players.list = []
        players.capitanes = []
        return try showList(nil)
    }
    
    func removePlayer(from userName: String, to player:User, _ byName: Bool?) throws -> JSON {
        let indexBaja = players.list.index(where: { $0.completeName() == player.completeName() })
        if players.remove(player: player, byName) {
            
            var bajaMessage = ""
            
            // check for suplente
            if players.list.count >= players.maxPlayers, indexBaja! <= players.maxPlayers - 1 {
                let firstSuplente = players.list[players.maxPlayers - 1]
                bajaMessage.append(firstSuplente.alias.hasSuffix("Guest") || firstSuplente.alias == "" ?  "Avisenlé a \(firstSuplente.firstName) que juega...\n\n"
                    : "*@\(firstSuplente.alias)* confirmá si podés jugar.\nEstás activo, perrro!.\n\n")
            }
            
            // check for captain
            if players.isCaptain(player).answer {
                players.capitanes = []
                bajaMessage.append("¡Se bajó un Capitán! \nA reasignarlos 👨🏿‍✈️👨🏻‍✈️\n\n")
                
            }
            bajaMessage.append(userName == player.firstName ? "‼️ Se bajó \(player.completeName())" : "‼️ \(userName) bajó a \(player.completeName())")
            return try showList(bajaMessage)
            
        } else {
            return try showList("🤦🏻‍♂️ No estás anotado, \(player.firstName)\n¡Anotate! 👇🏻")
        }
    }
    
    func getUser (_ request:Request) -> User {
        let u = User (request.data["message","from","id"]?.string ?? "",
                      firstName: request.data["message","from","first_name"]?.string ?? request.data["callback_query","from","first_name"]?.string ?? "",
                      lastName: request.data["message","from","last_name"]?.string ?? "",
                      alias: request.data["message","from","username"]?.string ?? "",
                      chatID: chatID)
        return u
    }
    
    func getCallBackUser (_ request:Request) -> User {
        let u = User (request.data["callback_query","from","id"]?.string ?? "",
                      firstName: request.data["callback_query","from","first_name"]?.string ?? "",
                      lastName: request.data["callback_query","from","last_name"]?.string ?? "",
                      alias: request.data["callback_query","from","username"]?.string ?? "",
                      chatID: chatID)
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
        try json.set("callback_data", "baja,\(player.id),\(player.completeName()),\(user.firstName)")
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
        try json.set("callback_data", "\(data.0.rawValue),\(data.1)")
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
}
