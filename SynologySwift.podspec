Pod::Spec.new do |s|
    s.name               = "SynologySwift"
    s.version            = "0.2.1"
    s.summary            = "Swift library for Synology DiskStation and use DSM APIs (login with encryption)"
    s.description        = "Swift library for accessing Synology NAS. Resolve host/iP of your NAS with a QuickConnectId and connect by APIs throught encryption service."
    s.homepage           = "https://github.com/Thomaslegravier/SynologySwift"
    s.license            = "MIT"
    s.author             = { "Thomas Le Gravier" => "legravier.thomas@gmail.com" }
    s.social_media_url   = "https://twitter.com/lebasalte"

    s.requires_arc = true
    s.swift_version = '5.0'
    s.source       = { :git => "https://github.com/Thomaslegravier/SynologySwift.git", :tag => "#{s.version}" }
    s.source_files  = "Sources/SynologySwift/**/*.swift"

    s.ios.deployment_target     = "12.0"
    s.osx.deployment_target     = "10.10"
    s.watchos.deployment_target = "2.0"
    s.tvos.deployment_target    = "9.0"
end
