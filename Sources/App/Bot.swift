//
//  Bot.swift
//  hayFulBot
//
//  Created by Fede Cugliandolo on 7/16/17.
//
//

import Vapor

public class Bot {
    var hello : String
    init(_ texto: String, droplet drop:Droplet) {
        hello = texto
    }
}
