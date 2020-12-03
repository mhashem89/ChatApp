//
//  ChatViewController.swift
//  ChatApp
//
//  Created by Mohamed Hashem on 7/17/20.
//  Copyright © 2020 Mohamed Hashem. All rights reserved.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import Firebase
import JGProgressHUD
import AVFoundation
import AVKit
import CoreLocation
import Combine

class ChatViewController: MessagesViewController {
    
    // MARK:- Properties
    
    var messages = [Message]() {
        didSet {
            DispatchQueue.main.async {
                self.messagesCollectionView.reloadData()
                self.spinner.dismiss()
                if self.messageInputBar.inputTextView.isFirstResponder { self.messagesCollectionView.scrollToLastItem() }
            }
        }
    }
    
    var chatViewModel: ChatViewModel!
    var cancellables = Set<AnyCancellable>()
    
    var contact: ChatAppUser!
    var user: ChatAppUser!
    
    var userImage: UIImage?
    var contactImage: UIImage?
    
    var spinner = JGProgressHUD(style: .dark)
    
    var profileView = ImageViewer()
    var selectedImageView = ImageViewer()
    var selectedCellFrame: CGRect?
    
    var pickedImageView = PickedImageView()
    var pickedVideoView = PickedVideoView()
    
    var pickedVideoURL: URL?
    
    var navTitleView = TitleView()
    
    var picker = UIImagePickerController()
    
    var audioRecorder: AVAudioRecorder!
    var audioSession: AVAudioSession!
    
    var audioPlayer: AVAudioPlayer!
    var cellAudioTimer: Timer?
    
    let profileImagePanGesture: UIPanGestureRecognizer = {
        let pan = UIPanGestureRecognizer()
        return pan
    }()
    
    lazy var pickImageTapGesture: UITapGestureRecognizer = {
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleImagePickerTap))
        tap.numberOfTapsRequired = 1
        return tap
    }()
    
    lazy var imageViewerTapGesture: UITapGestureRecognizer = {
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.imageViewerTap))
        tap.numberOfTapsRequired = 1
        return tap
    }()
    
    lazy var recordButtonPan: UIPanGestureRecognizer = {
        let pan = UIPanGestureRecognizer()
        pan.delegate = self
        return pan
    }()
    
    lazy var longPressGesture: UILongPressGestureRecognizer = {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(self.handleMicButtonPress(_:)))
        longPress.minimumPressDuration = 0.7
        longPress.numberOfTouchesRequired = 1
        longPress.delegate = self
        longPress.canBePrevented(by: self.recordButtonPan)
        return longPress
    }()
    
    var messageTime = String()
    
    var keyboardObserver: Any?
    
    let plusButton = InputBarButtonItem(type: .system)
    let micButton = InputBarButtonItem(type: .system)
        
    var imagePickerTapLocation: CGPoint?
    
    var audioCellDuration: Double = 0
    
    let sentTag = NSAttributedString(string: " - sent ✓", attributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.systemGray])
    let deliveredTag = NSAttributedString(string: " - delivered ✓", attributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.systemGray])
    let readTag = NSAttributedString(string: " - read ✓", attributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.systemBlue])

    
    // MARK:- Lifecycle Methods
    
    init(user: ChatAppUser, contact: ChatAppUser) {
        super.init(nibName: nil, bundle: nil)
        self.user = user
        self.contact = contact
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        chatViewModel = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        messagesCollectionView.backgroundColor = .white
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self
        messageInputBar.inputTextView.delegate = self
        scrollsToBottomOnKeyboardBeginsEditing = true
        self.hidesBottomBarWhenPushed = true
        
        Service.shared.downloadUserImage(user: user) { [weak self] (image) in
            if let userImage = image {
                DispatchQueue.main.async {
                    self?.userImage = userImage
                }
            }
        }
        
        DispatchQueue.global().async { [unowned self] in
            self.chatViewModel = ChatViewModel(user: self.user, contact: self.contact, completion: {
                if self.chatViewModel.conversation != nil {
                    DispatchQueue.main.async {
                        self.spinner.show(in: self.view)
                        self.chatViewModel.monitorConversation()
                        self.fetchMessagesFromViewModel()
                    }
                }
            })
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupNavBar()
        setupInputBar()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messagesCollectionView.scrollToBottom(animated: false)
    }
    
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if let conversation = chatViewModel.conversation {
            REF_CONVERSATIONS.child(conversation.uid).child("messages").removeAllObservers()
        }
    }
    
    
    // MARK:- Methods
    
    func fetchMessagesFromViewModel() {
         chatViewModel.$conversation
         .map { $0!.messages }
         .receive(on: RunLoop.main)
         .sink { [weak self] (messages) in
             let sortedMessages = messages.sorted(by: { $0.sentDate < $1.sentDate })
            self?.messages = sortedMessages
         }
         .store(in: &self.cancellables)
     }
    
    func createNewConversation(with message: Message) {
        let newConversation = ConversationManager.shared.createNewConversation(users: [user, contact], message: message)
        ConversationManager.shared.uploadConversation(conversation: newConversation)
        chatViewModel.conversation = newConversation
        chatViewModel.conversation?.messages.removeAll()
        chatViewModel.monitorConversation()
        fetchMessagesFromViewModel()
    }
    
    func setupNavBar() {
        navigationItem.titleView = navTitleView
        
        REF_USERS.child(user.uid).child("contacts").child(contact.uid).observeSingleEvent(of: .value) { [weak self] (snapshot) in
            self?.navTitleView.nameLabel.text = snapshot.value as? String ?? self?.contact.fullName
            self?.navTitleView.setupSubViews()
        }
        REF_USERS.child(contact.uid).child("status").observe(.value) { [weak self] (snapshot) in
            guard let status = snapshot.value as? String else { return }
            self?.contact.status = Service.shared.returnUserStatus(statusString: status)
            if status != "offline" {
                self?.navTitleView.showStatus(status: status)
            } else {
                self?.navTitleView.hideStatus()
            }
        }
        
        
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.leftItemsSupplementBackButton = true
        
        Service.shared.downloadUserImage(user: contact) { [weak self] (image) in
            if let contactImage = image {
                DispatchQueue.main.async {
                    self?.contactImage = contactImage
                    let button = UIButton(type: .system)
                    button.anchor(widthConstant: 36, heightConstant: 36)
                    button.layer.cornerRadius = 18
                    button.contentMode = .scaleAspectFit
                    button.setImage(self?.contactImage?.withRenderingMode(.alwaysOriginal), for: .normal)
                    button.clipsToBounds = true
                    button.addTarget(self, action: #selector(self?.showContactInfo), for: .touchUpInside)
                    let navBarContact = UIBarButtonItem(customView: button)
                    self?.navigationItem.leftBarButtonItem = navBarContact
                }
            }
        }
    }
    
    
    // MARK:- Selectors
    
    @objc func showContactInfo() {
        messageInputBar.inputTextView.resignFirstResponder()
        profileView = ImageViewer()
        view.addSubview(profileView)
        profileView.imageView.image = contactImage
        profileView.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
        profileView.backgroundColor = .white
        profileView.scrollView.delegate = self
        tabBarController?.tabBar.isHidden = true
        navigationItem.leftItemsSupplementBackButton = false
        let backButton = UIButton(type: .system)
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        if let firstName = contact.fullName.split(separator: " ").first { backButton.setTitle(String("  \(firstName)"), for: .normal) }
        backButton.addTarget(self, action: #selector(hideContactInfo), for: .touchUpInside)
        backButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: -15, bottom: 0, right: 0)
        let backBarButton = UIBarButtonItem(customView: backButton)
        navigationItem.setLeftBarButton(backBarButton, animated: true)
        UIView.animate(withDuration: 0.3, animations: {
            self.profileView.frame.size.width = self.view.frame.size.width
            self.profileView.frame.size.height = self.view.frame.size.height
            self.profileView.setupViews()
            self.profileView.imageView.frame = CGRect(x: 0, y: self.profileView.frame.height * 0.2, width: self.profileView.frame.width, height: self.profileView.frame.height * 0.6)
            self.title = "Contact Info"
            self.messageInputBar.isHidden = true
        }) { (_) in
            self.profileView.imageView.addGestureRecognizer(self.profileImagePanGesture)
            self.profileImagePanGesture.addTarget(self, action: #selector(self.profileViewPan(_:)))
        }
    }
    
    @objc func hideContactInfo() {
        navigationItem.leftBarButtonItems = []
        UIView.animate(withDuration: 0.5, animations: {
            self.profileView.imageView.frame.origin.x = 50
            self.profileView.imageView.frame.origin.y = 20
            self.profileView.imageView.frame.size.height = 36
            self.profileView.imageView.frame.size.width = 36
            self.profileView.imageView.layer.cornerRadius = 18
            self.messageInputBar.isHidden = false
        }) { (_) in
            self.setupNavBar()
            self.profileView.imageView.clipsToBounds = true
            self.profileView.frame = .zero
            self.profileView.removeFromSuperview()
            self.tabBarController?.tabBar.isHidden = false
        }
    }
    
  
    
    @objc func profileViewPan(_ pan: UIPanGestureRecognizer) {
        if pan.translation(in: self.profileView).y > 0 {
            switch pan.state {
            case.began:
                profileView.imageView.addBorderShadow()
            case .changed:
                let translation = pan.translation(in: self.profileView)
                let change = translation.y * 0.005
                let translateTransform = CGAffineTransform(translationX: translation.x, y: translation.y)
                let scaleTransform = CGAffineTransform(scaleX: 1 - (change * 0.09), y: 1 - (change * 0.09))
                profileView.imageView.layer.shadowOpacity = Float(0.55 + change)
                profileView.imageView.transform = translateTransform.concatenating(scaleTransform)
                profileView.backgroundColor = UIColor.white.withAlphaComponent(1 - change)
            case .ended:
                hideContactInfo()
            case .cancelled:
                profileView.backgroundColor = .white
                profileView.imageView.frame = CGRect(x: 0, y: profileView.frame.height * 0.2, width: profileView.frame.width, height: profileView.frame.height * 0.6)
            default:
                return
            }
        }
    }
    
    @objc func hideImageViewer() {
        navigationItem.leftBarButtonItems = []
        if let selectedCellFrame = self.selectedCellFrame {
            UIView.animate(withDuration: 0.5, animations: {
                self.selectedImageView.backgroundColor = UIColor.white.withAlphaComponent(0)
                self.selectedImageView.imageView.contentMode = .scaleAspectFill
                self.selectedImageView.imageView.layer.cornerRadius = 15
                self.selectedImageView.imageView.clipsToBounds = true
                self.selectedImageView.imageView.frame.origin.x = selectedCellFrame.origin.x
                self.selectedImageView.imageView.frame.origin.y = selectedCellFrame.origin.y
                self.selectedImageView.imageView.frame.size.width = 300
                self.selectedImageView.imageView.frame.size.height = 300
                self.messageInputBar.isHidden = false
            }) { (_) in
                self.navigationController?.navigationBar.isHidden = false
                self.setupNavBar()
                self.selectedImageView.removeFromSuperview()
                self.selectedImageView = ImageViewer()
                self.selectedImageView.frame = .zero
                self.selectedImageView.removeFromSuperview()
                self.tabBarController?.tabBar.isHidden = false
            }
        }
        
    }
    
    @objc func imageViewerPan(_ pan: UIPanGestureRecognizer) {
        if pan.translation(in: profileView).y > 0 {
            switch pan.state {
            case.began:
                selectedImageView.imageView.addBorderShadow()
            case .changed:
                let translation = pan.translation(in: profileView)
                let change = translation.y * 0.005
                let translateTransform = CGAffineTransform(translationX: translation.x, y: translation.y)
                let scaleTransform = CGAffineTransform(scaleX: 1 - (change * 0.09), y: 1 - (change * 0.09))
                selectedImageView.imageView.layer.shadowOpacity = Float(0.55 + change)
                selectedImageView.imageView.transform = translateTransform.concatenating(scaleTransform)
                selectedImageView.backgroundColor = UIColor.white.withAlphaComponent(1 - change)
            case .ended:
                hideImageViewer()
            case .cancelled:
                selectedImageView.backgroundColor = .white
                selectedImageView.imageView.frame = selectedImageView.frame
            default:
                return
            }
        }
    }
    
    @objc func imageViewerTap() {
        navigationController?.navigationBar.isHidden.toggle()
    }
    

    @objc func barPlusButtonTapped() {
        self.picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = false
        self.picker.mediaTypes = ["public.image", "public.movie"]
        picker.modalPresentationStyle = .overCurrentContext
        self.tabBarController?.tabBar.isHidden = true
        let optionsAlert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        optionsAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        optionsAlert.addAction(UIAlertAction(title: "Camera", style: .default, handler: { (_) in
             self.picker.sourceType = .camera
             self.present(self.picker, animated: true, completion: nil)
        }))
        optionsAlert.addAction(UIAlertAction(title: "Photo & Video Library", style: .default, handler: { (_) in
            self.picker.sourceType = .photoLibrary
            self.present(self.picker, animated: true, completion: nil)
        }))
        optionsAlert.addAction(UIAlertAction(title: "Location", style: .default, handler: { (_) in
            let mapVC = MapViewController()
            mapVC.delegate = self
            let navVC = UINavigationController(rootViewController: mapVC)
            navVC.modalPresentationStyle = .overCurrentContext
            self.present(navVC, animated: true, completion: nil)
        }))
        present(optionsAlert, animated: true)
    }
    
    
    var timerView = TimerView()
    
    fileprivate func extractedFunc() {
        audioSession = AVAudioSession.sharedInstance()
        messageInputBar.addSubview(timerView)
        recordButtonPan.addTarget(self, action: #selector(self.swipeTimerView(_:)))
        messageInputBar.separatorLine.isHidden = true
        timerView.frame = CGRect(x: messageInputBar.inputTextView.frame.origin.x + messageInputBar.inputTextView.frame.width,
                                 y: messageInputBar.inputTextView.frame.origin.y,
                                 width: 0,
                                 height: messageInputBar.inputTextView.frame.height)
        UIView.animate(withDuration: 0.3) {
            self.timerView.frame.origin.x = self.messageInputBar.inputTextView.frame.origin.x
            self.timerView.frame.size.width = self.messageInputBar.inputTextView.frame.width
            self.timerView.setupViews()
        }
    }
    
    @objc func handleMicButtonPress(_ press: UILongPressGestureRecognizer) {
        let dateString = ConversationManager.shared.dateFormatter.string(from: Date())
        let fileName = "\(user.uid)_\(contact.uid)_\(dateString)"
        switch press.state {
        case .began:
            extractedFunc()
            let filePath = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("\(fileName).m4a")
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            if let filePath = filePath {
                do {
                    try audioSession.setCategory(.playAndRecord, mode: .default)
                    try audioSession.setActive(true)
                    self.audioRecorder = try AVAudioRecorder(url: filePath, settings: settings)
                    audioRecorder.prepareToRecord()
                    audioRecorder.record()
                    Service.shared.updateUserStatus(user: user, status: .recordingAudio)
                } catch let err {
                    print("WTF", err.localizedDescription)
                }
            }
        case .ended:
            Service.shared.updateUserStatus(user: user, status: .online)
            if audioRecorder != nil {
                let duration = self.audioRecorder.currentTime.rounded()
                self.timerView.invalidateTimer = true
                self.audioRecorder.stop()
                UIView.animate(withDuration: 0.3, animations: {
                    self.timerView.frame.origin.x = 0
                    self.timerView.frame.size.width = 0
                }) { (_) in
                    self.timerView.removeFromSuperview()
                    self.timerView = TimerView()
                    self.messageInputBar.separatorLine.isHidden = false
                    if duration >= 1 {
                        self.spinner.show(in: self.view)
                        ConversationManager.shared.createAudioMessage(sender: self.user, receiver: self.contact, recorder: self.audioRecorder, duration: duration) { (message) in
                            guard let audioMessage = message else { return }
                            self.audioRecorder = nil
                            if self.chatViewModel.conversation != nil {
                                self.chatViewModel.uploadAudioMessage(message: audioMessage) {
                                }
                            } else {
                                self.createNewConversation(with: audioMessage)
                            }
                        }
                    }
                }
                
            } else {
                print("WTF DID NOT RECORD")
            }
        default:
            break
        }
        
    }
    
    @objc func swipeTimerView(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .changed:
            let translation = gesture.translation(in: messageInputBar)
            if translation.x < 0 {
                micButton.transform = CGAffineTransform(translationX: translation.x, y: 0)
                if translation.x < -view.frame.width * 0.1 {
                    Service.shared.updateUserStatus(user: user, status: .online)
                    micButton.removeGestureRecognizer(recordButtonPan)
                    micButton.removeGestureRecognizer(longPressGesture)
                    UIView.animate(withDuration: 0.3, animations: {
                        self.micButton.transform = .identity
                    }) { (_) in
                        self.micButton.addGestureRecognizer(self.longPressGesture)
                        self.micButton.addGestureRecognizer(self.recordButtonPan)
                        self.messageInputBar.separatorLine.isHidden = false
                    }
                }
            }
        case .ended:
            micButton.transform = CGAffineTransform(translationX: .zero, y: .zero)
            micButton.addGestureRecognizer(longPressGesture)
            self.messageInputBar.separatorLine.isHidden = false
        default:
            break
        }
        
        UIView.animate(withDuration: 0.3) {
            self.timerView.frame.size.width = 0
            self.timerView.removeFromSuperview()
            self.timerView = TimerView()
        }
    }
    
    @objc func handleKeyboard(notification: Notification) {
        if let userInfo = notification.userInfo, let keyboadFrame = userInfo["UIKeyboardFrameEndUserInfoKey"] as? CGRect {
            if picker.view.subviews.contains(pickedImageView) {
                pickedImageView.scrollView.contentSize = CGSize(width: view.frame.width, height: view.frame.height - keyboadFrame.height)
                if pickedImageView.scrollView.zoomScale != 1 { pickedImageView.scrollView.setZoomScale(1, animated: true) }
                pickedImageView.dimmingView.isHidden = false
                pickedImageView.scrollView.alwaysBounceVertical = true
                let safeAreaTop = UIApplication.shared.windows.filter { $0.isKeyWindow }.first?.safeAreaInsets.top ?? 0
                UIView.animate(withDuration: 0.3, animations: {
                    self.pickedImageView.scrollView.frame.origin.y = safeAreaTop
                    self.pickedImageView.pickedImageView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                    self.pickedImageView.captionTextField.frame.origin.y -= (keyboadFrame.height - 30)
                    self.pickedImageView.sendButton.frame.origin.y -= (keyboadFrame.height - 30)
                }) { (_) in
                    self.pickedImageView.scrollView.addGestureRecognizer(self.pickImageTapGesture)
                    NotificationCenter.default.removeObserver(self.keyboardObserver as Any)
                }
            } else if picker.view.subviews.contains(pickedVideoView) {
                UIView.animate(withDuration: 0.3, animations: {
                    self.pickedVideoView.lowerBarView.frame.origin.y -= (keyboadFrame.height - 20)
                }) { (_) in
                    NotificationCenter.default.removeObserver(self.keyboardObserver as Any)
                }
            }
        }
    }
    
    @objc func handleImagePickerTap() {
        pickedImageView.scrollView.removeGestureRecognizer(self.pickImageTapGesture)
        pickedImageView.captionTextField.resignFirstResponder()
        pickedImageView.scrollView.contentSize = view.frame.size
        pickedImageView.dimmingView.isHidden = true
        pickedImageView.scrollView.alwaysBounceVertical = false
        UIView.animate(withDuration: 0.3) {
            self.pickedImageView.scrollView.frame.origin.y = 0
            self.pickedImageView.pickedImageView.transform = CGAffineTransform(scaleX: 1, y: 1)
            self.pickedImageView.captionTextField.frame.origin.y = self.view.frame.height * 0.9
            self.pickedImageView.sendButton.frame.origin.y = self.view.frame.height * 0.885
        }
        keyboardObserver = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: nil, using: { [weak self] (notification) in
            self?.handleKeyboard(notification: notification)
        })
    }
    
   
    @objc func dismissPickedImageView()  {
        pickedImageView.scrollView.removeGestureRecognizer(pickImageTapGesture)
        if pickedImageView.dimmingView.isHidden == false {
            handleImagePickerTap()
        }
        UIView.animate(withDuration: 0.1, animations: {
            self.pickedImageView.frame.origin.y = self.view.frame.height
        }) { (_) in
            NotificationCenter.default.removeObserver(self.keyboardObserver as Any)
            self.pickedImageView.removeFromSuperview()
            self.pickedImageView = PickedImageView()
        }
    }
    
    @objc func dismissPickedVideoView() {
        pickedVideoView.captionBar.resignFirstResponder()
        UIView.animate(withDuration: 0.2, animations: {
            self.pickedVideoView.closeButton.frame.origin.y = 0
            self.pickedVideoView.captionBar.frame.origin.y = self.view.frame.height
        }) { (_) in
            self.pickedVideoView.removeFromSuperview()
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    @objc func sendVideoMessage() {
        if let pickedVideoURL = self.pickedVideoURL {
            let captionText = pickedVideoView.captionBar.text
            dismiss(animated: true, completion: nil)
            messageInputBar.inputTextView.resignFirstResponder()
            tabBarController?.tabBar.isHidden = false
            let placeholderMessage = ConversationManager.shared.createVideoMessagePlaceHolder(sender: user, receiver: contact, caption: captionText ?? nil)
            if chatViewModel.conversation != nil {
                chatViewModel.uploadPlaceHolderMessage(message: placeholderMessage)
            } else {
                createNewConversation(with: placeholderMessage)
            }
            chatViewModel.uploadVideo(videoURL: pickedVideoURL, message: placeholderMessage, captionText: captionText)
        }
    }
    
    @objc func sendPhotoMessage() {
        if let pickedImage = pickedImageView.pickedImageView.image {
            let captionText = pickedImageView.captionTextField.text
            dismiss(animated: true, completion: nil)
            messageInputBar.inputTextView.resignFirstResponder()
            tabBarController?.tabBar.isHidden = false
            let placeholderMessage = ConversationManager.shared.createMessageWithPlaceholder(sender: user, receiver: contact, caption: captionText ?? nil)
            if chatViewModel.conversation != nil {
                chatViewModel.uploadPlaceHolderMessage(message: placeholderMessage)
            } else {
                createNewConversation(with: placeholderMessage)
            }
            chatViewModel.uploadImage(pickedImage: pickedImage, message: placeholderMessage, captionText: captionText)
        }
    }
}


// MARK:- Message Display Delegate

extension ChatViewController: MessagesDataSource, MessagesDisplayDelegate, MessagesLayoutDelegate, MessageCellDelegate {
    
    func currentSender() -> SenderType {
        return user
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
    
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        guard let sender = [user, contact].filter({ $0.uid == message.sender.senderId }).first else { return }
        Service.shared.downloadUserImage(user: sender) { (image) in
            avatarView.image = image
        }
    }
    
    func messageStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageStyle {
        return .bubbleOutline(.clear)
    }
        
    func cellBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        let foundMessage = messages[indexPath.section]
        let bottomLabelText = NSMutableAttributedString(string: ConversationManager.shared.timeFormatter.string(from: message.sentDate), attributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.systemGray])
        var messageTag = NSAttributedString()
        if foundMessage.sender.senderId == user.uid {
            switch foundMessage.state {
            case .sent:
                messageTag = sentTag
            case .delivered:
                messageTag = deliveredTag
            case .read:
                messageTag = readTag
            default:
                messageTag = NSAttributedString()
            }
        } else {
            messageTag = NSAttributedString()
        }
        bottomLabelText.append(messageTag)
        return bottomLabelText
    }
    
    func cellBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 18
    }
    
    func didTapImage(in cell: MessageCollectionViewCell) {
        if let indexPath = messagesCollectionView.indexPath(for: cell) {
            switch messages[indexPath.section].kind {
            case .video(let item):
                if let videoURL = item.url {
                    let player = AVPlayer(url: videoURL)
                    let playerVC = AVPlayerViewController()
                    playerVC.player = player
                    present(playerVC, animated: true) {
                        playerVC.player?.play()
                    }
                }
            case .photo(let item):
                if let selectedImage = item.image {
                    messageInputBar.inputTextView.resignFirstResponder()
                    let cellFrameInView = messagesCollectionView.convert(cell.frame, to: view)
                    tabBarController?.tabBar.isHidden = true
                    
                    let selectedImageAspectRatio = selectedImage.size.width / selectedImage.size.height
                    
                    let calculatedHeight = view.frame.width / selectedImageAspectRatio
                    let calculatedFrame = CGRect(x: 0, y: (view.frame.height - calculatedHeight) / 2, width: view.frame.width, height: calculatedHeight)
                    let adjustImage: Bool = selectedImageAspectRatio > (view.frame.width / view.frame.height)
                    view.addSubview(selectedImageView)
                    selectedImageView.frame = view.bounds
                    selectedImageView.backgroundColor = UIColor.white.withAlphaComponent(0)
                    selectedImageView.addSubview(selectedImageView.scrollView)
                    selectedImageView.scrollView.fillSuperView()
                    selectedImageView.scrollView.delegate = self
                                        
                    selectedImageView.scrollView.addSubview(selectedImageView.imageView)
                    selectedImageView.imageView.image = selectedImage
                    let xPadding: CGFloat = messages[indexPath.section].sender.senderId == user.uid ? 64 : 34
                    selectedImageView.imageView.frame = CGRect(x: cellFrameInView.origin.x + xPadding, y: cellFrameInView.origin.y + 22, width: 300, height: 300)
                    selectedImageView.imageView.layer.cornerRadius = 15
                    selectedImageView.imageView.contentMode = .scaleAspectFill
                    selectedImageView.imageView.clipsToBounds = true
                    self.selectedCellFrame = CGRect(x: cellFrameInView.origin.x + xPadding, y: cellFrameInView.origin.y + 22, width: 300, height: 300)
                   
                    navigationItem.leftItemsSupplementBackButton = false
                    let backButton = UIButton(type: .system)
                    backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
                    backButton.setAttributedTitle(NSAttributedString(string: "Chats", attributes: [.font: UIFont.systemFont(ofSize: 18)]), for: .normal)
                    backButton.addTarget(self, action: #selector(hideImageViewer), for: .touchUpInside)
                    backButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: -15, bottom: 0, right: 0)
                    let backBarButton = UIBarButtonItem(customView: backButton)
                    navigationItem.setLeftBarButton(backBarButton, animated: true)
                                    
                    UIView.animate(withDuration: 0.3, animations: { [unowned self] in
                        self.selectedImageView.imageView.frame.origin.x = 0
                        self.selectedImageView.imageView.frame.origin.y = calculatedFrame.origin.y
                        self.selectedImageView.imageView.frame.size.width = self.view.frame.width
                        if adjustImage && selectedImageAspectRatio < 1 {
                            self.selectedImageView.imageView.center = .init(x: calculatedFrame.midX, y: calculatedFrame.midY)
                        } else if !adjustImage {
                            self.selectedImageView.imageView.frame.size.height = self.view.frame.height
                        }
                        self.title = self.contact.fullName
                        self.selectedImageView.backgroundColor = UIColor.white.withAlphaComponent(1)
                        self.messageInputBar.isHidden = true
                    }) { (_) in
                        self.selectedImageView.imageView.clipsToBounds = false
                        self.selectedImageView.imageView.addGestureRecognizer(self.profileImagePanGesture)
                        self.profileImagePanGesture.addTarget(self, action: #selector(self.imageViewerPan))
                        self.selectedImageView.addGestureRecognizer(self.imageViewerTapGesture)
                        
                    }
                }
            default:
                break
            }
        }

    }
    
    func didTapMessage(in cell: MessageCollectionViewCell) {
        if let indexPath = messagesCollectionView.indexPath(for: cell) {
            switch messages[indexPath.section].kind {
            case .location(let locationItem):
                tabBarController?.tabBar.isHidden = true
                let mapVC = MapViewController()
                mapVC.delegate = self
                mapVC.showCertainLocation = locationItem.location
                let navVC = UINavigationController(rootViewController: mapVC)
                navVC.modalPresentationStyle = .overCurrentContext
                present(navVC, animated: true, completion: nil)
            default:
                break
            }
        }
    }
    
    
    func startPlayingAudioMessage(audioURL: URL? = nil, item: AudioItem, cell: AudioMessageCell) {
        do {
            if audioPlayer == nil, audioURL != nil { audioPlayer = try AVAudioPlayer(contentsOf: audioURL!) }
            audioPlayer.prepareToPlay()
            audioPlayer.play()
            cell.playButton.isSelected = true
            cellAudioTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] (timer) in
                guard let self = self else { return }
                cell.progressView.progress += Float(1/self.audioPlayer.duration)
                self.audioCellDuration -= 1
                cell.durationLabel.text = ConversationManager.shared.minuteFormatter.string(from: self.audioCellDuration)
                if self.audioCellDuration < 0 {
                    timer.invalidate()
                    cell.playButton.isSelected = false
                    cell.progressView.progress = 0
                    cell.durationLabel.text = ConversationManager.shared.minuteFormatter.string(from: Double(item.duration))
                    self.audioPlayer = nil
                    self.cellAudioTimer = nil
                    self.audioCellDuration = 0
                }
            }
        } catch let err { print("WTF", err.localizedDescription) }
    }
    
    
    func didTapPlayButton(in cell: AudioMessageCell) {
        if let indexPath = messagesCollectionView.indexPath(for: cell) {
            switch messages[indexPath.section].kind {
            case .audio(let item):
                if cell.progressView.progress == 0, cell.playButton.isSelected == false {
                    audioCellDuration = Double(item.duration)
                    Service.shared.downloadMessageAudio(audioURL: item.url) { [weak self] (fileURLString) in
                        guard let filePath = fileURLString, let fileURL = URL(string: filePath) else { print("WTF NO AUDIO FILE"); return }
                        self?.startPlayingAudioMessage(audioURL: fileURL, item: item, cell: cell)
                    }
                } else if cell.progressView.progress > 0, cell.playButton.isSelected {
                    cellAudioTimer?.invalidate()
                    audioPlayer.stop()
                    cell.playButton.isSelected = false
                } else if cell.progressView.progress > 0, cell.playButton.isSelected == false {
                    startPlayingAudioMessage(item: item, cell: cell)
                }
            default:
                break
            }
        }
    }
    
    func messageBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        switch message.kind {
        case .photo(let item as MessageMedia), .video(let item as MessageMedia):
            if let caption = item.caption { return NSAttributedString(string: caption, attributes: [.font: UIFont.systemFont(ofSize: 16)])}
        default:
            break
        }
        return nil
    }
    
    func messageBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        switch message.kind {
        case .photo(let item as MessageMedia):
            if let caption = item.caption, !caption.isEmpty { return 18 }
        case .video(let item as MessageMedia):
            if let caption = item.caption, !caption.isEmpty { return 18 }
        default:
            break
        }
        return 0
    }
    
    func cellTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        let currentMessageTime = ConversationManager.shared.dayFormatter.string(from: message.sentDate)
        let title = currentMessageTime == ConversationManager.shared.dayFormatter.string(from: Date()) ? "Today" : currentMessageTime
        if messages[indexPath.section].messageId == messages.first?.messageId {
            messageTime = title
            return NSAttributedString(string: title, attributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.systemGray])
        }
        if title != messageTime {
            messageTime = title
            return NSAttributedString(string: title, attributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.systemGray])
        }
        return nil
    }
    
    func cellTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 22
    }
    
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        let activityIndicator = UIActivityIndicatorView()
        activityIndicator.hidesWhenStopped = true
        activityIndicator.startAnimating()
        activityIndicator.color = .black
        activityIndicator.style = .medium
        switch messages[indexPath.section].kind {
        case .photo(let item):
            if item.image == nil {
                imageView.backgroundColor = #colorLiteral(red: 0.9250760492, green: 0.9250760492, blue: 0.9250760492, alpha: 1)
                imageView.addSubview(activityIndicator)
                activityIndicator.anchor(centerX: imageView.centerXAnchor, centerY: imageView.centerYAnchor)
            } else {
                activityIndicator.stopAnimating()
                activityIndicator.removeFromSuperview()
            }
        case .video(let item):
            imageView.backgroundColor = #colorLiteral(red: 0.9250760492, green: 0.9250760492, blue: 0.9250760492, alpha: 1)
            imageView.addSubview(activityIndicator)
            activityIndicator.anchor(centerX: imageView.centerXAnchor, centerY: imageView.centerYAnchor)
            if let videoURL = item.url {
                Service.shared.generateVideoThumbnail(url: videoURL) { (image) in
                    if let thumbnailImage = image {
                        imageView.image = thumbnailImage
                        activityIndicator.stopAnimating()
                        activityIndicator.removeFromSuperview()
                    }
                }
            } else {
                imageView.image = UIImage(systemName: "video.fill")
                imageView.backgroundColor = #colorLiteral(red: 0.9250760492, green: 0.9250760492, blue: 0.9250760492, alpha: 1)
            }
        default:
            break
        }
    }
}

// MARK:- InputBarAccessoryViewDelegate

extension ChatViewController: InputBarAccessoryViewDelegate {
    
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        if let message = ConversationManager.shared.createTextMessage(sender: user, receiver: contact, text: text) {
            Service.shared.updateUserStatus(user: user, status: .online)
            if let conversation = self.chatViewModel.conversation {
                ConversationManager.shared.uploadMessageToConversation(conversation: conversation, message: message) { [weak self] (result) in
                    switch result {
                    case .failure(let error): print("WTF", error.localizedDescription)
                    case .success(_):
                        if self?.contact.status == .offline {
                            REF_CONVERSATIONS.child(conversation.uid).child("messages").child(message.messageId).child("state").setValue("sent")
                        }
                    }
                }
            } else {
                createNewConversation(with: message)
            }
        }
        messagesCollectionView.scrollToBottom(animated: true)
        inputBar.resignFirstResponder()
        inputBar.inputTextView.text = nil
    }
    
    func setupInputBar() {
        plusButton.setImage(UIImage(systemName: "plus.circle"), for: .normal)
        plusButton.setSize(.init(width: 35, height: 35), animated: false)
        plusButton.addTarget(self, action: #selector(self.barPlusButtonTapped), for: .touchUpInside)
        
        
        micButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        micButton.setSize(.init(width: 35, height: 35), animated: false)
        micButton.addGestureRecognizer(longPressGesture)
        micButton.addGestureRecognizer(recordButtonPan)
        
        messageInputBar.setStackViewItems([plusButton], forStack: .left, animated: false)
        messageInputBar.setStackViewItems([micButton], forStack: .right, animated: false)
        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false)
        messageInputBar.setRightStackViewWidthConstant(to: 40, animated: false)
    }
    
    func inputBar(_ inputBar: InputBarAccessoryView, textViewTextDidChangeTo text: String) {
        if !text.isEmpty {
            messageInputBar.setStackViewItems([messageInputBar.sendButton], forStack: .right, animated: false)
        } else {
            messageInputBar.setStackViewItems([micButton], forStack: .right, animated: false)
        }
    }
    
    
}


// MARK:- ImagePicker Delegate

extension ChatViewController: UIImagePickerControllerDelegate & UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        keyboardObserver = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: nil, using: { [weak self] (notification) in
            self?.handleKeyboard(notification: notification)
        })
        if let image = info[.originalImage] as? UIImage {
            pickedImageView = PickedImageView()
            picker.view.addSubview(pickedImageView)
            pickedImageView.captionTextField.delegate = self
            pickedImageView.scrollView.delegate = self
            pickedImageView.closeButton.addTarget(self, action: #selector(self.dismissPickedImageView), for: .touchUpInside)
            pickedImageView.sendButton.addTarget(self, action: #selector(self.sendPhotoMessage), for: .touchUpInside)
            pickedImageView.frame = CGRect(origin: self.imagePickerTapLocation ?? CGPoint(x: 0, y: 0), size: CGSize(width: 12, height: 12))
            pickedImageView.pickedImageView.image = image
            UIView.animate(withDuration: 0.3) {
                self.pickedImageView.frame.size.height = self.view.frame.size.height
                self.pickedImageView.frame.size.width = self.view.frame.size.width
                self.pickedImageView.pickedImageView.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height)
                self.pickedImageView.setupSubViews()
            }
        } else if let pickedVideoURL = info[.mediaURL] as? URL {
            pickedVideoView = PickedVideoView()
            self.pickedVideoURL = pickedVideoURL
            picker.view.addSubview(pickedVideoView)
            pickedVideoView.frame = view.bounds
            pickedVideoView.captionBar.delegate = self
            pickedVideoView.setupViews()
            pickedVideoView .closeButton.addTarget(self, action: #selector(self.dismissPickedVideoView), for: .touchUpInside)
            pickedVideoView.sendButton.addTarget(self, action: #selector(self.sendVideoMessage), for: .touchUpInside)
            UIView.animate(withDuration: 0.2) {
                self.pickedVideoView.lowerBarView.frame.origin.y = self.view.frame.height * 0.9
                self.pickedVideoView.closeButton.frame.origin.y = self.view.frame.height * 0.08
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.tabBarController?.tabBar.isHidden = false
        dismiss(animated: true, completion: nil)
    }
}

// MARK:- ScrollView Delegate

extension ChatViewController {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        if scrollView == pickedImageView.scrollView && pickedImageView.dimmingView.isHidden {
            return pickedImageView.pickedImageView
        } else if scrollView == profileView.scrollView {
            return profileView.imageView
        } else if scrollView == selectedImageView.scrollView {
            return selectedImageView.imageView
        }
        return nil
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if scale < 1 {
            scrollView.zoomScale = 1
            if scrollView == pickedImageView.scrollView {
                self.pickedImageView.pickedImageView.frame.origin = CGPoint(x: 0, y: self.view.frame.height * 0.12)
                UIView.animate(withDuration: 0.1) {
                    self.pickedImageView.pickedImageView.frame.size.width = self.view.frame.width
                    self.pickedImageView.pickedImageView.frame.size.height = self.view.frame.height * 0.7
                }
            } else if scrollView == profileView.scrollView {
                self.profileView.imageView.frame.origin = CGPoint(x: 0, y: self.profileView.frame.height * 0.2)
                UIView.animate(withDuration: 0.1) {
                    self.profileView.imageView.frame.size.width = self.profileView.frame.width
                    self.profileView.imageView.frame.size.height =  self.profileView.frame.height * 0.6
                }
            }
            
        }
    }
    
}

// MARK:- TextField/TextView Delegate

extension ChatViewController: UITextFieldDelegate, UITextViewDelegate {
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if textView == messageInputBar.inputTextView, !text.isEmpty {
            Service.shared.updateUserStatus(user: user, status: .typing)
        } else if textView.text.isEmpty, text.isEmpty {
            Service.shared.updateUserStatus(user: user, status: .online)
        }
        return true
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView == messageInputBar.inputTextView, isViewLoaded {
            Service.shared.updateUserStatus(user: user, status: .online)
        }
    }
}


// MARK:- GestureRecognizer Delegate

extension ChatViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer.view == micButton, otherGestureRecognizer.view == micButton {
            return true
        } else {
            return false
        }
    }
}

extension ChatViewController: MapViewControllerDelegate {
    
    func didSelectLocation(_ location: CLLocationCoordinate2D?) {
        guard let selectedLocationCoordinate = location else { return }
        
        let locationMessage = ConversationManager.shared.createLocationMessage(sender: user, receiver: contact, coordinate: selectedLocationCoordinate)
        
        if let conversation = chatViewModel.conversation {
            ConversationManager.shared.uploadMessageToConversation(conversation: conversation, message: locationMessage) { (result) in
                switch result {
                case .failure(let error): print("WTF", error.localizedDescription)
                case .success(_): break
                }
            }
        } else {
            createNewConversation(with: locationMessage)
        }
        
        messagesCollectionView.scrollToLastItem()
        messageInputBar.inputTextView.resignFirstResponder()
        messageInputBar.inputTextView.text = nil
        
    }
    
    func didDismiss() {
        tabBarController?.tabBar.isHidden = false
    }
    
    
}
