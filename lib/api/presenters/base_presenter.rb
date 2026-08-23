module Api
  module Presenters
    module BasePresenter
      extend ActiveSupport::Concern

      def base_url(opts)
        return unless opts.key?(:env)

        request = Grape::Request.new(opts[:env])
        "#{request.base_url}#{forwarded_prefix(opts[:env])}"
      end

      def request_url(opts)
        return unless opts.key?(:env)

        "#{base_url(opts)}#{opts[:env]['PATH_INFO']}"
      end

      private

      def forwarded_prefix(env)
        prefix = env['HTTP_X_FORWARDED_PREFIX'].to_s
        return '' unless prefix.start_with?('/')

        prefix.chomp('/')
      end
    end
  end
end
