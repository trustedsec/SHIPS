#Does not implement group membership functions
#these are not needed, framework defaults will be adequate
#passwordserver only distinguishes between the superuser and users

#You will need to require these here if you plan to load 
#the ident class via the -r flag rather than modify passwordserver.rb
require 'webrick'
require 'usa'

class IdentSample < WEBrick::USA::User::Identity
  
  def login(form_data)
    if form_data['username'] == 'admin' and form_data['password'] = 'password'
      #@usertoken and @username must both be defined after a successful login
      #@usertoken need not be equal to username but could be, or it might be a
      #backend system value such as a uid or sid 
      #@usertoken should never be set to a non nil class value
      #unless the user is authenticated 
      @usertoken = 'admin'
      @username = 'admin'
      true
    else
      false
    end
  rescue => e
    @usertoken = nil 
    return false
  end
  
  def self.form_inner_html
  #HTML content to be used inside the form on the login page, any controls
  #here are passed back to login as the form_data hash
      <<WWWFORM
       <table><tbody>
       <tr>
       <td>User Name:</td>
       <td><input class="PlainTextIn" maxlength=50 name="username", type="text"></td>
       </tr>
       <tr>
       <td>Password:</td>
       <td><input class="PasswordIn" maxlength=255 name="password", type="password"></td>
       </tr> 
       </tbody></table>
WWWFORM
  end
                                                  
end
