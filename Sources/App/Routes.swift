import Vapor

//extension Droplet {
//    func setupRoutes() throws {
//        get("hello") { req in
//            var json = JSON()
//            try json.set("hello", "world")
//            return json
//        }
//
//        get("plaintext") { req in
//            return "Hello, world!"
//        }
//
//        // response to requests to /info domain
//        // with a description of the request
//        get("info") { req in
//            return req.description
//        }
//
//        get("description") { req in return req.description }
//        
//        try resource("posts", PostController.self)
//    }
//}



extension Droplet {
    func botRoutes(_ token: String) throws {
        post(token) { request in
            let message = request.data["message", "text"]?.string ?? ""
            let username = request.data["message","from","username"]?.string ?? request.data["message","from","first_name"]!.string ?? "_user_"
            let firstName = request.data["message","from","first_name"]!.string ?? "_firstName_"
            let chatID: Int = request.data["message", "chat", "id"]?.int ?? 0
//            let document = request.data["message", "document", "file_id"]?.string ?? ""
//            let documentName = request.data["message", "document", "file_name"]?.string ?? ""
            
            
            if !message.isEmpty {
                switch message {
                case "/hola":
                    return try JSON(node: [
                         "method": "sendMessage",
                        "chat_id": chatID,
                        "text": "Hola @\(username) Bienvenido nuevamente a HayFulBot =)",
                        ])
                case _ where message.lowercased().contains("iniesta"):
                    let bot = Bot("¿¿Pidieron a Iniesta??", droplet: self)
                    return try JSON(node: [
                        "method": "sendDocument",
                        "chat_id": chatID,
                        "caption": bot.hello,
                        "document": "CgADAQADZwwAAkeJSwABykG1j0MYfQoC",
                        "disable_notification": true,
                        ])
                case "/lista":
                    return try JSON(node: [
                        "method": "sendMessage",
                        "chat_id": chatID,
                        "text": "\(firstName), tené paciencia que ya llega la lista 2.0 ⚽️. #FPF",
                        ])
                default:
                    return try JSON(node: [
                        "message": "Está vacío"])
                }
                //            } else if message.lowercased().contains("iniesta") {
                //                let bot = Bot("¿¿Pidieron a Iniesta??", droplet: self)
                //                return try JSON(node: [
                //                    "method": "sendDocument",
                //                    "chat_id": chatID,
                //                    "caption": bot.hello,
                //                    "document": "CgADAQADZwwAAkeJSwABykG1j0MYfQoC",
                //                    "disable_notification": true,
                //                    ])
                //            } else {
                //                return try JSON(node: [
                //                    "message": "Está vacío"])
                //            }
            } else {
                return try JSON(node: [
                    "message": "Está vacío"])
            }
        }
    }
}
