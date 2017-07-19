@_exported import Vapor

extension Droplet {
    public func setup(_ bot: Bot) throws {
        try routesForBot(bot)
    }
}
