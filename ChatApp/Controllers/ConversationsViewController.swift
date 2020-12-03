//
//  ViewController.swift
//  ChatApp
//
//  Created by Mohamed Hashem on 7/15/20.
//  Copyright © 2020 Mohamed Hashem. All rights reserved.
//

import UIKit
import Firebase
import FBSDKLoginKit
import GoogleSignIn

let cellId = "cellId"

class ConversationsViewController: UIViewController {

    // MARK:- Properties
    
    var user: ChatAppUser! {
        didSet {
            monitorConversations(user: user)
        }
    }
    
    var conversations = [Conversation]() {
        didSet {
            conversationsTable.reloadData()
        }
    }
    
    lazy var conversationsTable: ConversationsTable = {
        let table = ConversationsTable()
        table.delegate = self
        table.dataSource = self
        return table
    }()
    
    // MARK:- Lifecycle Methods
    
    init(user: ChatAppUser) {
        super.init(nibName: nil, bundle: nil)
        self.user = user
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let newChatButton = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(openNewChat))
        navigationItem.rightBarButtonItem = newChatButton
        navigationItem.hidesBackButton = true
        view.addSubview(conversationsTable)
        conversationsTable.frame = view.bounds
        navigationController?.navigationBar.prefersLargeTitles = true
        conversationsTable.tableFooterView = UIView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        monitorConversations(user: user)
        conversationsTable.reloadData()
        title = "Chats"
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        removeMonitor(user: user)
    }

    
    // MARK:- Selectors
    
    @objc func openNewChat() {
        let newChatVC = ContactSearchViewController(user: user)
        newChatVC.delegate = self
        present(newChatVC, animated: true, completion: nil)
    }
    
    // MARK:- Methods
    
    func monitorConversations(user: ChatAppUser) {
        REF_USERS.child(user.uid).child("chats").observe(.value) { [weak self] (snapshot) in
            if let chatsData = snapshot.value as? [String: Any] {
                var foundChatIds = [String]()
                var foundChats = [Conversation]()
                var chatsDict = [String: Conversation]()
                chatsData.keys.forEach { foundChatIds.append($0) }
                for chatId in foundChatIds {
                    ConversationManager.shared.locateConversation(conversationId: chatId, downloadMedia: false) { (conversation) in
                        guard let conversation = conversation else { return }
                        chatsDict[chatId] = conversation
                        if chatsDict.keys.count == foundChatIds.count {
                            foundChats = chatsDict.values.sorted(by: { $0.messages.last!.sentDate > $1.messages.last!.sentDate })
                            self?.conversations = foundChats
                        }
                    }
                }
            } else {
                self?.conversations = [Conversation]()
            }
        }
    }
    
    func removeMonitor(user: ChatAppUser) {
        if let foundChats = user.chats {
            for chatId in foundChats {
                REF_CONVERSATIONS.child(chatId).removeAllObservers()
            }
        }
        REF_USERS.child(user.uid).child("chats").removeAllObservers()
    }
    
    func presentLoginVC(animated: Bool = true) {
        let loginVC = LoginViewController()
        let navVC = UINavigationController(rootViewController: loginVC)
        navVC.modalPresentationStyle = .fullScreen
        present(navVC, animated: animated, completion: nil)
    }
}


extension ConversationsViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = conversationsTable.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! ConversationsTableCell
        cell.accessoryType = .none
        if let contact = conversations[indexPath.row].users.filter({$0.uid != self.user.uid}).first {
            REF_USERS.child(user.uid).child("contacts").child(contact.uid).observeSingleEvent(of: .value) { (snapshot) in
                cell.nameLabel.text = snapshot.value as? String ?? contact.fullName
            }
            let contactMessages = conversations[indexPath.row].messages.filter({ $0.sender.senderId == contact.uid }).sorted(by: { $0.sentDate > $1.sentDate })
            for sentMessage in contactMessages.filter({ $0.state == .sent || $0.state == .written }) {
                REF_CONVERSATIONS.child(conversations[indexPath.row].uid).child("messages").child(sentMessage.messageId).child("state").setValue("delivered")
            }
            if let latestMessage = conversations[indexPath.row].messages.last {
                let unreadMessages = contactMessages.filter({ $0.state == .sent || $0.state == .delivered })
                switch latestMessage.kind {
                case .text(let messageText):
                    cell.subtitleLabel.text = latestMessage.sender.senderId == user.uid ? "You: \(messageText)" : messageText
                case .photo:
                    cell.subtitleLabel.text = latestMessage.sender.senderId == user.uid ? "You sent photo message" : "Photo message"
                case .video:
                    cell.subtitleLabel.text = latestMessage.sender.senderId == user.uid ? "You sent video message" : "Video message"
                case .audio:
                    cell.subtitleLabel.text = latestMessage.sender.senderId == user.uid ? "You sent audio message" : "Audio message"
                case .location:
                    cell.subtitleLabel.text = latestMessage.sender.senderId == user.uid ? "You sent location message" : "Location message"
                default:
                    break
                }
                cell.subtitleLabel.font = UIFont.systemFont(ofSize: 14)
                if ConversationManager.shared.conversationDayFormatter.string(from: latestMessage.sentDate) ==  ConversationManager.shared.conversationDayFormatter.string(from: Date()) {
                    cell.dateLabel.text = ConversationManager.shared.timeFormatter.string(from: latestMessage.sentDate)
                } else {
                    cell.dateLabel.text = ConversationManager.shared.conversationDayFormatter.string(from: latestMessage.sentDate)
                }
                
                if unreadMessages.count > 0 {
                    cell.unreadMessagesCountLabel.text = String(unreadMessages.count)
                    cell.unreadMessagesCountLabel.isHidden = false
                    cell.dateLabel.textColor = .systemBlue
                } else if unreadMessages.count == 0 {
                    cell.dateLabel.textColor = .systemGray
                    cell.unreadMessagesCountLabel.isHidden = true
                }
                if latestMessage.sender.senderId == contact.uid, latestMessage.state != .read {
                    cell.subtitleLabel.textColor = .black
                    cell.subtitleLabel.font = UIFont.boldSystemFont(ofSize: 14)
                } else if latestMessage.sender.senderId == contact.uid, latestMessage.state == .read {
                    cell.subtitleLabel.textColor = .systemGray
                    cell.subtitleLabel.font = UIFont.systemFont(ofSize: 14)
                }
            }
            Service.shared.downloadUserImage(user: contact) { (image) in
                if let profileImage = image {
                    DispatchQueue.main.async {
                        cell.userImage.image = profileImage
                    }
                } else {
                    cell.userImage.image = UIImage(systemName: "person.fill")
                }
            }
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let contact = conversations[indexPath.row].users.filter({ $0.uid != self.user.uid }).first else { return }
        let chatVC = ChatViewController(user: self.user, contact: contact)
        self.navigationController?.pushViewController(chatVC, animated: true)
        title = ""
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 65
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "Delete") { (_, _, _) in
            let conversationId = self.conversations[indexPath.row].uid
            self.conversationsTable.performBatchUpdates({
                self.conversationsTable.deleteRows(at: [indexPath], with: .automatic)
                self.conversations.remove(at: indexPath.row)
            }) { (_) in
                REF_USERS.child(self.user.uid).child("chats").child(conversationId).removeValue()
            }
        }
        let swipe = UISwipeActionsConfiguration(actions: [delete])
        return swipe
    }
    
}

extension ConversationsViewController: ContactSearchViewDelegate {
    
    func contactSelected(contact: ChatAppUser) {
       let chatVC = ChatViewController(user: self.user, contact: contact)
       self.navigationController?.pushViewController(chatVC, animated: true)
    }
    
}
