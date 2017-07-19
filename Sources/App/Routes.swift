import Vapor

extension Droplet {
    func routesForBot(_ bot:Bot) throws {
        post(bot.token) { request in
            return try bot.processMessage(req:request)
        }
    }
}
