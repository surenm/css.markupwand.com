require 'tidy_ffi'
if Rails.env.production?
  TidyFFI.library_path = Rails.root.join("lib", "native", "libtidy.so").to_s
  require 'tidy_ffi/interface'
  require 'tidy_ffi/lib_tidy'
end