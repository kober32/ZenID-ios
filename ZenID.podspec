Pod::Spec.new do |s|
  s.cocoapods_version   = '>= 1.10'
  s.name                = "ZenID"
  s.version             = "0.0.1"
  s.summary             = "ZenID fork"
  s.homepage            = "https://github.com/kober32/ZenID-ios"
  s.social_media_url    = 'https://github.com/kober32/ZenID-ios'
  s.author              = { 'JK' => 'jan@kobersky.eu' }
  s.source              = { :git => 'https://github.com/kober32/ZenID-ios.git' }

  s.vendored_frameworks = ["Sources/LibZenid_iOS.xcframework", "Sources/RecogLib_iOS.xcframework"]
  s.platform            = :ios
  s.swift_version       = "5.0"
  s.ios.deployment_target  = '10.0'

  s.subspec 'documents_rb' do |sub|
    sub.resource_bundle = { 
      "ZenIDModels" => [
        # ID card
        "Models/documents/CZ/usurf_idc1_b.bin", 
        "Models/documents/CZ/usurf_idc1_f.bin", 
        "Models/documents/CZ/usurf_idc2_b.bin", 
        "Models/documents/CZ/usurf_idc2_f.bin",

        # Passport
        "Models/documents/CZ/usurf_pas_f.bin",

        # Driving
        "Models/documents/CZ/usurf_drv_f.bin",

        # Required
        "Models/documents/DOCUMENT/modelhashes.bin",
      ] 
    }
  end

end