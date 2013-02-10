module ActionView
  module Helpers
    module AssetTagHelper
      def accept_encoding?(encoding)
        (request.env['HTTP_ACCEPT_ENCODING'] || '').split(',').include?(encoding)
      end
      def rewrite_path_to_gzip?(source)
        (! config.asset_host.blank?) and (source =~ /assets\//) and accept_encoding?('gzip')
      end
      def path_to_javascript(source)
        source = rewrite_path_to_gzip(source) if rewrite_path_to_gzip?(source)
        compute_public_path(source, 'javascripts', 'js')
      end
      def path_to_stylesheet(source)
        source = rewrite_path_to_gzip(source) if rewrite_path_to_gzip?(source)
        compute_public_path(source, 'stylesheets', 'css')
      end
      def rewrite_path_to_gzip(source)
        source + ".cgz"
      end
    end
  end