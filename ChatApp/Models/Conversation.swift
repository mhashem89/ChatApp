//
//  Conversation.swift
//  ChatApp
//
//  Created by Mohamed Hashem on 7/19/20.
//  Copyright © 2020 Mohamed Hashem. All rights reserved.
//

import Foundation

struct Conversation: Equatable {
    
    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        return lhs.uid == rhs.uid
    }
    
    
    var users: [ChatAppUser]
    
    var messages: [Message]
    
    let uid: String
    
}
