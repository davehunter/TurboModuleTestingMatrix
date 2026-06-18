require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

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
  s.dependency "React-Codegen"
  s.dependency "ReactCommon"
  s.dependency "RCT-Folly"
end
