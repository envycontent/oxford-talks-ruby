require 'ldap'

module InstallationHelper

  class Installation
    attr_reader :installationName, :bugsEmail, :webmasterEmail, :noReplyEmail, :talksSmallLogoURL, :talksBigLogoURL, :favIconURL, :arrowURL,
      :talksSiteName, :talksSiteHost, :collegeOrUniversityName, :townName, :collegeOrUniversityLogoURL, :collegeOrUniversityURL,
      :collegeOrUniversityExampleEmail, :localLoginLinkText, :loginSystemName, :localLoginAction,
      :loginController, :styleSheet, :footerMessage, :searchExample
  
    def initialize(installationName, bugsEmail, webmasterEmail, noReplyEmail, talksSmallLogoURL, talksBigLogoURL, favIconURL, arrowURL, talksSiteName,
      talksSiteHost, collegeOrUniversityName, townName, collegeOrUniversityLogoURL, collegeOrUniversityURL,
      collegeOrUniversityExampleEmail, localLoginLinkText, loginSystemName, localLoginAction, loginController, styleSheet, footerMessage, searchExample)
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
    end

    def to_str()
      return @installationName
    end
  end

  class OxfordInstallation < Installation
    def initialize()
      super('oxford', 'talks@linacre.ox.ac.uk', 'talks@linacre.ox.ac.uk', 'noreply@linacre.ox.ac.uk', 'OxfordTalksLogo.png', 
      	'OxfordTalksLogo.png', 'favicon-ox.ico', 'redarrow.gif',
        'Oxford Talks', 'talks.linacre.ox.ac.uk', 'University of Oxford', 'Oxford', 'identifier2-ox.gif', 'http://www.ox.ac.uk',
        'first.lastname@college_or_department.ox.ac.uk', 'Oxford users (SSO)', 'SSO (Single Sign On)', 'go_to_secure_webauth',
        Login::OxfordssologinController, 'talks-screen-ox',
        'Oxford Talks is based on talks.cam which is &copy; University of Cambridge.', 'e.g. africa, ageing, maths')
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

    def local_user_from_id(id)
      # Note that for this to work, we need a valid kerberos ticket
      # at this point. One way is to go:
      #    kinit -k -t /etc/keytab services/hostname`
      # annother is to use k5start (see
      # http://www.eyrie.org/~eagle/software/kstart/k5start.html)
      # and a set KRB5CCNAME in the apache config
      # This is what we are doing
      conn = LDAP::SSLConn.new(host='ldap.oak.ox.ac.uk', port=636)
      #conn.sasl_quiet=true
      conn.sasl_bind('','')

      singleEntry = nil

      conn.search('ou=people,dc=oak,dc=ox,dc=ac,dc=uk', LDAP::LDAP_SCOPE_ONELEVEL, 
        "(oakPrincipal=krbPrincipalName=#{id}@OX.AC.UK,cn=OX.AC.UK,cn=KerberosRealms,dc=oak,dc=ox,dc=ac,dc=uk)", nil) { |entry|
        email = entry.get_values("mail")[0]
        name = entry.get_values("displayName")[0]
        sep = ", "
        ouValues = entry.get_values("ou")
        combinedOUValue = ouValues != nil ? ouValues.join(sep) : "";
        combinedOrganization = entry.get_values("o")[0] + sep + combinedOUValue
        return User.create! :crsid => id, :email => email, :affiliation => combinedOrganization, :name => name
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
        'e.g. Surfaces and strings, Darwin lectures, Thomas Young, meerkat, Lord Adonis')
    end

    def user_from_http_header(request)
      return nil unless AuthenticationHelper.authorization(request)
      return nil if AuthenticationHelper.authorization(request).empty?
      User.authenticate(*AuthenticationHelper.email_and_password(request))
    end

    def local_user_from_id(id)
      return User.create! :crsid => id, :email => local_email_address_from_id(id), :affiliation => collegeOrUniversityName
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
  
  #@@CURRENT_INSTALLATION = OxfordInstallation.new
  @@CURRENT_INSTALLATION = CambridgeInstallation.new

  def self.CURRENT_INSTALLATION
    return @@CURRENT_INSTALLATION
  end

  #def self.CURRENT_INSTALLATION=(new_installation)
  #  @@CURRENT_INSTALLATION = new_installation
  #end
end
