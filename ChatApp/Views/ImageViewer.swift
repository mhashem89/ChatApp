//
//  ImageView.swift
//  ChatApp
//
//  Created by Mohamed Hashem on 7/22/20.
//  Copyright © 2020 Mohamed Hashem. All rights reserved.
//

import UIKit


class ImageViewer: UIView {

    var scrollView: UIScrollView = {
        let view = UIScrollView()
        view.minimumZoomScale = 0.5
        view.maximumZoomScale = 2
        view.showsVerticalScrollIndicator = false
        return view
    }()
    
    var imageView: UIImageView = {
        let imView = UIImageView()
        imView.contentMode = .scaleAspectFit
        imView.clipsToBounds = true
        imView.isUserInteractionEnabled = true
        return imView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        backgroundColor = .systemBackground
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupViews() {
        if subviews.contains(imageView) { imageView.removeFromSuperview() }
        addSubview(scrollView)
        scrollView.frame = bounds
        scrollView.contentSize = frame.size
        scrollView.addSubview(imageView)
        imageView.frame = scrollView.frame
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 0
    }
    
}
