Pod::Spec.new do |s|
  s.name             = "dreiAttest"
  s.version          = "0.0.1"
  s.summary          = ""
  s.homepage         = "https://github.com/dreipol/dreiAttest-ios"
  s.license          = { type: 'MIT', file: 'LICENSE' }
  s.author           = { "dreipol GmbH" => "dev@dreipol.ch" }
  s.source           = { git: "https://github.com/dreipol/dreiAttest-ios.git", tag: s.version.to_s }
  s.social_media_url = 'https://twitter.com/dreipol'
  s.ios.deployment_target = '11.0'
  s.requires_arc = true
  s.ios.source_files = 'Sources/dreiAttest/**/*.{swift}'
  s.swift_version = '5.0'
  s.ios.frameworks = 'Foundation'
  # s.dependency 'Eureka', '~> 4.0'
  s.info_plist = {
    'CFBundleIdentifier' => 'ch.dreipol.dreiattest'
  }
  s.pod_target_xcconfig = {
    'PRODUCT_BUNDLE_IDENTIFIER': 'ch.dreipol.dreiattest'
  }
  s.script_phases = [
    {
        :name => 'Swiftlint',
        :execution_position => :before_compile,
        :shell_path => '/bin/sh',
        :script => <<-SCRIPT
        cd "$PODS_TARGET_SRCROOT/"
        
        if which swiftlint >/dev/null; then
          swiftlint
        else
          echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
        fi
        SCRIPT
    }
]
end
