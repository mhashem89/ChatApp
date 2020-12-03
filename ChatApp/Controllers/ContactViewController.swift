//
//  ContactsViewController.swift
//  ChatApp
//
//  Created by Mohamed Hashem on 7/18/20.
//  Copyright © 2020 Mohamed Hashem. All rights reserved.
//

import UIKit
import Firebase

class ContactsViewController: UIViewController, NewContactControllerDelegate {
    
    // MARK:- Properties
    var contacts = [ChatAppUser]() {
        didSet {
            conversationsTable.reloadData()
        }
    }
    
    var contactNamesDict = [String: String]()
    
    var user: ChatAppUser!
    
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
        fetchContacts(user: user)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(conversationsTable)
        conversationsTable.frame = view.bounds
        conversationsTable.tableFooterView = UIView()
        title = "Contacts"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addContact))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationItem.largeTitleDisplayMode = .always
    }
      
    
    // MARK:- Selectors
    
    @objc func addContact() {
        let newContactVC = NewContactViewController(user: user)
        newContactVC.delegate = self
        let navVc = UINavigationController(rootViewController: newContactVC)
        navVc.modalPresentationStyle = .automatic
        present(navVc, animated: true)
    }
    
    
    // MARK:- UI Methods
    
    func fetchContacts(user: ChatAppUser) {
        var fetchedContacts = [ChatAppUser]()
        REF_USERS.child(user.uid).child("contacts").observeSingleEvent(of: .value) { [weak self] (snapshot) in
            guard let contacts = snapshot.value as? [String: String] else { return }
            for uid in contacts.keys {
                if let _ = contacts[uid] {
                    Service.shared.fetchUserData(uid: uid) { (user) in
                        fetchedContacts.append(user)
                        self?.contacts = fetchedContacts.sorted(by: { $0.fullName < $1.fullName })
                        self?.contactNamesDict = contacts
                    }
                }
            }
        }
    }
    
    func newContactAdded() {
        fetchContacts(user: user)
    }
}


extension ContactsViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contacts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = ConversationsTableCell(style: .default, reuseIdentifier: cellId)
        let contact = contacts[indexPath.row]
        cell.nameLabel.text = contactNamesDict[contact.uid] ?? contact.fullName
        cell.subtitleLabel.text = contact.email
        Service.shared.downloadUserImage(user: contacts[indexPath.row]) { (image) in
            if let profileImage = image {
                DispatchQueue.main.async {
                    cell.userImage.image = profileImage
                }
            }
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 65
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        conversationsTable.deselectRow(at: indexPath, animated: true)
        let contact = contacts[indexPath.row]
        let chatVC = ChatViewController(user: self.user, contact: contact)
        self.navigationController?.pushViewController(chatVC, animated: true)
    }
    
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "Delete") { (_, _, _) in
            let contact = self.contacts[indexPath.row]
            self.conversationsTable.performBatchUpdates({
                self.conversationsTable.deleteRows(at: [indexPath], with: .automatic)
                self.contacts.remove(at: indexPath.row)
            }) { (_) in
                REF_USERS.child(self.user.uid).child("contacts").child(contact.uid).removeValue()
            }
        }
        let swipe = UISwipeActionsConfiguration(actions: [delete])
        return swipe
    }
    
}
