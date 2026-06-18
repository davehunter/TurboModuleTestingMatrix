require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

# Detect the consuming app's React Native version so we can emit the right
# pod dependency names. Pod naming changed in RN 0.85: third-party libs
# (Folly etc.) moved into the `ReactNativeDependencies` umbrella, and
# `React-Codegen` was removed.
install_root = Pod::Config.instance.installation_root.to_s rescue nil
rn_version = "0.0.0"
if install_root
  rn_pkg = File.expand_path("../node_modules/react-native/package.json", install_root)
  rn_version = JSON.parse(File.read(rn_pkg))["version"] if File.exist?(rn_pkg)
end
rn_minor = rn_version.split(".")[1].to_i

Pod::Spec.new do |s|
  s.name         = "RTNTestableModule"
  s.version      = package["version"]
  s.summary      = "RTNTestableModule"
  s.homepage     = "https://example.com"
  s.license      = { :type => "MIT", :text => "MIT" }
  s.author       = { "RTNTestableModule" => "dev@example.com" }
  s.platforms    = { :ios => "13.0" }
  s.source       = { :path => "." }

  s.source_files = "cpp/**/*.{h,cpp}", "ios/**/*.{h,m,mm}"
  s.requires_arc = true

  s.pod_target_xcconfig = {
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++17",
    "DEFINES_MODULE" => "YES",
    "HEADER_SEARCH_PATHS" => "\"$(PODS_ROOT)/boost\""
  }

  s.dependency "React-Core"
  s.dependency "ReactCommon"

  if rn_minor >= 85
    s.dependency "ReactNativeDependencies"
  else
    s.dependency "React-Codegen"
    s.dependency "RCT-Folly"
  end
end
