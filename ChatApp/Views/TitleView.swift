//
//  TitleView.swift
//  ChatApp
//
//  Created by Mohamed Hashem on 8/1/20.
//  Copyright © 2020 Mohamed Hashem. All rights reserved.
//

import UIKit


class TitleView: UIView {
    
    var nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 18)
        return label
    }()
    
    var statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .darkGray
        label.textAlignment = .center
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubviews([nameLabel, statusLabel])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func setupSubViews(status: String? = nil) {
        nameLabel.frame = CGRect(origin: .zero, size: nameLabel.intrinsicContentSize)
        nameLabel.center = .init(x: frame.size.width / 2, y: 0)
        
        statusLabel.anchor(top: nameLabel.bottomAnchor, topConstant: 2, centerX: centerXAnchor, centerXConstant: 1)
        statusLabel.alpha = 0
    }
    
    func showStatus(status: String) {
        statusLabel.text = status
        if statusLabel.alpha == 0 {
            UIView.animate(withDuration: 0.2) {
                self.nameLabel.center.y -= 5
                self.statusLabel.alpha = 1
            }
        }
    }
    
    func hideStatus() {
        if statusLabel.alpha == 1 {
            statusLabel.text = nil
            UIView.animate(withDuration: 0.2) {
                self.nameLabel.center.y = 0
                self.statusLabel.alpha = 0
            }
        }
    }
    
    
    
}


