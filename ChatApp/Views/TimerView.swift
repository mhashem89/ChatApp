//
//  TimerView.swift
//  ChatApp
//
//  Created by Mohamed Hashem on 7/30/20.
//  Copyright © 2020 Mohamed Hashem. All rights reserved.
//

import UIKit

class TimerView: UIView {
    
    var timerLabel: UILabel = {
        let label = UILabel()
        label.textColor = .black
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.text = "00:00"
        return label
    }()
    
    var swipeLabel: UILabel = {
        let label = UILabel()
        label.textColor = .black
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.text = "Swipe to cancel〈"
        return label
    }()
    
    var timer: Timer?
    
    var timeInterval: TimeInterval = 0
    
    var invalidateTimer: Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func setupViews() {
        addSubviews([swipeLabel, timerLabel])
        swipeLabel.anchor(trailing: trailingAnchor, trailingConstant: 10, centerY: centerYAnchor, centerYConstant: 5)
        timerLabel.anchor(trailing: swipeLabel.leadingAnchor, trailingConstant: 10, centerY: centerYAnchor, centerYConstant: 5)
        self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { (timer) in
            if self.invalidateTimer == false {
                self.timeInterval += 1
                self.timerLabel.text = ConversationManager.shared.minuteFormatter.string(from: self.timeInterval)
            } else {
                timer.invalidate()
            }
        })
        
    }
    
    
}

