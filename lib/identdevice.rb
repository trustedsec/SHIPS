require 'usa'
require_relative 'directory_models'

#A fake directory for device idents
class DirectoryDevice < WEBrick::USA::User::Directory
  def get_groups
    [WEBrick::USA::User::Group.new('devices', 'devices')]
  end

  def  get_idents_groups(identity)
  [WEBrick::USA::User::Group.new('devices', 'devices')]
  end

  def get_idents
    Array.new
  end

  alias_method :get_groups_by_name, :get_idents_groups
  alias_method :get_groups_by_token, :get_idents_groups

  def get_user_name(token)
    token
  end

  def members_of_group(group)
    [] #devices will never expand as ACL readers
  end

  def get_idents_by_name(name)
    [self.identity.new.impersonate(name, name)]
  end

  def get_ident_by_token(token)
    self.identity.new.impersonate(token, token)
  end
end

#Special identity class, used for devices to do password rotation
#Can be used for other AAA but not really recommended

#The basic principle is collect a devicename (document name), Folder:id and nonce value.
#if folder is not provided (legacy client) assume the default folder
#if a named document exists in folder and the nonce matches or stored nonce is 0 - authenticate true
#if the document does not exist, check the 'validators' for the device name assume stored nonce of 0 - authenticate true if a validator finds the device


class IdentDevice < WEBrick::USA::User::Identity

  #Because devices are weakly authenticated - additional loging here not necessarily present for other idents.
  #Its also needed to troubleshoot problems with device side scripts
  def login(form_data)
    doc = nil
    name = form_data['name']
    nonce = form_data['nonce'].to_i
    nonce = form_data['nouonce'].to_i if nonce == 0
    @folder = form_data['folder'].to_i
    @folder = @optional[:identDevice_default_folder] if @folder == 0

    unless name_valid?(name)
      @loginMessage = 'authentication failed not a legal host name'
      return false
    end

    Document.each_with_ex([[:device, nil, :present],[:name, name, :equal],[:Folder, @folder, :equal]]) {|x| doc = x}
    if doc
      unless doc.nonce? nonce
        @loginMessage = 'authentication failed bad nonce value'.gsub("\n", '\n')
        return false
      else
        @loginMessage = 'exists in database'
      end
      @document = doc
    else #try the validators
      valid = false
      (@optional[:identDevice_validators] ||= Array.new).each do |v|
        if DeviceValidator.new_of_type(v).lookup(name)
          @loginMessage = "found by #{v} new device".gsub("\n",'\n')
          valid = true
        end
      end
      unless valid
        @loginMessage = 'device could not be validated'
        return false
      end
    end

    @usertoken = name
    @username = name
    @document = doc
    self
  rescue
    @usertoken = nil
    @username = nil
    false
  end

  self.directory = DirectoryDevice

  def self.form_inner_html
    <<WWWFORM
       <table><tbody>
       <tr>
       <td>name:</td>
       <td><input class="PlainTextIn" maxlength=64 name="name" type="text"></td>
       </tr>
       <tr>
       <td>nonce:</td>
       <td><input class="PlainTextIn" maxlength=50 name="nonce" type="text"></td>
       </tr>
       <tr>
       <td>Folder Id:</td>
       <td><input class="PlainTextIn" maxlength=50 name="folder" type="text"></td>
       </tr>
       </tbody></table>
WWWFORM
  end

  def Document
    #As the associated document is really the only one that should be modifed it might be useful to hang onto it and make it available
    @document ||= nil
  end

  def loginMessage
    @loginMessage ||= ''
  end

  def Folder
    if @document
      @document.Folder
    else
      Folder.new.load(@folder)
    end
  end
  private

  def name_valid?(v)
    return false unless v
    return false unless v.length > 0
    return false unless v.length < 16 #15 chars is max host name length (at least of windows devices)
    char_cnt = 0
    ['/', '[', ']', "\"", ':', ';', '|', '<', '>', '+', '=', ',', '?', '*', ' ', '_', '&', "\0"].each { |c| char_cnt += v.count(c) }
    return false if char_cnt > 0
    true
  end

end