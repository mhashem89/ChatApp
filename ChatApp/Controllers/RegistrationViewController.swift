//
//  RegistrationViewController.swift
//  ChatApp
//
//  Created by Mohamed Hashem on 7/15/20.
//  Copyright © 2020 Mohamed Hashem. All rights reserved.
//

import UIKit
import Firebase


class RegistrationViewController: UIViewController {
    
    
    // MARK:- Properties
    
    let scrollView: UIScrollView = {
       let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.backgroundColor = .clear
        return scroll
    }()
    
    let userImage: UIImageView = {
        let imageView = UIImageView()
        imageView.image = #imageLiteral(resourceName: "profile-icon-png")
        imageView.contentMode = .scaleAspectFill
        imageView.isUserInteractionEnabled = true
        imageView.layer.cornerRadius = 75
        imageView.clipsToBounds = true
        return imageView
    }()
    
    let fullNameTextField: UITextField = {
        let tf = UITextField.setupTextField(placeholderText: "Full Name...")
        tf.returnKeyType = .continue
        return tf
    }()
    
    let emailTextField: UITextField = {
        let tf = UITextField.setupTextField(placeholderText: "Email Address...", isSecureEntry: false)
        tf.returnKeyType = .continue
        return tf
    }()
    
    let passwordTextField: UITextField = {
        let tf = UITextField.setupTextField(placeholderText: "Password...", isSecureEntry: true)
        tf.returnKeyType = .done
        return tf
    }()
    
    lazy var registerButton: UIButton = {
        let button = UIButton(type: .system)
        let title = NSAttributedString(string: "Register", attributes: [.font: UIFont.boldSystemFont(ofSize: 22), .foregroundColor: UIColor.white])
        button.setAttributedTitle(title, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(didTapRegisterButton), for: .touchUpInside)
        return button
    }()
    
    
    // MARK:- Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        view.addSubview(scrollView)
        scrollView.frame = view.bounds
        
        let stack = UIStackView(arrangedSubviews: [fullNameTextField, emailTextField, passwordTextField, registerButton])
        stack.axis = .vertical; stack.spacing = 15; stack.distribution = .fillEqually
        
        scrollView.addSubviews([userImage, stack])
        
        let width = view.frame.width * 0.8
        userImage.anchor(top: view.safeAreaLayoutGuide.topAnchor, topConstant: 40, centerX: scrollView.centerXAnchor, widthConstant: 150, heightConstant: 150)
        stack.anchor(top: userImage.bottomAnchor, topConstant: 15, centerX: scrollView.centerXAnchor, widthConstant: width, heightConstant: 300)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapUserImage))
        tap.numberOfTapsRequired = 1
        userImage.addGestureRecognizer(tap)
        
        [fullNameTextField, emailTextField, passwordTextField].forEach { $0.delegate = self }
        scrollView.delegate = self
        
    }
    
    // MARK:- Selectors
    
    @objc func didTapRegisterButton() {
        guard
            let fullName = fullNameTextField.text,
            let email = emailTextField.text,
            let password = passwordTextField.text
            else { return }
        Service.shared.createUser(fullName: fullName, email: email, password: password) { [weak self] (uid) in
            let signupAlert = UIAlertController(title: "Sign up successful!", message: "User created", preferredStyle: .alert)
            signupAlert.addAction(UIAlertAction(title: "Go to Login", style: .default, handler: { (_) in
                self?.dismissView()
            }))
            self?.present(signupAlert, animated: true, completion: nil)
            if let profilePic = self?.userImage.image, !profilePic.isEqual(#imageLiteral(resourceName: "profile-icon-png")) {
                Service.shared.uploadUserImage(image: profilePic, uid: uid) { (url) in
                    guard let urlString = url?.absoluteString else { return }
                    REF_USERS.child(uid).updateChildValues(["imageURL": urlString])
                }
            }
        }
    }
    
    @objc func didTapUserImage() {
        presentPictureAction()
    }
    
    func dismissView() {
        if navigationController != nil {
            navigationController?.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
    
    // MARK:- UI Methods
    
   
}


extension RegistrationViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case fullNameTextField:
            emailTextField.becomeFirstResponder()
        case emailTextField:
            passwordTextField.becomeFirstResponder()
        case passwordTextField:
            didTapRegisterButton()
        default:
            return true
        }
        return true
    }
}

extension RegistrationViewController: UIScrollViewDelegate {
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        [fullNameTextField, emailTextField, passwordTextField].forEach { $0.resignFirstResponder() }
    }
    
}

extension RegistrationViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func presentPictureAction() {
        let actionSheet = UIAlertController(title: "Profile Picture",
                                            message: "How would you like to take your picture?",
                                            preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Cancel",
                                            style: .cancel,
                                            handler: nil))
        actionSheet.addAction(UIAlertAction(title: "Camera",
                                            style: .default,
                                            handler: { [unowned self] (_) in
                                                self.presentCamera()
        }))
        actionSheet.addAction(UIAlertAction(title: "Photo Library",
                                            style: .default,
                                            handler: { [unowned self] (_) in
                                                self.presentImagePicker()
        }))
        present(actionSheet, animated: true)
    }
    
    func presentImagePicker() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        show(picker, sender: self)
    }
    
    func presentCamera() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        show(picker, sender: self)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let selectedImage = info[.originalImage] as? UIImage else { return }
        userImage.image = selectedImage
        dismiss(animated: true, completion: nil)
    }
    
}
