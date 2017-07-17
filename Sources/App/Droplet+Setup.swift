@_exported import Vapor

extension Droplet {
    public func setup(_ token : String) throws {
        try botRoutes(token)
    }
}
