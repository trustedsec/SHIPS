require 'usa'
require_relative 'directory_models'
require_relative 'directorysqlite'

#Simple class to do logins based on database records
#does not implement group membership functions

class IdentSQLite < WEBrick::USA::User::Identity

  self.directory = DirectorySQLite

  def login(form_data)
    return false unless user_account = UserAccount.load_by_user(form_data['username'])
    return false unless user_account.password?(form_data['password'])
    @usertoken = user_account.id.to_s
    @username = user_account.username
    self
  rescue
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
                                                  
end
