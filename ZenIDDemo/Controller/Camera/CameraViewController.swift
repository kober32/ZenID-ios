import AVFoundation
import CoreGraphics
import RecogLib_iOS
import UIKit
import WebKit

class CameraViewController: UIViewController {
    weak var delegate: CameraViewControllerDelegate?
    
    private let messageView = MessagesView()
    private var contentView: CameraView {
        view as! CameraView
    }
    
    private var targetFrame: CGRect = .zero
    
    private var photoType: PhotoType
    private var documentType: DocumentType
    private var faceMode: FaceMode?
    private var dataType: DataType
    
    private let camera = Camera()

    private var documentController: DocumentController?
    private var documentControllerConfig: DocumentControllerConfiguration?
    private var selfieController: SelfieController?
    private var selfieControllerConfig: SelfieControllerConfiguration?
    private var facelivenessController: FacelivenessController?
    private var facelivenessControllerConfig: FacelivenessControllerConfiguration?
    
    init(photoType: PhotoType, documentType: DocumentType, faceMode: FaceMode, dataType: DataType) {
        self.photoType = photoType
        self.documentType = documentType
        self.faceMode = faceMode
        self.dataType = dataType
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        ApplicationLogger.shared.Error("init(coder:) has not been implemented")
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = CameraView()
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupDocumentController()
        setupFacelivenessController()
        setupSelfieController()
        
        // Message view
        contentView.addSubview(messageView)
        messageView.anchor(top: contentView.safeAreaLayoutGuide.topAnchor, left: contentView.leftAnchor, bottom: nil, right: contentView.rightAnchor)
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        documentController?.start()
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        documentController?.stop()
    }
    
    deinit {
        documentController?.stop()
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }

    public func configureController(type: DocumentType, photoType: PhotoType, country: Country, faceMode: FaceMode?, documents: [Document], documentSettings: DocumentVerifierSettings, config: Config) {
        self.photoType = photoType
        self.documentType = type
        self.faceMode = faceMode
        self.dataType = dataType(of: documentType, photoType: photoType, isLivenessVideo: config.isLivenessVideo)
        
        self.title = type.title
        contentView.topLabel.text = photoType.message

        startSession()
        
        documentControllerConfig = nil
        
        if photoType.isDocument {
            documentControllerConfig = .init(
                showVisualisation: true,
                showDebugVisualisation: config.isDebugEnabled,
                dataType: dataType,
                role: RecoglibMapper.documentRole(from: type),
                country: country.recoglibCountry,
                page: photoType == .front ? .Front : .Back,
                code: nil,
                documents: type == .filter ? documents : nil,
                settings: documentSettings
            )
            updateDocumentController()
        } else {
            if faceMode?.isFaceliveness ?? false {
                facelivenessControllerConfig = .init(
                    showVisualisation: true,
                    showDebugVisualisation: config.isDebugEnabled,
                    dataType: dataType,
                    isLegacy: faceMode == .faceLivenessLegacy
                )
                updateFacelivenessController()
            } else if faceMode == .selfie {
                selfieControllerConfig = .init(
                    showVisualisation: true,
                    showDebugVisualisation: config.isDebugEnabled,
                    dataType: dataType
                )
                updateSelfieController()
            }
        }
        
        contentView.layer.addSublayer(messageView.layer)
    }
    
    private func dataType(of documentType: DocumentType, photoType: PhotoType, isLivenessVideo: Bool) -> DataType {
        if documentType == .documentVideo || photoType == .face && isLivenessVideo {
            return .video
        }
        return .picture
    }
    
    public func showErrorMessage(_ message: String) {
        messageView.showMessage(type: .error(message: message))
    }

    public func showSuccess() {
        messageView.showMessage(type: .success)
    }
    
    private func setupView() {
        view.backgroundColor = UIColor.black
    }
    
    private func saveAuxiliaryImagesToLibrary(info: FaceLivenessAuxiliaryInfo?) {
        for image in info?.images ?? [] {
            guard let image = UIImage(data: image) else {
                continue
            }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
    }
    
    private func returnImage(_ buffer: CVPixelBuffer, result: UnifiedResult? = nil) {
        let image = UIImage(pixelBuffer: buffer)
        let data = image?.jpegData(compressionQuality: 0.5)
        returnImage(data, result)
    }
    
    private func returnImage(_ data: Data?, _ result: UnifiedResult? = nil) {
        if let signatureImageData = result?.signature?.image, let signatureImage = UIImage(data: signatureImageData) {
            let preview = PreviewViewController(title:title ?? "", image: signatureImage)
            preview.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
            preview.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
            
            preview.saveAction = { [unowned self] in
                self.delegate?.didTakePhoto(signatureImageData, type: self.photoType, result: result)
            }
            preview.dismissAction = { [unowned self] in
                self.updateDocumentController()
            }

            present(preview, animated: true, completion: nil)
        }
        else {
            delegate?.didTakePhoto(nil, type: photoType, result: nil)
            navigationController?.popViewController(animated: true)
        }
    }
    
    func setupDocumentController() {
        documentController = DocumentController(camera: camera, view: contentView, modelsUrl: URL.modelsDocuments)
        documentController?.delegate = self
    }
    
    func setupFacelivenessController() {
        facelivenessController = FacelivenessController(camera: camera, view: contentView, modelsUrl: URL.modelsFolder.appendingPathComponent("face"))
        facelivenessController?.delegate = self
    }
    
    func setupSelfieController() {
        selfieController = SelfieController(camera: camera, view: contentView, modelsUrl: URL.modelsFolder.appendingPathComponent("face"))
        selfieController?.delegate = self
    }
    
    func updateDocumentController() {
        guard let configuration = documentControllerConfig else {
            return
        }
        do {
            try documentController?.configure(configuration: configuration)
        } catch {
            debugPrint(error)
        }
    }
    
    func updateFacelivenessController() {
        guard let configuration = facelivenessControllerConfig else {
            return
        }
        do {
            try facelivenessController?.configure(configuration: configuration)
        } catch {
            debugPrint(error)
        }
    }
    
    func updateSelfieController() {
        guard let configuration = selfieControllerConfig else {
            return
        }
        do {
            try selfieController?.configure(configuration: configuration)
        } catch {
            debugPrint(error)
        }
    }
}

extension CameraViewController: DocumentControllerDelegate {
    func controller(_ controller: DocumentController, didScan result: DocumentResult) {
        returnImage(nil, UnifiedDocumentResultAdapter(result: result))
    }
    
    func controller(_ controller: DocumentController, didRecord videoURL: URL) {
        delegate?.didTakeVideo(videoURL, type: photoType)
    }
}

extension CameraViewController: FacelivenessControllerDelegate {
    func controller(_ controller: FacelivenessController, didScan result: FaceLivenessResult) {
        returnImage(nil, UnifiedFacelivenessResultAdapter(result: result))
    }
    
    func controller(_ controller: FacelivenessController, didRecord videoURL: URL) {
        delegate?.didTakeVideo(videoURL, type: photoType)
    }
}

extension CameraViewController: SelfieControllerDelegate {
    func controller(_ controller: SelfieController, didScan result: SelfieResult) {
        returnImage(nil, UnifiedSelfieResultAdapter(result: result))
    }
    
    func controller(_ controller: SelfieController, didRecord videoURL: URL) {
        delegate?.didTakeVideo(videoURL, type: photoType)
    }
}

// MARK: - Methods for AV session
private extension CameraViewController {
    
    func startSession() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            beginSession()
        case .notDetermined:
            getAccessToCamera()
        case .denied, .restricted:
            returnImage(nil)
        @unknown default:
            returnImage(nil)
        }
    }
    
    func getAccessToCamera() {
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
            return
        }

        AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
            DispatchQueue.main.async { [unowned self] in
                if granted {
                    self.beginSession()
                } else {
                    self.returnImage(nil)
                }
            }
        })
    }
    
    func beginSession() {
        do {
            
        } catch {
            returnImage(nil)
            return
        }
    }
    
    
    private func overlayImageName() -> String {
        if documentType == .passport {
            return "targettingRectPas"
        } else if documentType == .idCard {
            return "targettingRect"
        }
        return ""
    }
}

extension CameraViewController {
    /*private func getVerifier(photoType: PhotoType, faceMode: FaceMode) -> UnifiedVerifier {
        switch photoType {
        case .face:
            switch faceMode {
            case .faceLiveness, .faceLivenessLegacy:
                return UnifiedFacelivenessVerifierAdapter(verifier: faceLivenessVerifier)
            case .selfie:
                return UnifiedSelfieVerifierAdapter(verifier: selfieVerifier)
            }
        default:
            return UnifiedDocumentVerifierAdapter(verifier: documentVerifier, orientation: .portrait)
        }
    }
    
    private func getVerifierRenderable(photoType: PhotoType, faceMode: FaceMode) -> VerifierRenderable? {
        switch photoType {
        case .face:
            switch faceMode {
            case .faceLiveness, .faceLivenessLegacy:
                return UnifiedFacelivenessVerifierAdapter(verifier: faceLivenessVerifier)
            case .selfie:
                return UnifiedSelfieVerifierAdapter(verifier: selfieVerifier)
            }
        default:
            return UnifiedDocumentVerifierAdapter(verifier: documentVerifier, orientation: .portrait)
        }
    }
    
    private func getWebViewOverlayState(result: UnifiedResult) -> WebViewOverlayState {
        .init(
            page: photoType.pageCode,
            state: String(describing: result.state),
            frame: getCroppedTargetFrame(width: Int(contentView.previewLayer!.frame.width), height: Int(contentView.previewLayer!.frame.height))
        )
    }*/
}
