//
//  ConversationsTable.swift
//  ChatApp
//
//  Created by Mohamed Hashem on 7/17/20.
//  Copyright © 2020 Mohamed Hashem. All rights reserved.
//

import UIKit


class ConversationsTable: UITableView {
    
    override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        register(ConversationsTableCell.self, forCellReuseIdentifier: cellId)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}





class ConversationsTableCell: UITableViewCell {
    
    let userImage: UIImageView = {
        let imageView = UIImageView()
        imageView.layer.cornerRadius = 20
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.image = UIImage(systemName: "person.fill")
        imageView.backgroundColor = #colorLiteral(red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 1)
        imageView.tintColor = .white
        return imageView
    }()
    
    let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 16)
        return label
    }()
    
    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .systemGray
        return label
    }()
    
    var imageSize: CGSize? {
        didSet {
            userImage.frame.size = imageSize!
            layoutIfNeeded()
        }
    }
    
    var dateLabel: UILabel = {
        let label = UILabel()
        label.textColor = .systemBlue
        label.font = UIFont.systemFont(ofSize: 14)
        return label
    }()
    
    var unreadMessagesCountLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.backgroundColor = .systemBlue
        label.layer.cornerRadius = 9
        label.clipsToBounds = true
        label.textAlignment = .center
        label.font = UIFont.boldSystemFont(ofSize: 14)
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
        addSubviews([userImage, nameLabel, subtitleLabel, dateLabel, unreadMessagesCountLabel])
        
        userImage.frame = CGRect(x: 5, y: (frame.height / 2) - 10, width: 40, height: 40)
        nameLabel.anchor(top: userImage.topAnchor, topConstant: 0, leading: userImage.trailingAnchor, leadingConstant: 10)
        subtitleLabel.anchor(top: nameLabel.bottomAnchor, topConstant: 5, leading: nameLabel.leadingAnchor)
        dateLabel.anchor(top: nameLabel.topAnchor, trailing: trailingAnchor, trailingConstant: 10)
        
        unreadMessagesCountLabel.anchor(top: dateLabel.bottomAnchor, topConstant: 4, trailing: dateLabel.trailingAnchor, widthConstant: 25, heightConstant: 20)
        unreadMessagesCountLabel.isHidden = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}
