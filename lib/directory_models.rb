require 'SQLiteORM'
require 'securerandom'
require 'digest'
require 'base64'

#Simple class to do logins based on database records
class UserAccount
  include SQLiteORM
  persist_attr_reader :password, :TEXT
  persist_attr_reader :username, :TEXT
  persist_attr_reader :salt, :TEXT
  persist_attr :tombstone, :INTEGER
  unique_attrs :username
  order_by_attr :username, :DESC
  attr_reader :id

  @@SPECIALS = ['^', '%', '@', '#', '$', '!', '/', '[', ']', "\"", ':', ';', '|', '<', '>', '+', '=', ',', '?', '*', ' ', '_', '&', '(', ')', "\0"]
  @@NUMBERS = %w(1 2 3 4 5 6 7 8 9 0)

  def self.load_by_user(username)
    obj = nil
    each_with(:username, username.downcase) {|x| obj = x}
    obj
  end

  def before_save
    @tombstone = Time.new.to_i
  end

  def tombstone
    Time.at @tombstone
  end
  
  def username=(v)
    char_cnt = 0
    @@SPECIALS.each { |c| char_cnt += v.count(c) }
    raise ArgumentError, 'User names cannot contain special characters.' unless char_cnt == 0
    @username = v.downcase
  end
  
  def password=(v)
    char_cnt = 0
    raise ArgumentError, 'Password is to short provide at least 8 characters' unless v.length > 7
    @@SPECIALS.each { |c| char_cnt += v.count(c) }
    raise ArgumentError, 'Password should contain at least one special character' unless char_cnt > 0
    char_cnt = 0
    @@NUMBERS.each { |c| char_cnt += v.count(c) }
    raise ArgumentError, 'Password should contain at least one number character' unless char_cnt > 0

    sha2 = Digest::SHA2.new(bitlen = 256)
    sha2 << v
    @salt = SecureRandom.random_number(2147483647).to_s
    sha2 << @salt
    @password = Base64.strict_encode64(sha2.digest) 
  end

  def password?(pass)
    sha2 = Digest::SHA2.new(bitlen = 256)
    sha2 << pass
    sha2 << @salt.to_s
    Base64.strict_encode64(sha2.digest) == @password
  end

  def before_delete
    self.each_GroupUserRelation {|gur| gur.delete }
  end

end

class GroupAccount
  include SQLiteORM
  persist_attr_accessor :groupname, :TEXT
  persist_attr_accessor :description, :TEXT
  persist_attr :tombstone, :INTEGER
  unique_attrs :groupname
  order_by_attr :groupname, :DESC
  attr_reader :id

  def before_save
    @tombstone = Time.new.to_i
  end

  def tombstone
    Time.at @tombstone
  end

  def before_delete
    self.each_GroupUserRelation {|gur| gur.delete }
  end

  def self.load_by_group(groupname)
    obj = nil
    each_with(:groupname, groupname) {|x| obj = x}
    obj
  end

  alias_method :name, :groupname
  alias_method :name=, :groupname=

end

class GroupUserRelation
 include SQLiteORM
 relate_model GroupAccount, :manyToOne
 relate_model UserAccount, :manyToOne
end