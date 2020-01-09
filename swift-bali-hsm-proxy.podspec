Pod::Spec.new do |s|
  s.name             = "bali-hsm-proxy"
  s.version          = "2.0.0"
  s.summary          = "A proxy to the ArmorD™ hardware security device."

  s.description      = <<-DESC
  This proxy allows swift based applications to interact with an ArmorD™ prototype device
  over low energy bluetooth (BLE) using the CoreBluetooth libraries.
                       DESC

  s.homepage         = "https://github.com/craterdog-bali/swift-bali-hsm-proxy"
  s.license          = 'MIT License'
  s.author           = { "Derk Norton" => "derk.norton@gmail.com", "Aren Dalloul" => "adalloul3108@gmail.com" }
  s.source           = { :git => "https://github.com/craterdog-bali/swift-bali-hsm-proxy.git", :tag => s.version.to_s }

  s.ios.deployment_target = '12.4'
  s.osx.deployment_target = '10.14'
  s.swift_version = '5.1'

  s.requires_arc = true

  s.source_files = 'Source/*.swift'
  s.frameworks   = 'CoreBluetooth'
end
