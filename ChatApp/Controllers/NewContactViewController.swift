//
//  NewContactViewController.swift
//  ChatApp
//
//  Created by Mohamed Hashem on 7/21/20.
//  Copyright © 2020 Mohamed Hashem. All rights reserved.
//

import UIKit
import Firebase

protocol NewContactControllerDelegate: class {
    func newContactAdded()
}

class NewContactViewController: UIViewController {
    
    
    // MARK:- Properties
    
    var user: ChatAppUser!
    
    weak var delegate: NewContactControllerDelegate?
    
    let nameLabel: UILabel = {
        let label = UILabel()
        label.text = "Name"
        label.font = UIFont.boldSystemFont(ofSize: 22)
        return label
    }()
    
    let emailLabel: UILabel = {
        let label = UILabel()
        label.text = "Email"
        label.font = UIFont.boldSystemFont(ofSize: 22)
        return label
    }()
    
    let nameTextField: UITextField = {
        let tf = UITextField()
        tf.addLeftPadding(10)
        tf.attributedPlaceholder = NSAttributedString(string: "Full Name", attributes: [.font: UIFont.systemFont(ofSize: 22)])
        tf.defaultTextAttributes = [.font: UIFont.systemFont(ofSize: 20)]
        tf.clearButtonMode = .whileEditing
        return tf
    }()

    let emailTextField: UITextField = {
        let tf = UITextField()
        tf.addLeftPadding(10)
        tf.attributedPlaceholder = NSAttributedString(string: "Email", attributes: [.font: UIFont.systemFont(ofSize: 22)])
        tf.defaultTextAttributes = [.font: UIFont.systemFont(ofSize: 20)]
        tf.autocapitalizationType = .none
        return tf
    }()
    
    let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView()
        indicator.style = .medium
        indicator.isHidden = true
        indicator.color = .black
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    
    let notOnAppLabel: UILabel = {
        let label = UILabel()
        label.attributedText = NSAttributedString(string: "Not on ChatApp", attributes: [.font: UIFont.systemFont(ofSize: 13), .foregroundColor: UIColor.lightGray])
        return label
    }()

    let bottomLine = UIView()
    
    let checkMark = UIImageView(image: UIImage(systemName: "checkmark.seal.fill"))
    
    var email: String? {
        didSet {
            if email != nil, name != nil {
                navigationItem.rightBarButtonItem?.isEnabled = true
            } else {
                navigationItem.rightBarButtonItem?.isEnabled = false
            }
        }
    }
    
    var name: String? {
        didSet {
            if let _ = self.email {
                navigationItem.rightBarButtonItem?.isEnabled = true
            }
        }
    }
    
    // MARK:- Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "New Contact"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save))
        navigationItem.rightBarButtonItem?.isEnabled = false
        
        setupUI()
        nameTextField.delegate = self
        emailTextField.delegate = self
        
        
    }
    
    init(user: ChatAppUser) {
        super.init(nibName: nil, bundle: nil)
        self.user = user
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK:- Selectors
    
    @objc func cancel() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func save() {
        guard !checkMark.isHidden else { return }
        guard let name = nameTextField.text, !name.isEmpty else { present(Service.shared.errorAlert(errorString: "Name Field is Empty"), animated: true); return }
        guard let email = emailTextField.text, !email.isEmpty else { present(Service.shared.errorAlert(errorString: "Name Field is Empty"), animated: true); return }
        Service.shared.locateUserByEmail(email: email) { (uid) in
            REF_USERS.child(self.user.uid).child("contacts").updateChildValues([uid: name])
            self.delegate?.newContactAdded()
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    
    // MARK:- UI Methods

    func setupUI() {
        view.addSubviews([nameLabel, nameTextField, emailLabel, emailTextField])
        
        let width = view.frame.width
        let height = view.frame.height
        nameLabel.frame = CGRect(x: width * 0.03, y: height * 0.1, width: 50, height: 50)
        nameLabel.sizeToFit()
        
        emailLabel.frame = CGRect(x: width * 0.03, y: (height * 0.1) + 20 + nameLabel.frame.height, width: 50, height: 50)
        emailLabel.sizeToFit()
        
        nameTextField.frame = CGRect(x: 30 + nameLabel.frame.width, y: height * 0.1, width: view.frame.width * 0.80, height: nameLabel.frame.height)
        emailTextField.frame = CGRect(x: nameTextField.frame.origin.x, y: emailLabel.frame.origin.y, width: view.frame.width * 0.80, height: emailLabel.frame.height + 10)
        emailTextField.contentVerticalAlignment = .top
        
        nameTextField.addBottomSeparatorLine(padding: -5)

        
        
        bottomLine.backgroundColor = .lightGray
        emailTextField.addSubview(bottomLine)
        bottomLine.frame = .init(x: 10, y: emailTextField.frame.height - 5, width: emailTextField.frame.width, height: 0.5)
        
        emailTextField.addSubview(activityIndicator)
        activityIndicator.frame = CGRect(x: emailTextField.frame.width - 40, y: (emailTextField.frame.height / 2) - 5, width: 5, height: 5)
        
        emailTextField.addSubview(checkMark)
        checkMark.frame = CGRect(x: emailTextField.frame.width - 40, y: (emailTextField.frame.height / 2) - 15, width: 20, height: 20)
        
        checkMark.isHidden = true
        emailTextField.addSubview(notOnAppLabel)
        notOnAppLabel.isHidden = true
        notOnAppLabel.alpha = 0
        notOnAppLabel.anchor(leading: emailTextField.leadingAnchor, leadingConstant: 10, bottom: emailTextField.bottomAnchor, bottomConstant: -7)
    }
    
}

extension NewContactViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if textField == emailTextField, let text = textField.text {
            switch string.isEmpty {
            case false:
                if text.split(separator: ".").last == "co" {
                    activityIndicator.startAnimating()
                    Auth.auth().fetchSignInMethods(forEmail: text + "m") { (methods, error) in
                        DispatchQueue.main.async {
                            self.activityIndicator.stopAnimating()
                            if let error = error { print("WTF", error.localizedDescription); return }
                            if let _ = methods {
                                self.checkMark.isHidden = false
                                self.email = text
                            }
                            if methods == nil {
                                self.notOnAppLabel.isHidden = false
                                self.email = nil
                                UIView.animate(withDuration: 0.2) {
                                    self.bottomLine.frame.origin.y += 12
                                    self.notOnAppLabel.alpha = 1
                                }
                            }
                        }
                    }
                }
            case true:
                self.navigationItem.rightBarButtonItem?.isEnabled = false
                if !self.notOnAppLabel.isHidden {
                    self.notOnAppLabel.isHidden = true
                    UIView.animate(withDuration: 0.2) {
                        self.bottomLine.frame.origin.y -= 12
                        self.notOnAppLabel.alpha = 0
                    }
                }
                if !self.checkMark.isHidden {
                    self.email = nil
                    self.checkMark.isHidden = true
                }
            }
        } else if textField == nameTextField, let name = textField.text, !name.isEmpty {
            self.name = name
        }
        return true
    }
    
    
    
}


