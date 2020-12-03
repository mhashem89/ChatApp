//
//  ContactBarView.swift
//  ChatApp
//
//  Created by Mohamed Hashem on 7/23/20.
//  Copyright © 2020 Mohamed Hashem. All rights reserved.
//

import UIKit

class ContactBarView: UIView {
    
    let nameLabel = UILabel()
    
    let backImageView = UIImageView(image: UIImage(systemName: "chevron.left"))
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubviews([backImageView, nameLabel])
        nameLabel.textColor = .systemBlue
        nameLabel.anchor(leading: leadingAnchor, leadingConstant: 5, centerY: centerYAnchor)
        backImageView.anchor(trailing: trailingAnchor, trailingConstant: 5, centerY: centerYAnchor)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
