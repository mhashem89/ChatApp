//
//  PickedImageView.swift
//  ChatApp
//
//  Created by Mohamed Hashem on 7/23/20.
//  Copyright © 2020 Mohamed Hashem. All rights reserved.
//

import UIKit

class PickedImageView: UIView {
    
    let pickedImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        return imageView
    }()
    
    let closeButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .white
        return button
    }()
    
    let captionTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Add caption..."
        tf.borderStyle = .roundedRect
        tf.backgroundColor = .white
        tf.layer.cornerRadius = 18
        tf.clipsToBounds = true
        return tf
    }()
    
    let sendButton: UIButton = {
        let button = UIButton(type: .system)
        button.tintColor = .systemBlue
        button.setImage(#imageLiteral(resourceName: "send"), for: .normal)
        button.contentMode = .scaleAspectFill
        return button
    }()
    
    let dimmingView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        return view
    }()
    
    let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.minimumZoomScale = 0.5
        view.maximumZoomScale = 2
        return view
    }()
    
    var activeField: UITextField?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        scrollView.addSubviews([pickedImageView, dimmingView])
        addSubviews([scrollView, closeButton, captionTextField, sendButton])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func setupSubViews() {
        scrollView.frame = bounds
        scrollView.contentSize = frame.size
        scrollView.showsVerticalScrollIndicator = false
        dimmingView.frame = scrollView.frame
        dimmingView.isHidden = true
        closeButton.frame = CGRect(x: frame.width * 0.05, y: frame.width * 0.05, width: 50, height: 50)
        
        captionTextField.frame = CGRect(x: frame.width * 0.05, y: frame.height * 0.9, width: frame.width * 0.8, height: captionTextField.intrinsicContentSize.height)
        
        sendButton.frame = CGRect(x: frame.width * 0.86, y: frame.height * 0.885, width: 60, height: 60)
    }
    
    
    
}


