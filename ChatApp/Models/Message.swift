//
//  Message.swift
//  ChatApp
//
//  Created by Mohamed Hashem on 7/17/20.
//  Copyright © 2020 Mohamed Hashem. All rights reserved.
//

import MessageKit
import CoreLocation

struct Message: MessageType {
    
    var sender: SenderType
    
    var messageId: String
    
    var sentDate: Date
    
    var kind: MessageKind
    
    var state: MessageState = .written

}

enum MessageState: String {
    case written, sent, delivered, read
}


struct Sender: SenderType {
    
    var displayName: String

    var senderId: String
    
    init?(user: ChatAppUser) {
        self.displayName = user.fullName
        self.senderId = user.uid
    }
    
    init(displayName: String, senderId: String) {
        self.displayName = displayName
        self.senderId = senderId
    }
    
}

struct MessageMedia: MediaItem {
    var url: URL?
    
    var image: UIImage?
    
    var placeholderImage: UIImage
    
    var size: CGSize
    
    var caption: String?
}

struct MessageAudio: AudioItem {
    var size: CGSize
    
    var url: URL
    
    var duration: Float
}


struct MessageLocation: LocationItem {
    var location: CLLocation
    
    var size: CGSize
}
