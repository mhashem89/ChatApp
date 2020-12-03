//
//  Service.swift
//  ChatApp
//
//  Created by Mohamed Hashem on 7/15/20.
//  Copyright © 2020 Mohamed Hashem. All rights reserved.
//

import UIKit
import Firebase
import FBSDKLoginKit
import AVFoundation

let DB_REF = Firebase.Database.database().reference()
let REF_USERS = DB_REF.child("users")
let REF_CONVERSATIONS = DB_REF.child("conversations")


class Service {
    
    static let shared = Service()
    
    private var imageCache = NSCache<NSString,UIImage>()
    
    func createUser(fullName: String, email: String, password: String, completion: @escaping (String) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { (result, error) in
            if let error = error { print("WTF signup error: \(error.localizedDescription)"); return }
            
            guard let uid = result?.user.uid else { return }
            let values: [AnyHashable: Any] = ["fullName": fullName, "email": email]
            REF_USERS.child(uid).setValue(values) { (error, ref) in
                if let error = error { print("WTF sign up error: \(error.localizedDescription)"); return }
                completion(uid)
            }
        }
    }
    
    func checkUser(uid: String, email: String, completion: @escaping (Bool) -> Void) {
        REF_USERS.child(uid).observeSingleEvent(of: .value) { (snapshot) in
            if let data = snapshot.value as? [AnyHashable: Any], let foundEmail = data["email"] as? String {
                if foundEmail == email {
                    completion(true)
                }
            } else {
                completion(false)
            }
        }
    }
    
    func updateUserStatus(user: ChatAppUser, status: UserStatus) {
        var statusString = String()
        switch status {
        case .online: statusString = "online"
        case .recordingAudio: statusString = "recording audio"
        case .typing: statusString = "typing..."
        case .offline: statusString = "offline"
        }
        REF_USERS.child(user.uid).child("status").setValue(statusString)
    }
    
    func returnUserStatus(statusString: String) -> UserStatus? {
        switch statusString {
        case "online": return .online
        case "recording audio": return .recordingAudio
        case "typing...": return .typing
        case "offline": return .offline
        default:
            return nil
        }
    }
    
    func loginUser(email: String, password: String, completion: @escaping(User) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { (result, error) in
            if let error = error { print("WTF sign in error: \(error.localizedDescription)"); return }
            guard let user = result?.user else { return }
            completion(user)
        }
    }
    
    func fetchUserData(uid: String, completion: @escaping (ChatAppUser) -> Void) {
        REF_USERS.child(uid).observeSingleEvent(of: .value) { (snapshot) in
            guard let data = snapshot.value as? [AnyHashable: Any],
            let user = ChatAppUser(uid: uid, data: data) else {
                return
            }
            completion(user)
        }
    }
    
    func getFBProfilePic(picData: Any?, completion: @escaping (UIImage?) -> Void) {
        guard let result = picData as? [AnyHashable: Any],
            let data = result["data"] as? [String: Any],
            let picURLString = data["url"] as? String,
            let picURL = URL(string: picURLString)
            else { return }
        let task = URLSession.shared.dataTask(with: picURL) { (data, response, error) in
            if let error = error { print("WTF not able to download FB image: \(error.localizedDescription)") }
            guard let data = data else { print("WTF ERROR NO FB IMAGE DATA"); return }
            let profilePic = UIImage(data: data)
            completion(profilePic)
        }
        task.resume()
    }
    
    func getGoogleProfilePic(urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else { print("WTF ERROR BAD URL"); return }
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let error = error { print("WTF IMAGE DOWNLOAD ERROR \(error.localizedDescription)"); return }
            guard let data = data else { print("WTF ERROR NO GOOGLE IMAGE DATA"); return }
            let profilePic = UIImage(data: data)
            completion(profilePic)
        }
        task.resume()
    }
    
    
    func uploadUserImage(image: UIImage, uid: String, completion: @escaping (URL?) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        let storage = Storage.storage().reference().child("UserImages").child("\(uid).jpg")
        storage.putData(imageData, metadata: nil) { (metadata, error) in
            if let error = error { print("WTF upload failed due to \(error.localizedDescription)") }
            else {
                storage.downloadURL { (url, error) in
                    DispatchQueue.main.async {
                         completion(url)
                    }
                }
            }
        }
    }
    
    func uploadMessageImage(image: UIImage, messageId: String, completion: @escaping (URL?) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 1) else { return }
        let storage = Storage.storage().reference().child("Messages").child("Images").child("\(messageId).jpg")
        storage.putData(imageData, metadata: nil) { (metadata, error) in
            if let error = error { print("WTF upload message image failued due to \(error.localizedDescription)") }
            else {
                storage.downloadURL { (url, error) in
                    DispatchQueue.main.async {
                         completion(url)
                    }
                }
            }
        }
    }
    
    func uploadMessageVideo(videoURL: URL, messageId: String, completion: @escaping (URL?) -> Void) {
        let storage = Storage.storage().reference().child("Messages").child("Videos").child("\(messageId).mov")
        let metadata = StorageMetadata()
        metadata.contentType = "video/quicktime"
        if let videoData = NSData(contentsOf: videoURL) as Data? {
            storage.putData(videoData, metadata: metadata) { (metadata, error) in
                if let error = error { print("WTF upload message video failued due to \(error.localizedDescription)") }
                else {
                    storage.downloadURL { (url, error) in
                        DispatchQueue.main.async {
                             completion(url)
                        }
                    }
                }
            }
        }
    }
    
    func uploadMessageAudio(audioURL: URL, messageId: String, completion: @escaping (StorageMetadata?, URL?) -> Void) {
        let storage = Storage.storage().reference().child("Messages").child("Audio").child("\(messageId).m4a")
        let metadata = StorageMetadata()
        metadata.contentType = "audio/mp4"
        if let audioData = NSData(contentsOf: audioURL) as Data? {
            storage.putData(audioData, metadata: metadata) { (metadata, error) in
                if let error = error {  print("WTF upload message audio failued due to \(error.localizedDescription)") }
                else {
                    storage.downloadURL { (url, error) in
                        DispatchQueue.main.async {
                             completion(metadata, url)
                        }
                    }
                }
            }
        }
    }
    
    func downloadMessageAudio(audioURL: URL, completion: @escaping (String?) -> Void) {
        let storageRef = Storage.storage().reference(forURL: audioURL.absoluteString)
        let filePath = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(storageRef.name)
        if filePath != nil {
            storageRef.write(toFile: filePath!) { (url, error) in
                if let error = error { print("WTF AUDIO DOWNLOAD ERROR", error.localizedDescription); return }
                DispatchQueue.main.async {
                    completion(url?.absoluteString)
                }
            }
        }
    }
    
    func downloadMessageVideo(videoURL: URL, completion: @escaping (String?) -> Void) {
        let storageRef = Storage.storage().reference(forURL: videoURL.absoluteString)
        let filePath = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(storageRef.name)
        if filePath != nil {
            storageRef.write(toFile: filePath!) { (url, error) in
                if let error = error { print("WTF VIDEO DOWNLOAD ERROR", error.localizedDescription); return }
                DispatchQueue.main.async {
                    completion(url?.absoluteString)
                }
            }
        }
    }
    
    func downloadMessageImage(imageURL: String, quality: CGFloat? = nil, completion: @escaping (UIImage?) -> Void) {
        if let image = imageCache.object(forKey: imageURL as NSString) {
            completion(image)
        } else {
            let storageRef = Storage.storage().reference(forURL: imageURL)
            storageRef.getData(maxSize: Int64(1024 * 1024 * 10)) { [weak self] (data, error) in
                if let error = error { print("ERROR downloading image due to \(error.localizedDescription)") }
                guard let data = data else { return }
                let image = UIImage(data: data)
                if let downloadedImage = image {
                    self?.imageCache.setObject(downloadedImage, forKey: imageURL as NSString)
                }
                if let imageQualty = quality, let reducedImageData = image?.jpegData(compressionQuality: imageQualty) {
                    let reducedImage = UIImage(data: reducedImageData)
                    completion(reducedImage)
                    return
                }
                completion(image)
            }
        }
    }
    
  
    
    ///Checks if user image is cached and if not downloads it and caches it. Returns nil if no url or no image found.
    func downloadUserImage(user: ChatAppUser, completion: @escaping (UIImage?) -> Void) {
        guard let url = user.imageURL else { completion(nil); return }
        if let userImage = imageCache.object(forKey: url as NSString) {
            completion(userImage)
        } else {
            let storageRef = Storage.storage().reference(forURL: url)
            DispatchQueue.global().async {
                storageRef.getData(maxSize: Int64(1024 * 1024 * 1.5)) { [weak self] (data, error) in
                    if let error = error { print("ERROR downloading image due to \(error.localizedDescription)") }
                    guard let data = data else { return }
                    let image = UIImage(data: data)
                    if let downloadedImage = image { self?.imageCache.setObject(downloadedImage, forKey: url as NSString) }
                    completion(image)
                }
            }
            
        }
    }
    
    
    func errorAlert(errorString: String) -> UIAlertController {
        let alert =  UIAlertController(title: "Error", message: errorString, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .destructive, handler: nil))
        return alert
    }
    
    func locateUserByEmail(email: String, completion: @escaping (String) -> Void) {
        REF_USERS.observeSingleEvent(of: .value) { (snapshot) in
            if let users = snapshot.value as? [String: Any] {
                for key in users.keys {
                    if let userData = users[key] as? [String: Any], let userEmail = userData["email"] as? String {
                        if userEmail == email {
                            completion(String(key))
                        }
                    }
                }
            }
        }
    }
    
    func generateVideoThumbnail(url: URL, completion: @escaping (UIImage?) -> Void) {
        if let thumbnailImage = imageCache.object(forKey: url.absoluteString as  NSString) {
            completion(thumbnailImage)
        }
        DispatchQueue.global().async {
            let asset = AVAsset(url: url)
            let avAssetGenerator = AVAssetImageGenerator(asset: asset)
            avAssetGenerator.appliesPreferredTrackTransform = true
            let thumbnailTime = CMTimeMake(value: 2, timescale: 1)
            do {
                let cgThumbImage = try avAssetGenerator.copyCGImage(at: thumbnailTime, actualTime: nil)
                let thumbImage = UIImage(cgImage: cgThumbImage)
                DispatchQueue.main.async { [weak self] in
                    self?.imageCache.setObject(thumbImage, forKey: url.absoluteString as NSString)
                    completion(thumbImage)
                }
            } catch let err {
                print("WTF", err.localizedDescription)
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    
}
