//
//  ProfileViewController.swift
//  ChatApp
//
//  Created by Mohamed Hashem on 7/15/20.
//  Copyright © 2020 Mohamed Hashem. All rights reserved.
//

import UIKit
import Firebase
import GoogleSignIn
import FBSDKLoginKit

class ProfileViewController: UIViewController {
    
    
    var user: ChatAppUser! {
        didSet {
            if self.isViewLoaded {
                tableView.reloadSections(IndexSet(arrayLiteral: 0), with: .none)
            }
            downloadImage()
        }
    }
    
    var profileImage: UIImage? {
        didSet {
            tableView.reloadSections(IndexSet(arrayLiteral: 0), with: .none)
        }
    }
    
    // MARK:- Properties
    lazy var tableView: UITableView = {
        let table = UITableView()
        table.delegate = self
        table.dataSource = self
        table.register(ConversationsTableCell.self, forCellReuseIdentifier: cellId)
        return table
    }()
    
    
    // MARK:- Lifecycle Methods
    
    init(user: ChatAppUser) {
        super.init(nibName: nil, bundle: nil)
        self.user = user
        downloadImage()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        tableView.frame = view.bounds
        navigationItem.title = "Profile"
        navigationController?.navigationBar.prefersLargeTitles = true
        tableView.tableFooterView = UIView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }
    
    // MARK:- Selectors
    
    func logout() {
        do {
            try Auth.auth().signOut()
            presentLoginVC()
            FBSDKLoginKit.LoginManager().logOut()
            GIDSignIn.sharedInstance()?.signOut()
        } catch let error {
            print(error)
        }
    }
    
    func presentLoginVC(animated: Bool = true) {
        let loginVC = LoginViewController()
        let navVC = UINavigationController(rootViewController: loginVC)
        navVC.modalPresentationStyle = .fullScreen
        present(navVC, animated: animated, completion: nil)
    }
    
    // MARK:- UI Methods
    
    func downloadImage() {
        Service.shared.downloadUserImage(user: user) { [weak self] (image) in
            if let profilePic = image {
                DispatchQueue.main.async {
                    self?.profileImage = profilePic
                }
            } else {
                self?.profileImage = UIImage(systemName: "person.fill")
            }
        }
    }
}

extension ProfileViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: cellId)
        switch indexPath.section {
        case 0:
            let nameCell = ConversationsTableCell(style: .default, reuseIdentifier: cellId)
            nameCell.nameLabel.text = user?.fullName
            nameCell.nameLabel.font = UIFont.boldSystemFont(ofSize: 24)
            nameCell.subtitleLabel.text = "Hey there! I am using Whatsapp"
            nameCell.subtitleLabel.font = UIFont.systemFont(ofSize: 16)
            nameCell.imageSize = .init(width: 80, height: 80)
            if GIDSignIn.sharedInstance()?.currentUser == nil  && AccessToken.current == nil {
                nameCell.accessoryType = .disclosureIndicator
            } else {
                nameCell.accessoryType = .none
            }
            if let image = self.profileImage {
                nameCell.userImage.image = image
            } else {
                nameCell.userImage.image = UIImage(systemName: "person.fill")
            }
            return nameCell
        case 1:
            cell.textLabel?.text = "Contacts"
            cell.textLabel?.textAlignment = .left
            cell.textLabel?.font = UIFont.systemFont(ofSize: 18)
            cell.accessoryType = .disclosureIndicator
        case 2:
            cell.textLabel?.text = "Log out"
            cell.textLabel?.textAlignment = .center
            cell.textLabel?.font = UIFont.systemFont(ofSize: 20)
            cell.textLabel?.textColor = .red
        default:
            break
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            if tableView.cellForRow(at: indexPath)?.accessoryType == .disclosureIndicator {
                let editProfileVC = EditProfileViewController(user: user)
                editProfileVC.userImage = self.profileImage
                editProfileVC.delegate = self
                navigationController?.pushViewController(editProfileVC, animated: true)
            } else {
                tableView.cellForRow(at: indexPath)?.selectionStyle = .none
            }
        case 1:
            navigationController?.pushViewController(ContactsViewController(user: user), animated: true)
        case 2:
            self.logout()
        default:
            break
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            return 100
        case 1:
            return 60
        default:
            return 120
        }
    }
    
}


extension ProfileViewController: EditProfilViewControllerDelegate {
    func userDataChanged() {
        Service.shared.fetchUserData(uid: user.uid) { (user) in
            self.user = user
        }
    }
    
    
}
