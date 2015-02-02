require 'base64'
require 'time'
require 'securerandom'
require_relative 'sqliteorm'

class Computer
  @@password_length = 20
  @@password_age = 10
  attr_reader :password, :tombstone, :password1, :password2, :password3, :id

  include SQLiteORM 
  alias_method :dcload, :load

  def load(v)
    dcload(v) if v.nil?
    dcload(v.downcase) unless v.nil?
  end
  
  def self.password_length=(v)
    @@password_length = v
  end
  
  def self.password_age=(v)
    @@password_age = v
  end
  
  def initialize
    @id = nil
    @nonce = '0'
    @tombstone = Time.new.to_s
    @password = nil
    @password1 = nil
    @password2 = nil
    @password3 = nil
  end
  
  def id=(v)
    raise ArgumentError, 'Must provide value for computer name' unless v
    raise ArgumentError, 'Computer names are limited to 15 characters' unless v.length < 16
    char_cnt = 0
    ['/', '[', ']', "\"", ':', ';', '|', '<', '>', '+', '=', ',', '?', '*', ' ', '_', '&', "\0"].each { |c| char_cnt += v.count(c) }
    raise ArgumentError, 'Computer name contains illegal characters' if char_cnt > 0
    @id = v.downcase
  end
  
  def expire_time
    #Adds 7 hours of fuzziness to the expiry
    #so every machines does not try to reset at the same time
    t = Time.parse(@tombstone.to_s) + (3600 * 24 * @@password_age) + (rand(8) * 3600) 
    t.strftime("%F %T")
  end
  
  def ==(v)
    @id == v.id
  end
  
  def enc_password()
    Base64.strict_encode64(@password)
  end
  
  def enc_password1()
   Base64.strict_encode64(@password1)
  end
    
  def enc_password2()
   Base64.strict_encode64(@password2)
  end
  
  def enc_password3()
   Base64.strict_encode64(@password3)
  end
  
  def enc_password=(v)
    self.password = Base64.strict_decode64(v)
  end
  
  def nonce
    @nonce.to_s #might come from the db as INTEGER 
  end
  
  def nonce=(v)
    #2147483647 is allowed and 0 is reserved
    v = (1 + SecureRandom.random_number(2147483646)).to_s if v.nil?
    @nonce = v
    @nonce
  end
  
  def to_array
    [@id, @nonce, @tombstone, @password]
  end
  	
  def tombstone=(v)
    v = Time.new.to_s if v.nil?
   @tombstone = v
   @tombstone
  end
  
  def password=(v)
    v = generate_password if v.nil?
    raise ArgumentError, 'Password exceeds the maximum allowed length (255)' if v.length > 255
    self.password1 = @password #store the old value
    @password = v
    @tombstone = Time.new.to_s
    @password
  end 
  
  alias_method :name, :id
  alias_method :name=, :id=
  alias_method :nouonce, :nonce
  alias_method :nouonce=, :nonce= 
  
private 

  def password1=(v)
    self.password2 = @password1
    @password1 = v
  end
  
  def password2=(v)
    self.password3 = @password2
    @password2 = v
  end
  
  def password3=(v)
    @password3 = v
  end
   
  def generate_password
  #generates password with complexity 3 of upper/lower/number/special 
    complex = 0
    pwd = nil
    while complex < 3 do
      complex = 0
      newpwd = Array.new(@@password_length) { SecureRandom.random_number(94) + 32 } #array of printing chars
      complex = complex + 1 if newpwd.index { |a| (65..90).include? a } #upper
      complex = complex + 1 if newpwd.index { |a| (97..122).include? a } #lower
      complex = complex + 1 if newpwd.index { |a| (48..57).include? a } #number
      complex = complex + 1 if newpwd.index { |a| ((32..47).include? a) or #specials
                      				  ((58..64).include? a) or 
                      				  ((91..96).include? a) or
                      				  ((123..126).include? a) }
     pwd = newpwd.map { |a| a.chr }.join
     complex = 0 unless pwd.length == pwd.squeeze.length                  				   
    end
    pwd
  end
end
