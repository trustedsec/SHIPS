require 'usa'
require 'net/ldap'
require_relative 'ldaphelpers'

class DirectoryLDAP < WEBrick::USA::User::Directory

  include LDAP_Helpers

  def initialize(optional={})
    super optional
    @ldap = Net::LDAP.new
    @ldap.host = @optional[:identLDAP_host]
    @ldap.port = @optional[:identLDAP_port].to_i
    @ldap.encryption @optional[:identLDAP_encryption].to_sym if optional[:identLDAP_encryption]
    @ldap.base = @optional[:identLDAP_user_base]
    @ldap.auth @optional[:identLDAP_username], @optional[:identLDAP_password]
  end

  def get_groups
    filter = Net::LDAP::Filter.eq('objectClass', @optional[:identLDAP_group_class])
    group_search filter
  end


  def get_idents
    filter = Net::LDAP::Filter.eq('objectClass', @optional[:identLDAP_user_class])
    user_search filter
  end

  def get_groups_by_name(name)
    filter1 = Net::LDAP::Filter.eq('objectClass', @optional[:identLDAP_group_class])
    filter2 = Net::LDAP::Filter.eq(@optional[:identLDAP_name_attribute], name)
    group_search Net::LDAP::Filter.join(filter1, filter2)
  end

  def get_group_by_token(token)
    filter1 = Net::LDAP::Filter.eq('objectClass', @optional[:identLDAP_group_class])
    filter2 = Net::LDAP::Filter.eq(@optional[:identLDAP_token_attribute], token)
    groups = group_search Net::LDAP::Filter.join(filter1, filter2)
    return nil unless groups.count == 1
    groups[0]
  end

  def get_idents_by_name(name)
    filter1 = Net::LDAP::Filter.eq('objectClass', @optional[:identLDAP_user_class])
    filter2 = Net::LDAP::Filter.eq(@optional[:identLDAP_name_attribute], name)
    user_search Net::LDAP::Filter.join(filter1, filter2)
  end

  def get_ident_by_token(token)
    filter1 = Net::LDAP::Filter.eq('objectClass', @optional[:identLDAP_user_class])
    filter2 = Net::LDAP::Filter.eq(@optional[:identLDAP_token_attribute], token)
    users = user_search Net::LDAP::Filter.join(filter1, filter2)
    return nil unless users.count == 1
    return users[0]
  end

  def get_user_name(token)
    user = get_ident_by_token token
    return '' unless user
    return user.username
  end

  def members_of_group(group)
    filter1 = Net::LDAP::Filter.eq('objectClass', @optional[:identLDAP_group_class])
    filter2 = Net::LDAP::Filter.eq(@optional[:identLDAP_token_attribute], group.grouptoken)
    filter = Net::LDAP::Filter.join(filter1, filter2)
    groups = Array.new
    scope = Net::LDAP::SearchScope_WholeSubtree
    attributes = [@optional[:identLDAP_token_attribute], @optional[:identLDAP_name_attribute]]
    if rs = @ldap.search({ :filter => filter,
                   :scope => scope,
                   :attributes => attributes,
                   :base => @optional[:identLDAP_group_base]
                 })
      return Array.new unless rs.count == 1
      r = rs.first
      dn = r['dn'].first.to_s
    else
      return Array.new
    end
    filter1 = Net::LDAP::Filter.eq('objectClass', @optional[:identLDAP_user_class])
    filter2 = Net::LDAP::Filter.eq(@optional[:identLDAP_group_attribute], dn)

    user_search Net::LDAP::Filter.join(filter1, filter2)
  end

  def get_idents_groups(identity)
    dns = Array.new
    groups = Array.new
    scope = Net::LDAP::SearchScope_WholeSubtree
    filter1 = Net::LDAP::Filter.eq('objectClass', @optional[:identLDAP_user_class])
    filter2 = Net::LDAP::Filter.eq(@optional[:identLDAP_token_attribute], identity.usertoken)
    filter = Net::LDAP::Filter.join(filter1, filter2)
    attributes = [@optional[:identLDAP_group_attribute]]
    if rs = @ldap.search({ :filter => filter,
                           :scope => scope,
                           :attributes => attributes,
                           :base => @optional[:identLDAP_user_base]
                         })
      return Array.new unless rs.count == 1
      r = rs.first
      dns = r[@optional[:identLDAP_group_attribute]]
    else
      return Array.new
    end

    filter1 = Net::LDAP::Filter.eq('objectClass', @optional[:identLDAP_group_class])
    dns.each do |dn|
      filter2 = Net::LDAP::Filter.eq('distinguishedName', dn.to_s)
      groups += group_search Net::LDAP::Filter.join(filter1, filter2)
    end

    groups
  end

  private

  def group_search(filter)
    groups = Array.new
    scope = Net::LDAP::SearchScope_WholeSubtree
    attributes = [@optional[:identLDAP_token_attribute], @optional[:identLDAP_name_attribute]]
    @ldap.search({ :filter => filter,
                   :scope => scope,
                   :attributes => attributes,
                   :base => @optional[:identLDAP_group_base]
                 }) do |group|
      if @optional[:identLDAP_token_attribute] == 'objectSid'
        groups << WEBrick::USA::User::Group.new(group[@optional[:identLDAP_name_attribute]].first.to_s,
                                                get_sid_string(group[@optional[:identLDAP_token_attribute]].first))
      else
        groups << WEBrick::USA::User::Group.new(group[@optional[:identLDAP_name_attribute]].first.to_s,
                                                group[@optional[:identLDAP_token_attribute]].first.to_s)
      end
    end
    groups
  end

  def user_search(filter)
    idents = Array.new
    scope = Net::LDAP::SearchScope_WholeSubtree
    attributes = [@optional[:identLDAP_name_attribute], @optional[:identLDAP_token_attribute]]
    @ldap.search({ :filter => filter,
                   :scope => scope,
                   :attributes => attributes,
                   :base => @optional[:identLDAP_user_base]
                 }) do |user|
      if @optional[:identLDAP_token_attribute] == 'objectSid'
        idents << self.identity.new.impersonate(get_sid_string(user[@optional[:identLDAP_token_attribute]].first),
                                      user[@optional[:identLDAP_name_attribute]].first.to_s)
      else
        idents << self.identity.new.impersonate(user[@optional[:identLDAP_token_attribute]].first.to_s,
                                      user[@optional[:identLDAP_name_attribute]].first.to_s)
      end
    end
    idents
  end

end