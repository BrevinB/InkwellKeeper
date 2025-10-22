//
//  CameraPreview.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI
import UIKit
internal import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let cameraManager: CameraManager

    func makeUIView(context: Context) -> PreviewView {
        let previewView = PreviewView()
        previewView.previewLayer = cameraManager.previewLayer
        previewView.cameraManager = cameraManager
        return previewView
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        // Update the preview layer if needed
        if uiView.previewLayer != cameraManager.previewLayer {
            uiView.previewLayer = cameraManager.previewLayer
        }
        uiView.cameraManager = cameraManager
    }
}

class PreviewView: UIView {
    weak var cameraManager: CameraManager?

    var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            oldValue?.removeFromSuperlayer()
            if let previewLayer = previewLayer {
                layer.addSublayer(previewLayer)
                updateLayerFrame()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGestureRecognizers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGestureRecognizers()
    }

    private func setupGestureRecognizers() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        let devicePoint = previewLayer?.captureDevicePointConverted(fromLayerPoint: location) ?? location

        // Show focus indicator animation
        showFocusIndicator(at: location)

        // Tell camera manager to focus on this point
        cameraManager?.focusOnPoint(devicePoint)
    }

    private func showFocusIndicator(at point: CGPoint) {
        // Create a simple focus indicator
        let focusView = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        focusView.center = point
        focusView.layer.borderColor = UIColor.systemYellow.cgColor
        focusView.layer.borderWidth = 2
        focusView.layer.cornerRadius = 40
        focusView.alpha = 0

        addSubview(focusView)

        UIView.animate(withDuration: 0.2, animations: {
            focusView.alpha = 1
            focusView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            UIView.animate(withDuration: 0.2, delay: 0.5, animations: {
                focusView.alpha = 0
            }) { _ in
                focusView.removeFromSuperview()
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayerFrame()
    }

    private func updateLayerFrame() {
        previewLayer?.frame = bounds
    }
}
