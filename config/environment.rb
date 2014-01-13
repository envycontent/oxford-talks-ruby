# Be sure to restart your web server when you modify this file.

# Uncomment below to force Rails into production mode when 
# you don't control web/app server and can't set it the proper way
ENV['RAILS_ENV'] ||= 'production'

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')
ENV['LANG'] = 'en_GB.utf8'

Rails::Initializer.run do |config|
  # Settings in config/environments/* take precedence those specified here
  
  # Skip frameworks you're not going to use
  # config.frameworks -= [ :action_web_service, :action_mailer ]

  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/extras )

  # Force all environments to use the same logger level 
  # (by default production uses :info, the others :debug)
  # config.log_level = :debug

  # Use the database for sessions instead of the file system
  # (create the session table with 'rake create_sessions_table')
  config.action_controller.session_store = :active_record_store

  # Enable page/fragment caching by setting a file-based store
  # (remember to create the caching directory and make it readable to the application)
  # config.action_controller.fragment_cache_store = :file_store, "#{RAILS_ROOT}/cache"

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector
  
  # Make Active Record use UTC-base instead of local time
  # config.active_record.default_timezone = :utc
  
  # Use Active Record's schema dumper instead of SQL when creating the test database
  # (enables use of different database adapters for development and test environments)
  config.active_record.schema_format = :ruby

  # See Rails::Configuration for more options

  # This is neccessary to make the images in embedded feeds work
  # config.action_controller.asset_host = Proc.new { |source, request|
  #   "#{request.protocol}#{request.host_with_port}"
  # }
  
  # Configure the mailer
  config.action_mailer.delivery_method = :sendmail
  config.action_mailer.raise_delivery_errors = true
end

# Add new inflection rules using the following format 
# (all these examples are active by default):
# Inflector.inflections do |inflect|
#   inflect.plural /^(ox)$/i, '\1en'
#   inflect.singular /^(ox)en/i, '\1'
#   inflect.irregular 'person', 'people'
#   inflect.uncountable %w( fish sheep )
# end

# Include your application configuration below

require 'icalendar_extensions'

begin 
  require 'RMagick'
rescue LoadError
  require_gem 'RMagick'
end

# TODO: Investigate if this needs changing. This method has been removed from TextHelper, and is not on SanitizeHelper (?)
#module ActionView
#  module Helpers
#    module TextHelper
#      module_function :sanitize
#    end
#  end
#end

# Configure the exception notification plugin
ExceptionNotifier.exception_recipients = InstallationHelper.CURRENT_INSTALLATION.bugsEmail
ExceptionNotifier.sender_address =%( "talks.cam" <BUGS_SENDER@talks.cam> )

# Monkey patch ActionMailer to force a return-path to be inserted
class ActionMailer::Base
  def perform_delivery_sendmail(mail)
#    IO.popen("/usr/sbin/sendmail -i -t","w+") do |sm|
    IO.popen("/usr/sbin/sendmail -i -t -fBUGS_ENVELOPE@talks.cam","w+") do |sm|
      sm.print(mail.encoded.gsub(/\r/, ''))
      sm.flush
    end
  end
end

# FIXME yuck, Ruby version incompatibility
# probably caused by Rails 1.2.3 adding String#chars
# and then Ruby catching up and adding its own one by 1.8.7
# http://old.teabass.com/undefined-method-for-enumerable/
#unless '1.9'.respond_to?(:force_encoding)
if RUBY_VERSION=='1.8.7'
  String.class_eval do
    begin
      remove_method :chars
    rescue NameError
        # OK
    end
  end
end

# FIXME yuck, Ruby version incompatibility
# I've chosen to roll back to 1.8.5; but in any case
# 1.8.7 apparently had a known bug too, which didn't get fixed until 1.9?
# http://redmine.ruby-lang.org/issues/show/2147
# http://svn.ruby-lang.org/cgi-bin/viewvc.cgi/trunk/lib/pp.rb?r1=25122&r2=25121&pathrev=25122
if RUBY_VERSION=='1.8.7'
  class PP < PrettyPrint
    module ObjectMixin
  
  # 1.8.5 version
      def pretty_print(q)
        if /\(Kernel\)#/ !~ method(:inspect).inspect
          q.text self.inspect
        elsif /\(Kernel\)#/ !~ method(:to_s).inspect && instance_variables.empty?
          q.text self.to_s
        else
          q.pp_object(self)
        end
      end
  
    end
  end
end

# Replacements for the Rack::Utils parse_query and normalize_params methods.
# Code is from Rack 1.1.0 with the patch at 
# http://github.com/rack/rack/commit/dae12e088592ee69545b5f2f81b87f4959859164
# applied.
#
# Fixes a bug where pairs of quotes in parameter values cause the parameter
# to be truncated. See:
# https://rails.lighthouseapp.com/projects/8994/tickets/4808-textarea-input-silently-truncated-in-238
#
#  Slight modification from original patch: Before this was conditional on finding Rack 1.1.0 gem. Now,
# it runs regardless. It seems 1.1.3 still suffers from the same problem, and on the development
# server the gem isn't found, but the code still somehow runs.
#
module Rack
  module Utils
    def parse_query(qs, d = nil)
      params = {}

      (qs || '').split(d ? /[#{d}] */n : DEFAULT_SEP).each do |p|
        k, v = p.split('=', 2).map { |x| unescape(x) }
        if cur = params[k]
          if cur.class == Array
            params[k] << v
          else
            params[k] = [cur, v]
          end
        else
          params[k] = v
        end
      end

      return params
    end
    module_function :parse_query

    def normalize_params(params, name, v = nil)
      name =~ %r(\A[\[\]]*([^\[\]]+)\]*)
      k = $1 || ''
      after = $' || ''

      return if k.empty?

      if after == ""
        params[k] = v
      elsif after == "[]"
        params[k] ||= []
        raise TypeError, "expected Array (got #{params[k].class.name}) for param `#{k}'" unless params[k].is_a?(Array)
        params[k] << v
      elsif after =~ %r(^\[\]\[([^\[\]]+)\]$) || after =~ %r(^\[\](.+)$)
        child_key = $1
        params[k] ||= []
        raise TypeError, "expected Array (got #{params[k].class.name}) for param `#{k}'" unless params[k].is_a?(Array)
        if params[k].last.is_a?(Hash) && !params[k].last.key?(child_key)
          normalize_params(params[k].last, child_key, v)
        else
          params[k] << normalize_params({}, child_key, v)
        end
      else
        params[k] ||= {}
        raise TypeError, "expected Hash (got #{params[k].class.name}) for param `#{k}'" unless params[k].is_a?(Hash)
        params[k] = normalize_params(params[k], after, v)
      end

      return params
    end
    module_function :normalize_params
  end
end




