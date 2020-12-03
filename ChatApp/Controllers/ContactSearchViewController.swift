//
//  NewChatViewController.swift
//  ChatApp
//
//  Created by Mohamed Hashem on 7/17/20.
//  Copyright © 2020 Mohamed Hashem. All rights reserved.
//

import UIKit
import MessageKit

protocol ContactSearchViewDelegate: class {
    func contactSelected(contact: ChatAppUser)
}

class ContactSearchViewController: UIViewController {
 
    
    // MARK:- Properties
    
    var contacts = [ChatAppUser]()
    var searchResults = [ChatAppUser]()
    var contactNames = [String: String]()
    
    var user: ChatAppUser!
    weak var delegate: ContactSearchViewDelegate?
    
    lazy var conversationsTable: ConversationsTable = {
        let table = ConversationsTable()
        table.delegate = self
        table.dataSource = self
        return table
    }()
    
    let upperView = NewChatUpperView()
    let noResultsView = NoResultsView()
         
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
        view.addSubviews([conversationsTable, noResultsView, upperView])
        
        upperView.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 110)
        conversationsTable.frame = CGRect(x: 0, y: upperView.frame.height, width: view.frame.width, height: view.frame.height - upperView.frame.height)
        conversationsTable.backgroundColor = .white
        
        upperView.searchBar.delegate = self
        upperView.cancelButton.addTarget(self, action: #selector(dismissView), for: .touchUpInside)
    }
    
    // MARK:- Selectors
    
    @objc func dismissView() {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK:- Methods
    func searchBarClicked() {
        self.upperView.newChatLabel.isHidden = true
        self.upperView.cancelButton.isHidden = true
        UIView.animate(withDuration: 0.3, animations: {
            self.view.layoutIfNeeded()
            self.upperView.searchBar.frame.origin.y -= 50
            self.upperView.frame.size = CGSize(width: self.view.frame.width, height: 60)
            self.conversationsTable.frame.origin.y -= 50
            self.upperView.searchBar.setShowsCancelButton(true, animated: true)
        }) { (_) in
        }
    }
    
    func cancelSearchClicked() {
        self.upperView.searchBar.resignFirstResponder()
        UIView.animate(withDuration: 0.3, animations: {
            self.view.layoutIfNeeded()
            self.upperView.searchBar.frame.origin.y += 50
            self.upperView.frame.size = CGSize(width: self.view.frame.width, height: 110)
            self.conversationsTable.frame.origin.y += 50
            self.upperView.searchBar.setShowsCancelButton(false, animated: true)
        }) { (_) in
            self.upperView.newChatLabel.isHidden = false
            self.upperView.cancelButton.isHidden = false
        }
    }
    
    func fetchContacts(user: ChatAppUser) {
        var fetchedContacts = [ChatAppUser]()
        REF_USERS.child(user.uid).child("contacts").observeSingleEvent(of: .value) { [weak self] (snapshot) in
            guard let contacts = snapshot.value as? [String: String] else { return }
            for uid in contacts.keys {
                if let _ = contacts[uid] {
                    Service.shared.fetchUserData(uid: uid) { (user) in
                        fetchedContacts.append(user)
                        self?.contacts = fetchedContacts.sorted(by: { $0.fullName < $1.fullName })
                        self?.contactNames = contacts
                    }
                }
            }
        }
    }
    
    
}

extension ContactSearchViewController: UISearchBarDelegate {
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        self.searchBarClicked()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        noResultsView.frame = .zero
        searchBar.text = nil
        self.cancelSearchClicked()
        self.searchResults.removeAll()
        conversationsTable.reloadData()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty || searchText.replacingOccurrences(of: " ", with: "").isEmpty {
            searchResults.removeAll()
            conversationsTable.reloadData()
        } else {
            let searchText = searchText.lowercased()
            contacts.forEach {
                let fullName = $0.fullName.lowercased()
                if fullName.contains(searchText) && !searchResults.contains($0) {
                    searchResults.append($0)
                    noResultsView.frame = .zero
                    conversationsTable.reloadData()
                } else if !fullName.contains(searchText), let index = searchResults.firstIndex(of: $0) {
                    searchResults.remove(at: index)
                    conversationsTable.reloadData()
                }
            }
            if searchResults.isEmpty {
                noResultsView.frame = conversationsTable.frame
            }
        }
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchResults.removeAll()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchResults.removeAll()
    }
}

// MARK:- Table View Controller

extension ContactSearchViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = ConversationsTableCell(style: .default, reuseIdentifier: cellId)
        let contact = searchResults[indexPath.row]
        cell.nameLabel.text = contactNames[contact.uid] ?? contact.fullName
        cell.subtitleLabel.text = contact.email
        Service.shared.downloadUserImage(user: searchResults[indexPath.row]) { (image) in
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
        let contact = searchResults[indexPath.row]
        dismiss(animated: true) { [weak self] in
            self?.delegate?.contactSelected(contact: contact)
        }
    }
    
    
}



class NewChatUpperView: UIView {
    
    let newChatLabel: UILabel = {
        let label = UILabel()
        label.text = "New Chat"
        label.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        return label
    }()
    
    let searchBar: UISearchBar = {
        let bar = UISearchBar()
        bar.placeholder = "Search"
        bar.layer.cornerRadius = 5
        bar.backgroundImage = UIImage()
        return bar
    }()
    
    let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        let title = NSAttributedString(string: "Cancel", attributes: [.foregroundColor: UIColor.systemBlue, .font: UIFont.systemFont(ofSize: 17)])
        button.setAttributedTitle(title, for: .normal)
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubviews([newChatLabel, searchBar, cancelButton])
        backgroundColor = #colorLiteral(red: 0.9527031541, green: 0.9527031541, blue: 0.9527031541, alpha: 1)
        searchBar.barTintColor = backgroundColor
        
        newChatLabel.anchor(top: topAnchor, topConstant: 20, centerX: centerXAnchor)
        searchBar.anchor(leading: leadingAnchor, leadingConstant: 10, trailing: trailingAnchor, trailingConstant: 5, bottom: bottomAnchor, bottomConstant: 5)
        cancelButton.anchor(top: topAnchor, topConstant: 15, trailing: trailingAnchor, trailingConstant: 10)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


class NoResultsView: UIView {
    
    let noResultsLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 24)
        label.text = "No Search Results"
        label.textColor = .lightGray
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        addSubview(noResultsLabel)
        noResultsLabel.anchor(centerX: centerXAnchor, centerY: centerYAnchor, centerYConstant: -80)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

