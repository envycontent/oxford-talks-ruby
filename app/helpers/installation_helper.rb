require 'ldap'

module InstallationHelper

  class Installation
    attr_reader :installationName, :bugsEmail, :webmasterEmail, :noReplyEmail, :talksSmallLogoURL, :talksBigLogoURL, :favIconURL, :arrowURL,
      :talksSiteName, :talksSiteHost, :collegeOrUniversityName, :townName, :collegeOrUniversityLogoURL, :collegeOrUniversityURL,
      :collegeOrUniversityExampleEmail, :localLoginLinkText, :loginSystemName, :localLoginAction,
      :loginController, :styleSheet, :footerMessage, :searchExample, :only_admin_edit_documents
  
    def initialize(installationName, bugsEmail, webmasterEmail, noReplyEmail, talksSmallLogoURL, talksBigLogoURL, favIconURL, arrowURL, talksSiteName,
      talksSiteHost, collegeOrUniversityName, townName, collegeOrUniversityLogoURL, collegeOrUniversityURL,
      collegeOrUniversityExampleEmail, localLoginLinkText, loginSystemName, localLoginAction, loginController, styleSheet, footerMessage, searchExample, only_admin_edit_documents)
      @installationName = installationName
      @bugsEmail = bugsEmail
      @webmasterEmail = webmasterEmail
      @noReplyEmail = noReplyEmail
      @talksSmallLogoURL = talksSmallLogoURL
      @talksBigLogoURL = talksBigLogoURL
      @favIconURL = favIconURL
      @arrowURL = arrowURL
      @talksSiteName = talksSiteName
      @talksSiteHost = talksSiteHost
      @collegeOrUniversityName = collegeOrUniversityName
      @townName = townName
      @collegeOrUniversityLogoURL = collegeOrUniversityLogoURL
      @collegeOrUniversityURL = collegeOrUniversityURL
      @collegeOrUniversityExampleEmail = collegeOrUniversityExampleEmail
      @localLoginLinkText = localLoginLinkText
      @loginSystemName = loginSystemName
      @localLoginAction = localLoginAction
      @loginController = loginController
      @styleSheet = styleSheet
      @footerMessage = footerMessage
      @searchExample = searchExample
      @only_admin_edit_documents = only_admin_edit_documents
    end

    def to_str()
      return @installationName
    end
  end

  class OxfordInstallation < Installation
    def initialize()
      super('oxford', 'oxtalks-bugs@it.ox.ac.uk', 'oxtalks-contact@it.ox.ac.uk', 'noreply@talks.ox.ac.uk', 'OxfordTalksLogo.png', 
      	'OxfordTalksLogo.png', 'favicon-ox-uni.ico', 'redarrow.gif',
        'Oxford Talks', 'talks.ox.ac.uk', 'University of Oxford', 'Oxford', 'identifier2-ox.gif', 'http://www.ox.ac.uk',
        'first.lastname@college_or_department.ox.ac.uk', 'Oxford users (SSO)', 'SSO (Single Sign On)', 'go_to_secure_webauth',
        Login::OxfordssologinController, 'talks-screen-ox',
        'Oxford Talks is based on talks.cam which is &copy; University of Cambridge.', 'e.g. africa, ageing, maths', true)
    end

    def user_from_http_header(request)
      username = webauth_username(request)
      if username != nil then
        return User.find_or_create_by_crsid(username)
      end
      
      return nil unless AuthenticationHelper.authorization(request)
      return nil if AuthenticationHelper.authorization(request).empty?

      return User.authenticate(*AuthenticationHelper.email_and_password(request))
    end

    def webauth_username(request)
      request.env['WEBAUTH_USER']
    end

    def open_ldap_connection
      # Note that for this to work, we need a valid kerberos ticket
      # at this point. One way is to go:
      #    kinit -k -t /etc/keytab services/hostname`
      # annother is to use k5start (see
      # http://www.eyrie.org/~eagle/software/kstart/k5start.html)
      # and a set KRB5CCNAME in the apache config
      # This is what we are doing
      Rails.logger.debug "LDAPing again"
      ENV['KRB5CCNAME'] = '/var/cache/k5start/talks-ox-ac-uk.ccache'
      Rails.logger.debug ENV['KRB5CCNAME']
      conn = LDAP::SSLConn.new(host='ldap.oak.ox.ac.uk', port=636)
      # Noisy sasl generates lots of logging output
      conn.sasl_quiet=false
      conn.sasl_bind('','')
      return conn
    end

    @@ldap_base = 'ou=people,dc=oak,dc=ox,dc=ac,dc=uk'

    def local_id_from_email(email)
      open_ldap_connection.search(@@ldap_base, LDAP::LDAP_SCOPE_ONELEVEL, "(oakAlternativeMail=#{email})") { |entry|
        return entry.get_values("oakOxfordSSOUsername")[0]
      }
      # Couldn't find that user
      return nil
    end

    def local_user_from_id(id)
      open_ldap_connection.search(@@ldap_base, LDAP::LDAP_SCOPE_ONELEVEL, 
        "(oakPrincipal=krbPrincipalName=#{id}@OX.AC.UK,cn=OX.AC.UK,cn=KerberosRealms,dc=oak,dc=ox,dc=ac,dc=uk)", nil) { |entry|
        email = entry.get_values("mail")[0]
        name = entry.get_values("displayName")[0]
        affiliation_separator = ", "
        ou_values = entry.get_values("ou")
        combined_ou_value = ou_values != nil ? ou_values.join(affiliation_separator) : ""
        combined_organization = entry.get_values("o")[0] + affiliation_separator + combined_ou_value
        return User.create! :crsid => id, :email => email, :affiliation => combined_organization, :name => name
      }
    end

    def is_local_user?(user)
      not user.nil? and not user.crsid.nil?
    end
  end  
  
  class CambridgeInstallation < Installation
    def initialize()
      super('cambridge', %w( BUGS@talks.cam ), 'webmaster@talks.cam.ac.uk', 'noreply@talks.cam.ac.uk', 'talkslogosmall.gif', 'reallybigtalkslogo.gif',
        'favicon-cam.ico', 'redarrow.gif', 'talks.cam', 'talks.cam.ac.uk', 'University of Cambridge', 'Cambridge', 'identifier2.gif',
        'http://www.cam.ac.uk', 'crsid@cam.ac.uk', 'Cambridge users (raven)', 'raven', 'go_to_raven',
        Login::RavenloginController, 'talks-screen-cam', '&copy; 2006-2009 talks.cam, University of Cambridge',
        'e.g. Surfaces and strings, Darwin lectures, Thomas Young, meerkat, Lord Adonis', false)
    end

    def user_from_http_header(request)
      return nil unless AuthenticationHelper.authorization(request)
      return nil if AuthenticationHelper.authorization(request).empty?
      User.authenticate(*AuthenticationHelper.email_and_password(request))
    end

    def local_user_from_id(id)
      return User.create! :crsid => id, :email => local_email_address_from_id(id), :affiliation => collegeOrUniversityName
    end

    def local_id_from_email(email)
      return unless email =~ /^([a-z0-9]+)@cam.ac.uk$/i
      return $1
    end

    def is_local_user?(user)
      return user.email.include? "@cam.ac.uk"
    end

    private

    def local_email_address_from_id(id)
      return "#{id}@cam.ac.uk";
    end
  end

  class AuthenticationHelper
    def self.email_and_password(request)
      Base64.decode64(credentials(request)).split(/:/, 2)
    end  

    def self.credentials(request)
      authorization(request).split.last
    end

    def self.authorization(request)
      request.env['HTTP_AUTHORIZATION']   ||
      request.env['X-HTTP_AUTHORIZATION'] ||
      request.env['X_HTTP_AUTHORIZATION'] ||
      request.env['REDIRECT_X_HTTP_AUTHORIZATION']
    end
  end
  
  @@CURRENT_INSTALLATION = OxfordInstallation.new
  #@@CURRENT_INSTALLATION = CambridgeInstallation.new

  def self.CURRENT_INSTALLATION
    return @@CURRENT_INSTALLATION
  end

  #def self.CURRENT_INSTALLATION=(new_installation)
  #  @@CURRENT_INSTALLATION = new_installation
  #end
end
