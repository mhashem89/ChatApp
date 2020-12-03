//
//  PickedVideoView.swift
//  ChatApp
//
//  Created by Mohamed Hashem on 7/28/20.
//  Copyright © 2020 Mohamed Hashem. All rights reserved.
//

import UIKit
import AVFoundation


class PickedVideoView: UIView {

    let lowerBarView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        return view
    }()
    
    let captionBar: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Add caption..."
        tf.backgroundColor = .white
        tf.addLeftPadding(10)
        return tf
    }()
    
    let sendButton: UIButton = {
           let button = UIButton(type: .system)
           button.tintColor = .systemBlue
           button.setImage(#imageLiteral(resourceName: "send"), for: .normal)
           button.contentMode = .scaleAspectFill
           return button
       }()
    
    let closeButton: UIButton = {
           let button = UIButton()
           button.setImage(UIImage(systemName: "xmark"), for: .normal)
           button.tintColor = .white
           return button
       }()
    
    func setupViews() {
        backgroundColor = UIColor.black.withAlphaComponent(0.5)
        addSubviews([lowerBarView, closeButton])
        lowerBarView.addSubviews([captionBar, sendButton])
        lowerBarView.frame = CGRect(x: 0, y: frame.height, width: frame.width, height: frame.height * 0.1)
        captionBar.anchor(top: lowerBarView.topAnchor, leading: lowerBarView.leadingAnchor, bottom: lowerBarView.bottomAnchor, widthConstant: lowerBarView.frame.width * 0.8)
        sendButton.anchor(trailing: lowerBarView.trailingAnchor, trailingConstant: 15, centerY: lowerBarView.centerYAnchor, centerYConstant: -5, widthConstant: 60, heightConstant: 60)
        closeButton.frame = CGRect(x: frame.width * 0.08, y: 0, width: 50, height: 50)
    }
    
    
    
}

