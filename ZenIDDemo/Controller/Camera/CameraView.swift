
import UIKit
import AVFoundation


final class CameraView: UIView {
    
    let saveTrigger = Buttons.Camera.saveStack
    let cameraTrigger = Buttons.Camera.trigger
    let statusButton = Buttons.Camera.status
    let instructionView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        let subView = UIView(frame: stack.bounds)
        subView.backgroundColor = UIColor.white.withAlphaComponent(0.7)
        subView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        subView.layer.cornerRadius = 8
        stack.insertSubview(subView, at: 0)
        return stack
    }()

    let topLabel: UILabel = {
        let label = UILabel()
        label.textColor = .black
        label.font = .messageLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private var controlView = UIView()
    let cameraView = UIView()
    private(set) var overlay: CameraOverlayView?
    var previewLayer: AVCaptureVideoPreviewLayer?
    private(set) var drawLayer: DrawingLayer?
    
    var showInstructionView: Bool = false {
        didSet {
            instructionView.isHidden = !showInstructionView
        }
    }
    
    var supportChangedOrientation: (() -> Bool)!
    
    private(set) var webViewOverlay: WebViewOverlay?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if let previewLayer = previewLayer {
            previewLayer.frame = cameraView.bounds
        }
    }
    
    func setup(isOtherDocument: Bool) {
        // Camera view
        addSubview(cameraView)
        cameraView.anchor(top: safeAreaLayoutGuide.topAnchor, left: leftAnchor, bottom: nil, right: rightAnchor)
        
        // Control view
        setupControlView(isOtherDocument: isOtherDocument)

        // Top label wrapper
        let topLabelWrapper = UIView()
        topLabelWrapper.backgroundColor = .clear
        topLabelWrapper.addSubview(topLabel)
        topLabel.anchor(top: topLabelWrapper.topAnchor, left: topLabelWrapper.leftAnchor, bottom: topLabelWrapper.bottomAnchor, right: topLabelWrapper.rightAnchor, paddingTop: 10, paddingLeft: 10, paddingBottom: 10, paddingRight: 10)

        // Instructions view
        instructionView.addArrangedSubview(statusButton)
        instructionView.addArrangedSubview(topLabelWrapper)
        addSubview(instructionView)
        instructionView.centerX(to: cameraView)
        instructionView.centerY(to: cameraView)
    }
    
    func setupControlView(isOtherDocument: Bool) {
        controlView.removeFromSuperview()
        controlView = UIView()
        if isOtherDocument {
            addSubview(controlView)
            controlView.anchor(top: cameraView.bottomAnchor, left: leftAnchor, bottom: layoutMarginsGuide.bottomAnchor, right: rightAnchor)
            
            // Trigger button
            controlView.addSubview(cameraTrigger)
            cameraTrigger.isHidden = false
            cameraTrigger.anchor(top: controlView.topAnchor, left: nil, bottom: controlView.bottomAnchor, right: nil, paddingTop: 10, paddingBottom: 10)
            cameraTrigger.centerX(to: controlView)
            cameraTrigger.centerY(to: controlView)

            // Save button
            controlView.addSubview(saveTrigger)
            saveTrigger.anchor(top: controlView.topAnchor, left: cameraTrigger.rightAnchor, bottom: controlView.bottomAnchor, right: controlView.rightAnchor)
        } else {
            addSubview(controlView)
            controlView.anchor(top: cameraView.bottomAnchor, left: leftAnchor, bottom: layoutMarginsGuide.bottomAnchor, right: rightAnchor)
            controlView.heightAnchor.constraint(equalToConstant: 0).isActive = true
            controlView.addSubview(cameraTrigger)
            cameraTrigger.translatesAutoresizingMaskIntoConstraints = false
            cameraTrigger.isHidden = true
        }
    }
    
    func rotateOverlay(targetFrame: CGRect) {
        guard let overlay = self.overlay else { return }
        
        if !supportChangedOrientation() {
            return
        }
        
        let gravity = Defaults.videoGravity
        switch gravity {
        case .resizeAspect:
            overlay.setupImage(rect: targetFrame)
            
        case .resizeAspectFill:
            overlay.setupImage()
            
        default:
            overlay.setupImage()
        }
    }
    
    func addWebViewOverlay() {
        webViewOverlay?.removeFromSuperview()
        let webView = WebViewOverlay()
        webView.loadOnline()
        addSubview(webView)
        leftAnchor.constraint(equalTo: webView.leftAnchor).isActive = true
        bottomAnchor.constraint(equalTo: webView.bottomAnchor).isActive = true
        rightAnchor.constraint(equalTo: webView.rightAnchor).isActive = true
        topAnchor.constraint(equalTo: webView.topAnchor).isActive = true
        webViewOverlay = webView
    }
    
    func removeWebViewOverlay() {
        webViewOverlay?.removeFromSuperview()
        webViewOverlay = nil
    }
    
    private func configurePreviewLayer() {
        previewLayer!.videoGravity = Defaults.videoGravity
        previewLayer!.frame = cameraView.layer.bounds
        cameraView.layer.addSublayer(previewLayer!)
    }

    private func configureDrawingLayer() {
        guard let previewLayer = previewLayer else { return }
        drawLayer?.removeFromSuperlayer()
        drawLayer = DrawingLayer()
        drawLayer?.backgroundColor = UIColor.red.withAlphaComponent(0.4).cgColor
        previewLayer.addSublayer(drawLayer!)
    }
    
    func configureOverlay(overlay: CameraOverlayView, showStaticOverlay: Bool, targetFrame: CGRect) {
        self.overlay?.removeFromSuperview()
        self.overlay = overlay
        if let overlay = self.overlay {
            cameraView.addSubview(overlay)
            overlay.anchor(top: cameraView.topAnchor, left: cameraView.leftAnchor, bottom: cameraView.bottomAnchor, right: cameraView.rightAnchor)
            overlay.isHidden = !showStaticOverlay
            overlay.setupSafeArea(layoutGuide: safeAreaLayoutGuide)
            rotateOverlay(targetFrame: targetFrame)
        }
    }
    
    func configureVideoLayers(overlay: CameraOverlayView, showStaticOverlay: Bool, targetFrame: CGRect) {
        configurePreviewLayer()
        configureDrawingLayer()
        configureOverlay(overlay: overlay, showStaticOverlay: showStaticOverlay, targetFrame: targetFrame)
    }
    
}
