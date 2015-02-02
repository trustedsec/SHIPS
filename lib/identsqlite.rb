require_relative 'sqliteorm'
require 'digest'
require 'base64'

#Simple class to do logins based on database records
#does not implement group membership functions

class IdentSQLite < WEBrick::USA::User::Identity
  attr_reader :password, :salt
  
  include SQLiteORM
  
  def initialize(optional=nil)
    super
    @optional = nil #Don't wan't any
    @id = nil
    @password = nil
    @salt = nil
  end
  
  def username=(v)
    char_cnt = 0
    ['/', '[', ']', "\"", ':', ';', '|', '<', '>', '+', '=', ',', '?', '*', ' ', '_', '&', '(', ')', "\0"].each { |c| char_cnt += v.count(c) }
    raise ArgumentError, 'User names cannot contain special characters.' unless char_cnt == 0
    @id = v.downcase
  end
  
  def username
    @id
  end
  
  def password=(v)
    sha2 = Digest::SHA2.new(bitlen = 256)
    sha2 << v
    @salt = rand(2147483647).to_s
    sha2 << @salt
    @password = Base64.strict_encode64(sha2.digest) 
  end
  
  def login(form_data)
    #binding.pry
    user = form_data['username'].force_encoding('UTF-8')
    pass = form_data['password'].force_encoding('UTF-8')
    raise RuntimeError, 'Bad Credentials' unless load(user)
    sha2 = Digest::SHA2.new(bitlen = 256)
    sha2 << pass
    sha2 << @salt.to_s
    raise RuntimeError, 'Bad Credentials' unless Base64.strict_encode64(sha2.digest) == @password
    @usertoken = @id
    true
    rescue => e
    @usertoken = nil 
    return false
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
       <td><input class="PasswordIn" maxlength=255 name="password" type="password"></td>
       </tr> 
       </tbody></table>
WWWFORM
  end
                                                  
end
