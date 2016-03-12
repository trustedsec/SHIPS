require 'usa'
require 'net/ldap'
require_relative '../lib/ldaphelpers'
require_relative 'directoryldap'

class IdentLDAP < WEBrick::USA::User::Identity
  include LDAP_Helpers
  self.directory = DirectoryLDAP

  def initialize(optional={})
    super optional
    @ldap = Net::LDAP.new
    @ldap.host = @optional[:identLDAP_host]
    @ldap.port = @optional[:identLDAP_port].to_i
    @ldap.encryption @optional[:identLDAP_encryption].to_sym if optional[:identLDAP_encryption]
    @ldap.base = @optional[:identLDAP_user_base]
    @ldap.auth @optional[:identLDAP_username], @optional[:identLDAP_password]
  end

  def login(form_data)
    return false unless name_valid? form_data['username']
    return false if form_data['password'].to_s.empty?
    filter = Net::LDAP::Filter.eq(@optional[:identLDAP_name_attribute], form_data['username'])
    if @optional[:identLDAP_group_required]
      filter2 = Net::LDAP::Filter.eq(@optional[:identLDAP_group_attribute], @optional[:identLDAP_group_required])
      filter = Net::LDAP::Filter.join(filter, filter2)
    end
    scope = Net::LDAP::SearchScope_WholeSubtree
    attributes = [@optional[:identLDAP_name_attribute], @optional[:identLDAP_token_attribute]]
    if rs = @ldap.bind_as({:filter => filter,
                          :scope => scope,
                          :password => form_data['password'],
                          :attributes => attributes})
      r = rs.first #first item in the record set, bind_as returns an array.
      if @optional[:identLDAP_token_attribute] == 'objectSid' #special treatment for AD
        @usertoken = get_sid_string(r[@optional[:identLDAP_token_attribute]].first)
      else
        @usertoken = r[@optional[:identLDAP_token_attribute]].first.to_s
      end
      @username = r[@optional[:identLDAP_name_attribute]].first.to_s
    else
      return false
    end
    self
  rescue StandardError => ex
    @usertoken = nil
    @username = nil
    false
  end

  def self.form_inner_html
    <<WWWFORM
       <table><tbody>
       <tr>
       <td>User Name:</td>
       <td><input class="PlainTextIn" maxlength=50 name="username" type="text"></td>
       </tr>
       <tr>
       <td>Password:</td>
       <td><input class="PasswordIn" maxlength=255 name="password" type="password" autocomplete="off"></td>
       </tr>
       </tbody></table>
WWWFORM
  end

  private
  def name_valid?(v)
    # This is a reasonable thing to do for AD it might not be technically true for other LDAP environments
    # still seems like a reasonable limitation on user names.
    return false unless v
    return false unless v.length > 0
    return false unless v.length < 21 #20 chars is max user name length on winders
    char_cnt = 0
    ['/', '[', ']', "\"", ':', ';', '|', '<', '>', '+', '=', ',', '?', '*', ' ', '_', '&', "\0"].each { |c| char_cnt += v.count(c) }
    return false if char_cnt > 0
    true
  end

end
