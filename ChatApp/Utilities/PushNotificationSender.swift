//
//  PushNotificationSender.swift
//  ChatApp
//
//  Created by Mohamed Hashem on 10/18/20.
//  Copyright © 2020 Mohamed Hashem. All rights reserved.
//

import UIKit


class PushNotificationSender {
    
    static func sendPushNotification(to token: String, title: String, body: String, from uid: String, withId messageId: String, in conversationId: String) {
        
        let urlString = "https://fcm.googleapis.com/fcm/send"
        
        let url = URL(string: urlString)!
        
        let paramString: [String: Any] = [
            "to": token,
            "notification": ["title": title, "body": body, "sound": "default"],
            "data": ["user" : uid, "messageId": messageId, "conversationId": conversationId]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: paramString, options: [.prettyPrinted])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("key=AAAAsvcdX7A:APA91bH9ejGcmPy2H0BwRAfNci7gEmM6r2cUb1WGBnUdx6nTHiFb1RaPtl5rXg8Qxh3CwelInu3zaAlVwOTDASm9JqlibFq47o0xFinuj6LChB4kQMx9PGiDy616lahODYd-FYKEstwe", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            do {
                if let jsonData = data {
                    if let jsonDataDict = try JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions.allowFragments) as? [String: Any] {
                        print("WTF Received data:\n\(jsonDataDict)")
                    }
                }
            } catch let err {
                print(err.localizedDescription)
            }
        }
        task.resume()
    }
    
}

