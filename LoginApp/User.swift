//
//  User.swift
//  LoginApp
//
//  Created by Jatin Gupta on 2025-09-11.
//


import Foundation

struct User: Codable {
    let username: String
    let password: String
    let token: String
    let email: String?
}


