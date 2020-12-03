//
//  ChatAppUser.swift
//  ChatApp
//
//  Created by Mohamed Hashem on 7/15/20.
//  Copyright © 2020 Mohamed Hashem. All rights reserved.
//

import Foundation
import MessageKit

struct ChatAppUser: Equatable {
    
    static func == (lhs: ChatAppUser, rhs: ChatAppUser) -> Bool {
        return lhs.uid == rhs.uid
    }
    
    var email: String
    var fullName: String
    var uid: String
    var imageURL: String?
    var contacts = [String]()
    var chats: [String]?
    var status: UserStatus?
    
    init?(uid: String, data: [AnyHashable: Any]) {
        if let email = data["email"] as? String, let fullName = data["fullName"] as? String {
            self.email = email
            self.fullName = fullName
            self.uid = uid
            if let imageURL = data["imageURL"] as? String { self.imageURL = imageURL }
            if let userContacts = data["contacts"] as? NSArray {
                userContacts.forEach { self.contacts.append($0 as! String) }
            }
            if let chatData = data["chats"] as? [String: Any] {
                var foundChats = [String]()
                for chat in chatData.keys {
                    foundChats.append(chat)
                }
                self.chats = foundChats
            }
        } else {
            print("ERROR: CORRUPT USER DATA")
            return nil
        }
    }
    
    
    init(email: String, fullName: String, uid: String, imageURL: String? = nil, contacts: [String]? = nil) {
        self.email = email
        self.fullName = fullName
        self.uid = uid
        if let url = imageURL { self.imageURL = url }
        if let contacts = contacts { self.contacts = contacts }
    }
    
}

extension ChatAppUser: SenderType {
    
    var senderId: String {
        return uid
    }
    
    var displayName: String {
        return fullName
    }
}

enum UserStatus: String {
    case online, typing, recordingAudio, offline
}
