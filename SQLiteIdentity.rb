#!/usr/bin/ruby
require 'webrick'
require 'time'
require 'socket'
require 'getoptlong'
require_relative 'lib/configuration'
require 'SQLiteORM'
require_relative 'lib/directory_models'

def startup(cfg_path=nil)
  application_dir = File.expand_path(File.dirname(__FILE__))
  settings = Configuration.new(cfg_path || application_dir + '/etc/conf')
  database = SQLite3::Database.new(settings['data','dataPath',application_dir + '/var/data/SHIPS.sqlite'])

  #bind the models to the application database
  database_lock = Mutex.new
  ObjectSpace.each_object(Class).select {|klass| klass < SQLiteORM }.each do |model|
    model.database = database
    model.lock = database_lock
  end

rescue StandardError => e
  puts 'Encountered a fatal startup error!'
  puts e.message
  Kernel.exit! false
end

def generate_password
  #generates password with complexity 3 of upper/lower/number/special
  complex = 0
  while complex < 4 do
    newpwd = Array.new(12) { SecureRandom.random_number(94) + 32 } #array of printing chars
    complex = complex + 1 if newpwd.index { |a| (65..90).include? a } #upper
    complex = complex + 1 if newpwd.index { |a| (97..122).include? a } #lower
    complex = complex + 1 if newpwd.index { |a| (48..57).include? a } #number
    complex = complex + 1 if newpwd.index { |a| ((32..47).include? a) or #specials
        ((58..64).include? a) or
        ((91..96).include? a) or
        ((123..126).include? a) }
  end
  newpwd.map { |a| a.chr }.join
end

def helptext
  puts <<HELPTEXT
  If using an alternative config the path should be the first argument.

--help,       -h :Print this message
--user,       -u :Name of user for operation
--group,      -g :Name of group for operation
--description -d :Description for group
--operation   -o :operation to perform [addUser, addGroup,
                                      addUserToGroup, deleteUser,
                                      deleteGroup,
                                      removeUserFromGroup]
--listUsers   -U :Display list of users
--listGroups  -G :Display list of groups

create a user:
  -o addUser -u bob

create a group
 -o addGroup -g users

set the group users description
-o setGroupDescription -d 'admin users' -g users

add user bob to group users
-o addUserToGroup -u bob -g users

remove user bob from group users
-o removeUserFromGroup -u bob -g users

delete the group users
-o deleteGroup -g users

delete the user bob
-o deleteUser -u bob
HELPTEXT
end
unless ARGV[0]
  helptext
  exit 0
end
if ARGV[0][0] != '-'
  startup ARGV[0]
  ARGV.shift
else
  startup
end
options = GetoptLong.new(
    ['--help', '-h', GetoptLong::NO_ARGUMENT],
    ['--listUsers', '-U', GetoptLong::NO_ARGUMENT],
    ['--listGroups', '-G', GetoptLong::NO_ARGUMENT],
    ['--operation', '-o', GetoptLong::REQUIRED_ARGUMENT],
    ['--user', '-u', GetoptLong::REQUIRED_ARGUMENT],
    ['--group', '-g', GetoptLong::REQUIRED_ARGUMENT],
    ['--description', '-d', GetoptLong::REQUIRED_ARGUMENT]
)

description = nil
user = nil
group = nil
operation = nil
options.each do |option, argument|
  case option
    when '--help'
      helptext
      exit 0
    when '--listUsers'
      UserAccount.each {|user| puts "#{user.username} token: #{user.id.to_s}" }
      Kernel.exit! false
    when '--listGroups'
      GroupAccount.each {|group| puts "#{group.groupname} - #{group.description} token: #{group.id.to_s}" }
      Kernel.exit! false
    when '--description'
      description = argument
    when '--user'
      user = argument
    when '--group'
      group = argument
    when '--operation'
      operation = argument.downcase
  end
end

begin
  x = nil
  case operation
    when 'adduser'
      UserAccount.new
      raise ArgumentError 'a user must be specified' unless user
      x = UserAccount.new
      x.username = user
      pwd = generate_password
      x.password = pwd
      puts "Initial Password: #{pwd}"
    when 'addgroup'
      raise ArgumentError 'a group must be specified' unless group
      x = GroupAccount.new
      x.groupname = group
      x.description = description
    when 'deleteuser'
      raise ArgumentError 'a user must be specified' unless user
      x = UserAccount.load_by_user user
      x.delete if x
      x = nil
    when 'deletegroup'
      raise ArgumentError 'a group must be specified' unless group
      x = GroupAccount.load_by_group group
      x.delete if x
      x = nil
    when 'addusertogroup'
      raise ArgumentError 'a group must be specified' unless group
      raise ArgumentError 'a user must be specified' unless user
      u = UserAccount.load_by_user user
      g = GroupAccount.load_by_group group
      raise StandardError, 'group not found' unless g
      raise StandardError, 'user not found' unless u
      x = GroupUserRelation.new
      x.GroupAccount = g
      x.UserAccount = u
    when 'removeuserfromgroup'
      raise ArgumentError 'a group must be specified' unless group
      raise ArgumentError 'a user must be specified' unless user
      g = GroupAccount.load_by_group group
      u = UserAccount.load_by_user user
      x = GroupUserRelation.new
      raise StandardError, 'group not found' unless g
      raise StandardError, 'user not found' unless u
      GroupUserRelation.each_with_ex([[:UserAccount, u],[:GroupAccount, g]]) {|x| x.delete}
      x = nil
    else
      raise ArgumentError, 'Unknown options'
  end
  x.save if x

rescue StandardError,ArgumentError => e
  puts 'Encountered a fatal error!'
  puts e.message
  Kernel.exit! false
end