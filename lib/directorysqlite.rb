require 'usa'
require_relative 'directory_models'

class DirectorySQLite < WEBrick::USA::User::Directory

  def get_groups
    groups = Array.new
    GroupAccount.each { |group| groups << WEBrick::USA::User::Group.new(group.groupname, group.id) }
    groups
  end

  def get_idents_groups(identity)
    groups = Array.new
    GroupUserRelation.each_with(:UserAccount, identity.usertoken, :equal) do |group_pointer|
      group = group_pointer.GroupAccount
      groups << WEBrick::USA::User::Group.new(group.groupname, group.id)
    end
    groups
  end

  def get_idents
    idents = Array.new
    UserAccount.each { |user| idents << self.identity.new.impersonate(user.id, user.username) }
    idents
  end

  def get_groups_by_name(name)
    groups = Array.new
    GroupAccount.each_with(:groupname, name, :equal) { |group| groups << WEBrick::USA::User::Group.new(group.groupname, group.id) }
    groups
  end

  def get_group_by_token(token)
    group = GroupAccount.new.load(token.to_i)
    return WEBrick::USA::User::Group.new(group.groupname, group.id) if group
    nil
  end

  def get_user_name(token)
    user = UserAccount.new.load(token.to_i)
    return user.username if user
    ''
  end

  def get_idents_by_name(name)
    idents = Array.new
    UserAccount.each_with(:username, name, :equal ) { |user| idents << self.identity.new.impersonate(user.id, user.username) }
    idents
  end

  def get_ident_by_token(token)
    user = UserAccount.new.load(token.to_i)
    return self.identity.new.impersonate(user.id, user.username) if user
    nil
  end

  def members_of_group(group)
    idents = Array.new
    GroupUserRelation.each_with(:GroupAccount, group.grouptoken, :equal) do |gur|
      user = gur.UserAccount
      idents << self.identity.new.impersonate(user.id, user.username)
    end
    idents
  end

end