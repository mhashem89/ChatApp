//
//  ContainerController.swift
//  ChatApp
//
//  Created by Mohamed Hashem on 7/17/20.
//  Copyright © 2020 Mohamed Hashem. All rights reserved.
//

import UIKit

class ContainerController: UITabBarController {
    
    var user: ChatAppUser! {
        didSet {
            monitorUser(uid: user.uid)
        }
    }
    
    var conversationsVC: ConversationsViewController!
    var profileVC: ProfileViewController!
    
    init(user: ChatAppUser) {
        super.init(nibName: nil, bundle: nil)
        self.user = user
        monitorUser(uid: user.uid)
        conversationsVC = ConversationsViewController(user: user)
        profileVC = ProfileViewController(user: user)
        navigationController?.navigationBar.prefersLargeTitles = true
        conversationsVC.tabBarItem.title = "Chats"
        conversationsVC.tabBarItem.image = UIImage(systemName: "message.fill")
        profileVC.tabBarItem.title = "Profile"
        profileVC.tabBarItem.image = UIImage(systemName: "person.fill")
        self.viewControllers = [UINavigationController(rootViewController: conversationsVC), UINavigationController(rootViewController: profileVC)]
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Service.shared.updateUserStatus(user: user, status: .online)
    }
    
    func monitorUser(uid: String) {
        REF_USERS.removeAllObservers()
        REF_USERS.child(uid).observe(.value) { [weak self]( snapshot) in
            guard let strongSelf = self else { return }
            if let userData = snapshot.value as? [AnyHashable: Any] {
                let newUser = ChatAppUser(uid: strongSelf.user.uid, data: userData)
                strongSelf.conversationsVC.user = newUser
                strongSelf.profileVC.user = newUser
            }
        }
    }
    
}
