//
//  LoginViewController.swift
//  ChatApp
//
//  Created by Mohamed Hashem on 7/15/20.
//  Copyright © 2020 Mohamed Hashem. All rights reserved.
//

import UIKit
import FBSDKLoginKit
import Firebase
import GoogleSignIn
import JGProgressHUD

class LoginViewController: UIViewController {
    
    
    // MARK:- Properties

    var loggedinUser: ChatAppUser? 
    
    let scrollView: UIScrollView = {
       let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.backgroundColor = .clear
        return scroll
    }()
    
    let logo: UIImageView = {
        let imageView = UIImageView()
        imageView.image = #imageLiteral(resourceName: "Logo")
        imageView.contentMode = .scaleAspectFit
        return imageView
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
    
    let registerButton: UIButton = {
        let button = UIButton(type: .system)
        let title = NSAttributedString(string: "Register", attributes: [.font : UIFont.boldSystemFont(ofSize: 16), .foregroundColor: UIColor.systemBlue])
        button.setAttributedTitle(title, for: .normal)
        return button
    }()
    
    lazy var loginButton: UIButton = {
        let button = UIButton(type: .system)
        let title = NSAttributedString(string: "Log In", attributes: [.font: UIFont.boldSystemFont(ofSize: 22), .foregroundColor: UIColor.white])
        button.setAttributedTitle(title, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)
        return button
    }()
    
    let fbLoginButton: FBLoginButton = {
        let button = FBLoginButton()
        button.layer.cornerRadius = 10
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 22)
        button.layer.masksToBounds = true
        button.permissions = ["public_profile", "email"]
        return button
    }()
    
    let googleLoginButton: GIDSignInButton = {
        let button = GIDSignInButton()
        button.layer.cornerRadius = 10
        button.layer.masksToBounds = true
        return button
    }()
    
    let dimmingView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.alpha = 0.5
        view.isHidden = true
        view.layer.cornerRadius = 10
        view.layer.masksToBounds = true
        return view
    }()
    
    let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        return indicator
    }()
    
    let spinner = JGProgressHUD(style: .dark)
    
    // MARK:- Lifecycle Methods
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        view.backgroundColor = .white
        view.addSubview(scrollView)
        scrollView.frame = view.bounds
        
        let stack = UIStackView(arrangedSubviews: [emailTextField, passwordTextField, loginButton, fbLoginButton, googleLoginButton])
        stack.axis = .vertical; stack.spacing = 15; stack.distribution = .fillEqually
        
        scrollView.addSubviews([logo, stack, dimmingView])
        dimmingView.addSubview(activityIndicator)
        
        title = "Log In"
        configureRegisterButton()
        let width = view.frame.width * 0.8
        
        logo.anchor(top: view.safeAreaLayoutGuide.topAnchor, topConstant: 40, centerX: scrollView.centerXAnchor, widthConstant: 150, heightConstant: 150)
        stack.anchor(top: logo.bottomAnchor, topConstant: 15, centerX: scrollView.centerXAnchor, widthConstant: width, heightConstant: 310)
        dimmingView.anchor(centerX: scrollView.centerXAnchor, centerY: scrollView.centerYAnchor, centerYConstant: -50, widthConstant: 75, heightConstant: 75)
        activityIndicator.anchor(centerX: dimmingView.centerXAnchor, centerY: dimmingView.centerYAnchor)
        
        scrollView.delegate = self
        fbLoginButton.delegate = self
        GIDSignIn.sharedInstance()?.delegate = self
        [emailTextField, passwordTextField].forEach { $0.delegate = self }
        
        configureGID()
    }
    
    
    // MARK:- Selectors
    
    @objc func goToRegister() {
        let registrationVC = RegistrationViewController()
        registrationVC.title = "Create Account"
        if navigationController != nil {
            navigationController?.pushViewController(registrationVC, animated: true)
        } else {
            self.present(registrationVC, animated: true)
        }
    }
    
    @objc func loginButtonTapped() {
        guard let email = emailTextField.text, let password = passwordTextField.text, !email.isEmpty, !password.isEmpty else { return }
        dimmingView.isHidden = false
        activityIndicator.startAnimating()
        Service.shared.loginUser(email: email, password: password) { [weak self] (user) in
            Service.shared.fetchUserData(uid: user.uid) { (fetchedUser) in
                self?.login(user: fetchedUser)
            }
        }
        
    }
    
    // MARK:- Methods
    
    func configureGID() {
        GIDSignIn.sharedInstance()?.presentingViewController = self
    }
    
    func login(user: ChatAppUser) {
        if let presentingVC = presentingViewController as? ContainerController {
            presentingVC.user = user
            presentingVC.dismiss(animated: true, completion: nil)
        } else {
            let containerVC = ContainerController(user: user)
            containerVC.modalPresentationStyle = .fullScreen
            self.present(containerVC, animated: true, completion: nil)
        }
    }
    
    func configureRegisterButton() {
        if navigationController != nil {
            let registerButton = UIBarButtonItem(title: "Register", style: .done, target: self, action: #selector(goToRegister))
            navigationItem.rightBarButtonItem = registerButton
        } else {
            view.addSubview(registerButton)
            registerButton.anchor(top: view.safeAreaLayoutGuide.topAnchor, topConstant: 10, trailing: view.trailingAnchor, trailingConstant: 10)
            registerButton.addTarget(self, action: #selector(goToRegister), for: .touchUpInside)
        }
    }
}


extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case emailTextField:
            passwordTextField.becomeFirstResponder()
        case passwordTextField:
            loginButtonTapped()
        default:
            return true
        }
        return true
    }
}

extension LoginViewController: UIScrollViewDelegate {
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        [emailTextField, passwordTextField].forEach { $0.resignFirstResponder() }
    }
    
}

// MARK:- Facebook Sign-in

extension LoginViewController: LoginButtonDelegate {
    
    func loginButton(_ loginButton: FBLoginButton, didCompleteWith result: LoginManagerLoginResult?, error: Error?) {
        if let error = error {
            print("WTF", error.localizedDescription)
            return
        }
        guard let token = result?.token else { return }
        let credential = FacebookAuthProvider.credential(withAccessToken: token.tokenString)
        self.spinner.show(in: self.view, animated: true)
        
        Auth.auth().signIn(with: credential) { [weak self] (result, error) in
            guard let self = self else { return }
            if let error = error { self.present(Service.shared.errorAlert(errorString: error.localizedDescription), animated: true, completion: nil) }
            guard let user = result?.user else { return }
            
            let facebookRequest = FBSDKLoginKit.GraphRequest(graphPath: "me",
                                                             parameters: ["fields": "email, name, picture.type(large)"],
                                                             tokenString: token.tokenString,
                                                             version: nil,
                                                             httpMethod: .get)
            facebookRequest.start { (connection, result, error) in
                if let error = error {
                    print("WTF unable to get FB creds: \(error.localizedDescription)")
                    return
                }
                guard let fbLoginResult = result as? [AnyHashable: Any] else { return }
                if let email = fbLoginResult["email"] as? String, let fullName = fbLoginResult["name"] as? String {
                    Service.shared.checkUser(uid: user.uid, email: email) { (userExists) in
                        switch userExists {
                        case true:
                            Service.shared.fetchUserData(uid: user.uid) { (fetchedUser) in
                                self.loggedinUser = fetchedUser
                                self.login(user: fetchedUser)
                            }
                        case false:
                            user.updateEmail(to: email, completion: nil)
                            let values: [AnyHashable: Any] = ["email": email, "fullName": fullName]
                            let newUser = ChatAppUser(email: email, fullName: fullName, uid: user.uid)
                            self.loggedinUser = newUser
                            REF_USERS.child(user.uid).setValue(values) { (error, ref) in
                                self.login(user: newUser)
                            }
                        }
                        Service.shared.getFBProfilePic(picData: fbLoginResult["picture"]) { (image) in
                            guard let profilePic = image else { return }
                            Service.shared.uploadUserImage(image: profilePic, uid: user.uid) { (firebaseUrl) in
                                guard let firebaseUrl = firebaseUrl else { return }
                                REF_USERS.child(user.uid).updateChildValues(["imageURL": firebaseUrl.absoluteString])
                            }
                        }
                    }
                }
            }
        }
    }
    
    func loginButtonDidLogOut(_ loginButton: FBLoginButton) {
        
    }
}

// MARK:- Google Sign in

extension LoginViewController: GIDSignInDelegate {
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        if let error = error {
            print("WTF google sign in error: \(error.localizedDescription)")
        } else if let googleUser = user {
            dimmingView.isHidden = false
            activityIndicator.startAnimating()
            guard let email = googleUser.profile.email,
                let fullName = googleUser.profile.name,
                let idToken = googleUser.authentication.idToken,
                let accessToken = googleUser.authentication.accessToken
                else { return }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            Auth.auth().signIn(with: credential) { (result, error) in
                if let error = error { print("WTF unable to google sign in: \(error)") }
                guard let user = result?.user else { return }
                Service.shared.checkUser(uid: user.uid, email: email) { [weak self] (userExists) in
                    switch userExists {
                    case true:
                        Service.shared.fetchUserData(uid: user.uid) { (fetchedUser) in
                            self?.loggedinUser = fetchedUser
                            self?.login(user: fetchedUser)
                        }
                    case false:
                        user.updateEmail(to: email, completion: nil)
                        let values: [AnyHashable: Any] = ["email": email, "fullName": fullName]
                        let newUser = ChatAppUser(email: email, fullName: fullName, uid: user.uid)
                        self?.loggedinUser = newUser
                        REF_USERS.child(user.uid).setValue(values) { (error, ref) in
                            self?.login(user: newUser)
                        }
                    }
                    if let imageURL = googleUser.profile.imageURL(withDimension: 300) {
                        Service.shared.getGoogleProfilePic(urlString: imageURL.absoluteString) { (image) in
                            if let profilePic = image {
                                Service.shared.uploadUserImage(image: profilePic, uid: user.uid) { (url) in
                                    guard let url = url else { return }
                                    REF_USERS.child(user.uid).updateChildValues(["imageURL": url.absoluteString])
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
