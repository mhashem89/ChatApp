//
//  ConversationManager.swift
//  ChatApp
//
//  Created by Mohamed Hashem on 7/19/20.
//  Copyright © 2020 Mohamed Hashem. All rights reserved.
//

import UIKit
import Firebase
import AVKit
import CoreLocation
import MessageKit
import FirebaseMessaging


class ConversationManager {
    
    static let shared = ConversationManager()
    
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = .current
        return formatter
    }()
    
    let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        formatter.timeZone = .current
        return formatter
    }()
    
    let conversationDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.timeZone = .current
        return formatter
    }()
    
    let minuteFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.allowsFractionalUnits = true
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
    func createTextMessage(sender: ChatAppUser, receiver: ChatAppUser, text: String) -> Message? {
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty else { return nil }
        let dateString = dateFormatter.string(from: Date())
        let messageId = "\(sender.uid)_\(receiver.uid)_\(dateString)"
        return Message(sender: sender, messageId: messageId, sentDate: Date(), kind: .text(text))
    }
    
    func createPhotoMessage(sender: ChatAppUser, receiver: ChatAppUser, photo: UIImage, completion: @escaping (Message?) -> Void) {
        let dateString = dateFormatter.string(from: Date())
        let messageId = "\(sender.uid)_\(receiver.uid)_\(dateString)"
        Service.shared.uploadMessageImage(image: photo, messageId: messageId) { (url) in
            if let url = url, let placeholder = UIImage(systemName: "photo") {
                let mediaItem = MessageMedia(url: url, image: photo, placeholderImage: placeholder, size: photo.size)
                let newMessage = Message(sender: sender, messageId: messageId, sentDate: Date(), kind: .photo(mediaItem))
                completion(newMessage)
            } else {
                completion(nil)
            }
        }
    }
    
    func createAudioMessage(sender: ChatAppUser, receiver: ChatAppUser, recorder: AVAudioRecorder, duration: TimeInterval, completion: @escaping (Message?) -> Void) {
        let dateString = dateFormatter.string(from: Date())
        let messageId = "\(sender.uid)_\(receiver.uid)_\(dateString)"
        
        Service.shared.uploadMessageAudio(audioURL: recorder.url, messageId: messageId) { (metadata, url) in
            if let url = url {
                let audioItem = MessageAudio(size: .init(width: 300, height: 300), url: url, duration: Float(duration))
                let audioMessage = Message(sender: sender, messageId: messageId, sentDate: Date(), kind: .audio(audioItem), state: .sent)
                completion(audioMessage)
            }
        }
    }
    
    func createLocationMessage(sender: ChatAppUser, receiver: ChatAppUser, coordinate: CLLocationCoordinate2D) -> Message {
        let dateString = dateFormatter.string(from: Date())
        let messageId = "\(sender.uid)_\(receiver.uid)_\(dateString)"
        let locationItem = MessageLocation(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), size: .init(width: 200, height: 200))
        let message = Message(sender: sender, messageId: messageId, sentDate: Date(), kind: .location(locationItem), state: .written)
        return message
    }
    
    func createMessageWithPlaceholder(sender: ChatAppUser, receiver: ChatAppUser, caption: String? = nil) -> Message {
        let dateString = dateFormatter.string(from: Date())
        let messageId = "\(sender.uid)_\(receiver.uid)_\(dateString)"
        let placeholderImage = UIImage(systemName: "person.fill")!
        let mediaItem = MessageMedia(url: nil, image: placeholderImage, placeholderImage: placeholderImage, size: .init(width: 300, height: 300), caption: caption ?? nil)
        let message = Message(sender: sender, messageId: messageId, sentDate: Date(), kind: .photo(mediaItem))
        return message
    }
    
    func createVideoMessagePlaceHolder(sender: ChatAppUser, receiver: ChatAppUser, caption: String? = nil) -> Message {
        let dateString = dateFormatter.string(from: Date())
        let messageId = "\(sender.uid)_\(receiver.uid)_\(dateString)"
        let placeholderImage = UIImage(systemName: "video")!
        let mediaItem = MessageMedia(url: nil, image: placeholderImage, placeholderImage: placeholderImage, size: .init(width: 300, height: 300), caption: caption ?? nil)
        let message = Message(sender: sender, messageId: messageId, sentDate: Date(), kind: .video(mediaItem))
        return message
    }
    
    func createNewConversation(users: [ChatAppUser], message: Message) -> Conversation {
        let uid = users[0].uid + "_" + users[1].uid
        let newConversation = Conversation(users: users, messages: [message], uid: uid)
        return newConversation
    }
    
    func checkForConversation(users: [ChatAppUser], completion: @escaping (Bool, Conversation?) -> Void) {
        guard users.count == 2 else { print ("WTF ERROR USERS COUNT = \(users.count)"); return }
        let uid = users[0].uid + "_" + users[1].uid
        let alternateUID = users[1].uid + "_" + users[0].uid
        
        REF_CONVERSATIONS.child(uid).observeSingleEvent(of: .value) { [weak self] (snapshot) in
            if let value = snapshot.value as? [AnyHashable: Any] {
                let fetchedConversation = self?.fetchConversation(conversationId: uid, users: users, data: value)
                completion(true, fetchedConversation)
            } else {
                REF_CONVERSATIONS.child(alternateUID).observeSingleEvent(of: .value) { (snapshot) in
                    if let value = snapshot.value as? [AnyHashable: Any] {
                        let fetchedConversation = self?.fetchConversation(conversationId: alternateUID, users: users, data: value)
                        completion(true, fetchedConversation)
                    } else {
                        completion(false, nil)
                    }
                }
            }
        }
    }
    
    func fetchConversation(conversationId: String, users: [ChatAppUser], data: [AnyHashable: Any], downloadMedia: Bool = true) -> Conversation? {
        guard let fetchedMessages = data["messages"] as? [String: Any] else {
            return nil
        }
        let firstUser = users[0]; let secondUser = users[1]
        let usersDictionary: [String: ChatAppUser] = [firstUser.uid: firstUser, secondUser.uid: secondUser]
        var messagesArray = [Message]()
        for messageId in fetchedMessages.keys {
            if let messageData = fetchedMessages[messageId] as? [String: String] {
                parseMessage(usersDictionary: usersDictionary, messageId: messageId, messageData: messageData, downloadMedia: downloadMedia) { (message) in
                    if let message = message {
                        messagesArray.append(message)
                    }
                }
            }
        }
        if messagesArray.count > 0 {
            messagesArray = messagesArray.sorted(by: { $0.sentDate < $1.sentDate })
            return Conversation(users: [firstUser, secondUser], messages: messagesArray, uid: conversationId)
        } else {
            return nil
        }
    }
    
    func parseMessage(usersDictionary : [String: ChatAppUser], messageId: String, messageData: [String: String], downloadMedia: Bool = true, imageQuality: CGFloat? = nil, completion: @escaping (Message?) -> Void) {
        guard let senderId = messageData["senderId"],
            let sender = usersDictionary[senderId],
            let dateString = messageData["sentDate"],
            let date = dateFormatter.date(from: dateString),
            let messageType = messageData["messageType"],
            let state = messageData["state"],
            let messageState = MessageState(rawValue: state) else { return }
        switch messageType {
        case "text":
            if let text = messageData["text"] {
                let message = Message(sender: sender, messageId: messageId, sentDate: date, kind: .text(text), state: messageState)
                completion(message)
            }
        case "photo":
            if let placeholderImage = UIImage(systemName: "message.fill") {
                switch downloadMedia {
                case true:
                    guard let urlString = messageData["imageURL"] else { return }
                    Service.shared.downloadMessageImage(imageURL: urlString, quality: imageQuality) { (image) in
                        if let image = image  {
                            let mediaItem = MessageMedia(url: URL(string: urlString), image: image, placeholderImage: placeholderImage, size: .init(width: 300, height: 300), caption: messageData["caption"] ?? nil)
                            let message = Message(sender: sender, messageId: messageId, sentDate: date, kind: .photo(mediaItem), state: messageState)
                            completion(message)
                        }
                    }
                case false:
                    var imageURL: URL?
                    if let imageURLString = messageData["imageURL"] { imageURL = URL(string: imageURLString) }
                    let mediaItem = MessageMedia(url: imageURL ?? nil, image: nil, placeholderImage: placeholderImage, size: CGSize(width: 120, height: 120), caption: messageData["caption"] ?? nil)
                    let message = Message(sender: sender, messageId: messageId, sentDate: date, kind: .photo(mediaItem), state: messageState)
                    completion(message)
                }
            }
        case "video":
            if let placeholderImage = UIImage(systemName: "video") {
                var videoURL: URL?
                if let videoURLString = messageData["videoURL"] { videoURL = URL(string: videoURLString) }
                let mediaItem = MessageMedia(url: videoURL ?? nil, image: placeholderImage, placeholderImage: placeholderImage, size: .init(width: 300, height: 300), caption: messageData["caption"] ?? nil)
                let message = Message(sender: sender, messageId: messageId, sentDate: date, kind: .video(mediaItem), state: messageState)
                completion(message)
            }
        case "audio":
            guard let audioURLString = messageData["audioURL"],
                let audioURL = URL(string: audioURLString),
                let durationString = messageData["duration"],
                let duration = Float(durationString)
                else { print("WTF NO AUDIO URL"); return }
            let audioItem = MessageAudio(size: .init(width: 300, height: 70), url: audioURL, duration: duration)
            let message = Message(sender: sender, messageId: messageId, sentDate: date, kind: .audio(audioItem), state: messageState)
            completion(message)
        case "location":
            guard let longitudeString = messageData["longitude"], let latitudeString = messageData["latitude"] else { print("WTF NO COORDINATES"); return }
            if let longitude = CLLocationDegrees(longitudeString), let latitude = CLLocationDegrees(latitudeString) {
                let locationItem = MessageLocation(location: CLLocation(latitude: latitude, longitude: longitude), size: .init(width: 200, height: 200))
                let message = Message(sender: sender, messageId: messageId, sentDate: date, kind: .location(locationItem), state: messageState)
                completion(message)
            }
        default:
            break
        }
    }
    
    func locateConversation(conversationId: String, downloadMedia: Bool = true, completion: @escaping(Conversation?) -> Void) {
        REF_CONVERSATIONS.child(conversationId).observe(.value) { [weak self] (snapshot) in
            guard let data = snapshot.value as? [AnyHashable: Any], let userIds = data["uesrs"] as? NSArray else { print("WTF WHERE IS THE DATA?"); return }
            self?.fetchConversationUsers(userIds: userIds) { (fetchedUsers) in
                let conversation = self?.fetchConversation(conversationId: conversationId, users: fetchedUsers, data: data, downloadMedia: downloadMedia)
                completion(conversation)
            }
        }
    }
    
    func fetchConversationUsers(userIds: NSArray, completion: @escaping ([ChatAppUser]) -> Void) {
        var fetchedUsers = [ChatAppUser]()
        for userId in userIds {
            guard let userId = userId as? String else { return }
            Service.shared.fetchUserData(uid: userId) { (user) in
                fetchedUsers.append(user)
                if fetchedUsers.count == 2 {
                    completion(fetchedUsers)
                }
            }
        }
    }
    
    func uploadConversation(conversation: Conversation) {
        if conversation.messages.count > 0 {
            let userIds = [conversation.users[0].uid, conversation.users[1].uid]
            REF_CONVERSATIONS.child(conversation.uid).updateChildValues(["uesrs": userIds])
            for message in conversation.messages {
                uploadMessageToConversation(conversation: conversation, message: message) { (result) in
                    switch result {
                    case .failure(let error): print("WTF", error.localizedDescription)
                    case .success(_):
                        REF_CONVERSATIONS.child(conversation.uid).child("messages").child(message.messageId).child("state").setValue("sent")
                    }
                }
            }
            for user in conversation.users {
                REF_USERS.child(user.uid).child("chats").child(conversation.uid).setValue("started")
            }
        }
    }
    
    func uploadMessageToConversation(conversation: Conversation, message: Message, completion: @escaping (Result<DatabaseReference, Error>) -> Void) {
        let sentDate = dateFormatter.string(from: message.sentDate)
        var messageData = [String: String]()
        switch message.kind {
        case .text(let text):
            guard !text.isEmpty else { print("WTF EMPTY MESSAGE"); return }
            messageData = ["senderId": message.sender.senderId, "sentDate": sentDate, "messageType": "text", "text": text, "state": "written"]
        case .photo(let mediaItem as MessageMedia):
            messageData = ["senderId": message.sender.senderId, "sentDate": sentDate, "messageType": "photo", "state": "written"]
            if let url = mediaItem.url { messageData["imageURL"] = url.absoluteString }
            if let captionText = mediaItem.caption { messageData["caption"] = captionText }
        case .video(let mediaItem as MessageMedia):
            messageData = ["senderId": message.sender.senderId, "sentDate": sentDate, "messageType": "video", "state": "written"]
            if let url = mediaItem.url { messageData["videoURL"] = url.absoluteString }
        case .audio(let audioItem as MessageAudio):
            messageData = ["senderId": message.sender.senderId, "sentDate": sentDate, "messageType": "audio", "state": "sent", "duration": String(audioItem.duration)]
            messageData["audioURL"] = audioItem.url.absoluteString
        case .location(let locationItem as MessageLocation):
            let latitudeString = String(locationItem.location.coordinate.latitude)
            let longitudeString = String(locationItem.location.coordinate.longitude)
            messageData = ["senderId": message.sender.senderId, "sentDate": sentDate, "messageType": "location", "state": "sent", "longitude": longitudeString, "latitude": latitudeString]
        default: break
        }

        if !messageData.isEmpty {
            REF_CONVERSATIONS.child(conversation.uid).child("messages").child(message.messageId).setValue(messageData) { (error, reference) in
                if let error = error { completion(.failure(error)) }
                else {
                    completion(.success(reference))
                    guard let contactUID = conversation.users.filter({ $0.uid != message.sender.senderId }).first?.uid else { return }
                    var messageText: String?
                    switch message.kind {
                    case .text(let text):
                        messageText = text
                    case .audio(_):
                        messageText = "Audio Message"
                    case .photo(_):
                        messageText = "Photo"
                    default:
                        break
                    }
                    REF_USERS.child(contactUID).observeSingleEvent(of: .value) { (snapshot) in
                        var title: String?
                        if let userData = snapshot.value as? [String: Any] {
                            if let userContacts = userData["contacts"] as? [String: String], let userName = userContacts[message.sender.senderId] {
                                title = userName
                            }
                            if let fcmToken = userData["fcmToken"] as? String {
                                PushNotificationSender.sendPushNotification(to: fcmToken, title: title ?? message.sender.displayName, body: messageText ?? "", from: message.sender.senderId, withId: message.messageId, in: conversation.uid)
                            }
                        }
                    }
                }
            }
        } else {
           print("WTF uploading messaging failed")
        }
    }
    
}
