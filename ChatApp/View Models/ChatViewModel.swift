//
//  ChatViewModel.swift
//  ChatApp
//
//  Created by Mohamed Hashem on 8/16/20.
//  Copyright © 2020 Mohamed Hashem. All rights reserved.
//

import Foundation
import Firebase
import AVFoundation

class ChatViewModel: ObservableObject {
    
    @Published var conversation: Conversation?
    var user: ChatAppUser!
    var contact: ChatAppUser!
    
    init(user: ChatAppUser, contact: ChatAppUser, completion: @escaping () -> Void) {
        self.user = user
        self.contact = contact
        ConversationManager.shared.checkForConversation(users: [user, contact]) { (_, conversation) in
            if let conversation = conversation {
                self.conversation = conversation
                self.conversation?.messages.removeAll()
                completion()
            }
        }
    }
    
    func monitorConversation() {
        guard let conversation = self.conversation else { return }
        let usersDict: [String: ChatAppUser] = [conversation.users[0].uid: conversation.users[0], conversation.users[1].uid: conversation.users[1]]
        
        REF_CONVERSATIONS.child(conversation.uid).child("messages").observe(.childAdded) { (snapshot) in
            guard let messageData = snapshot.value as? [String: String] else { return }
            ConversationManager.shared.parseMessage(usersDictionary: usersDict, messageId: snapshot.key, messageData: messageData, downloadMedia: false) { (message) in
                guard var newMessage = message else { print("WTF ERROR PARSING MESSAGE"); return }
                self.conversation?.messages.append(newMessage)
                if newMessage.sender.senderId != self.user.uid {
                    newMessage.state = .read
                    REF_CONVERSATIONS.child(conversation.uid).child("messages").child(newMessage.messageId).child("state").setValue("read")
                }
                switch newMessage.kind {
                case .photo(let item):
                    self.handlePhotoMessages(message: newMessage, item: item as! MessageMedia)
                case .video(let item):
                    self.handleVideoMessage(message: newMessage, item: item as! MessageMedia)
                default:
                    break
                }
            }
        }
        
        REF_CONVERSATIONS.child(conversation.uid).child("messages").observe(.childChanged) { (snapshot) in
            guard let messageData = snapshot.value as? [String: String] else { return }
            ConversationManager.shared.parseMessage(usersDictionary: usersDict, messageId: snapshot.key, messageData: messageData, downloadMedia: messageData["imageURL"] != nil ? true : false, imageQuality: 0.5) { (message) in
                guard let changedMessage = message else { return }
                if let existingMessageIndex = self.conversation?.messages.firstIndex(where: { $0.messageId == changedMessage.messageId }) {
                    self.conversation?.messages[existingMessageIndex] = changedMessage
                }
            }
        }
    }
    
    
    private func handlePhotoMessages(message: Message, item: MessageMedia) {
        guard let imageURLString = item.url?.absoluteString else { return }
        Service.shared.downloadMessageImage(imageURL: imageURLString) { (image) in
            guard let image = image else { return }
            let mediaItemWithImage = MessageMedia(url: item.url, image: image, placeholderImage: item.placeholderImage, size: .init(width: 300, height: 300), caption: item.caption ?? nil)
            let newMessagewithImage = Message(sender: message.sender, messageId: message.messageId, sentDate: message.sentDate, kind: .photo(mediaItemWithImage), state: message.state)
            if let existingMessageIndex = self.conversation?.messages.firstIndex(where: { $0.messageId == message.messageId }) {
                self.conversation?.messages[existingMessageIndex] = newMessagewithImage
            }
        }
    }
    
    private func handleVideoMessage(message: Message, item: MessageMedia) {
        let mediaItemWithVideo = MessageMedia(url: item.url, image: item.image, placeholderImage: item.placeholderImage, size: .init(width: 300, height: 300), caption: item.caption)
        let newMessageWithVideo = Message(sender: message.sender, messageId: message.messageId, sentDate: message.sentDate, kind: .video(mediaItemWithVideo), state: message.state)
        if let existingMessageIndex = self.conversation?.messages.firstIndex(where: { $0.messageId == message.messageId }) {
            self.conversation?.messages[existingMessageIndex] = newMessageWithVideo
        }
    }
    
    func uploadPlaceHolderMessage(message: Message) {
        guard let existingConversation = conversation else { return }
        ConversationManager.shared.uploadMessageToConversation(conversation: existingConversation, message: message) { (result) in
            switch result {
            case .failure(let error): print("WTF", error.localizedDescription)
            case .success(_):
                break
            }
        }
    }
    
    
    func uploadVideo(videoURL: URL, message: Message, captionText: String? = nil) {
        Service.shared.uploadMessageVideo(videoURL: videoURL, messageId: message.messageId) { (url) in
            guard let videoDBURL = url, let placeholderImage = UIImage(systemName: "video") else { return }
            let mediaItemWithVideo = MessageMedia(url: videoDBURL, image: placeholderImage, placeholderImage: placeholderImage, size: .init(width: 300, height: 300), caption: captionText ?? nil)
            let videoMessage = Message(sender: message.sender, messageId: message.messageId, sentDate: message.sentDate, kind: .video(mediaItemWithVideo))
            
            if let existingConversation = self.conversation {
                REF_CONVERSATIONS.child(existingConversation.uid).child("messages").child(videoMessage.messageId).child("videoURL").setValue(videoDBURL.absoluteString)
                if let captionText = captionText {
                    REF_CONVERSATIONS.child(existingConversation.uid).child("messages").child(videoMessage.messageId).child("caption").setValue(captionText)
                }
                REF_CONVERSATIONS.child(existingConversation.uid).child("messages").child(videoMessage.messageId).child("state").observeSingleEvent(of: .value) { (snapshot) in
                    if let state = snapshot.value as? String, state == "written" {
                        REF_CONVERSATIONS.child(existingConversation.uid).child("messages").child(videoMessage.messageId).child("state").setValue("sent")
                    }
                }
            }
        }
    }
    
    func uploadImage(pickedImage: UIImage, message: Message, captionText: String? = nil) {
        Service.shared.uploadMessageImage(image: pickedImage, messageId: message.messageId) { (url) in
            guard let imageURL = url, let placeholderImage = UIImage(systemName: "person.fill") else { return }
            let mediaItemWithImage = MessageMedia(url: imageURL, image: pickedImage, placeholderImage: placeholderImage, size: pickedImage.size, caption: captionText ?? nil)
            let photoMessage = Message(sender: message.sender, messageId: message.messageId, sentDate: message.sentDate, kind: .photo(mediaItemWithImage))
            if let existingConversation = self.conversation {
                REF_CONVERSATIONS.child(existingConversation.uid).child("messages").child(photoMessage.messageId).child("imageURL").setValue(imageURL.absoluteString)
                if let captionText = captionText {
                    REF_CONVERSATIONS.child(existingConversation.uid).child("messages").child(photoMessage.messageId).child("caption").setValue(captionText)
                }
                REF_CONVERSATIONS.child(existingConversation.uid).child("messages").child(photoMessage.messageId).child("state").observeSingleEvent(of: .value) { (snapshot) in
                    if let state = snapshot.value as? String, state == "written" {
                        REF_CONVERSATIONS.child(existingConversation.uid).child("messages").child(photoMessage.messageId).child("state").setValue("sent")
                    }
                }
            }
        }
    }
    
    
    func uploadAudioMessage(message: Message, completion: @escaping () -> Void) {
        if let existingConversation = self.conversation {
            ConversationManager.shared.uploadMessageToConversation(conversation: existingConversation, message: message) { (_) in
                completion()
            }
        }
    }
    
    
}
