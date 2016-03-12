require 'SQLiteORM'
require 'openssl'
require 'base64'
require 'time'

module Document_Model_Common

  def before_save
    @ACL ||= nil
    @Folder ||= nil
    @name ||= nil
    raise StandardError, "#{ self.class.name } does not have a ACL set" unless @ACL
    raise StandardError, "#{ self.class.name } does not have an Folder set" unless @Folder
    raise StandardError, "#{ self.class.name } does not have a value for name set" unless @name
    @tombstone = Time.new.to_i
  end

  def tombstone
    Time.at @tombstone
  end

end

class Document
  @@PLAIN_DOCUMENT = 0
  @@SECURE_DOCUMENT = 1

  include SQLiteORM
  persist_attr_accessor :name
  order_by_attr :name, :DESC
  persist_attr :doctype, :INTEGER
  persist_attr :tombstone, :INTEGER
  persist_attr :nonce, :INTEGER
  persist_attr :device, :INTEGER
  relate_model WEBrick::USA::Auth::ACL, :manyToOne

  include Document_Model_Common

  attr_accessor :username
  attr_accessor :password
  attr_reader :password1
  attr_reader :password2
  attr_reader :password3
  attr_accessor :description
  attr_accessor :notes
  attr_accessor :url
  attr_reader :expiretime
  attr_reader :id

  def clear!
    @username = ''
    @password = ''
    @password1 = ''
    @password2 = ''
    @password3 = ''
    @description = ''
    @notes = ''
    @url = ''
    @expiretime = Time.new.to_i.to_s
  end

  def device?
    return true if @device
    false
  end

  def device!
    @device = 1
    @nonce = nil
  end

  def nonce?(v)
    return true if (@nonce ||= nil).nil?
    return true if @nonce == v.to_i
    false
  end

  def nonce!
    #2147483647 is allowed and 0 is reserved
    @nonce = (1 + SecureRandom.random_number(2147483646))
  end

  def reset!
    @nonce = nil
  end

  def open_document(identity=nil)
    if @doctype == @@PLAIN_DOCUMENT
      body = DocumentBody.load_by_Document self
    elsif @doctype == @@SECURE_DOCUMENT
      raise ArgumentError, 'Identity required to open secure document' if identity.nil?
      body = DocumentBody.load_by_Document self, PubKey.load_by_identity(identity)
    elsif @doctype.nil? #Might be if someone tries ot open the body on a new document
      return nil
    else
      raise RuntimeError, 'Unknown Document type encountered data error?'
    end
    @open = true
    return nil unless body
    @username = body.username
    @password = body.password
    @password1 = body.password1
    @password2 = body.password2
    @password3 = body.password3
    @description = body.description
    @expiretime = body.expiretime
    @notes = body.notes
    @url = body.url
    body = nil
  end

  def type
    @doctype ||= @@PLAIN_DOCUMENT
    if @doctype == @@PLAIN_DOCUMENT
      :plain
    elsif @doctype == @@SECURE_DOCUMENT
      :secure
    else
      nil
    end
  end

  def type=(v)
    if v == :plain
      @doctype = @@PLAIN_DOCUMENT
    elsif v == :secure
      @doctype = @@SECURE_DOCUMENT
    else
      raise ArgumentError, 'Expected :plain or :secure document type'
    end
  end

  def expiretime=(t)
    #Store these times as a string representation of timestamp int
    if t.kind_of? Time
      @expiretime = t.to_i.to_s
    elsif t.kind_of? String
      @expiretime = Time.parse(t).to_i.to_s
    elsif t.kind_of? Integer
      @expiretime = t.to_s
    end
  rescue ArgumentError
    @expiretime = 0.to_s
  end

  def after_save
    if @doctype == @@PLAIN_DOCUMENT
      DocumentBody.each_with_ex([[:PubKey, nil, :present],[:Document, self, :equal]]) {|x| x.delete} #corner case converting to a plain document.
      body = DocumentBody.load_by_Document self
      body = self.new_DocumentBody unless body #Create a new body if one does not exist
      save_child body
      body.save
    elsif @doctype == @@SECURE_DOCUMENT
      DocumentBody.each_with_ex([[:PubKey, nil, :null],[:Document, self, :equal]]) {|x| x.delete} #corner case converting from a plain document.
      self.ACL.readers.each do |reader|
        if key = PubKey.load_by_identity(reader)
          body = DocumentBody.load_by_Document self, key
          unless body #create a new document body and associate the readers pubkey
            body = self.new_DocumentBody
            body.PubKey = key
          end
          save_child_secure body, key
        end
      end
    else
      raise RuntimeError, 'Unknown Document type encountered data error?'
    end
  end

  def rekey(identity)
    #light weight save that assumes the content of a secure document isn't changing
    #but needs to be rewritten with a new public key
    raise ArgumentError, 'may only be used on a secure document' unless @doctype == @@SECURE_DOCUMENT
    key = PubKey.load_by_identity(identity)
    body = DocumentBody.load_by_Document self, key
    save_child_secure body, key
    body.save
  end

  def save_child(body)
    body.username = @username
    body.password = @password
    body.description = @description
    body.expiretime = @expiretime
    body.notes = @notes
    body.url = @url
  end

  def save_child_secure(body, key)
    body.username = key.cipher @username
    body.password = key.cipher @password
    body.description = key.cipher @description
    body.expiretime = key.cipher @expiretime
    body.notes = key.cipher @notes
    body.url = key.cipher @url
    body.save
  end

  private

  def before_delete
    self.each_DocumentBody { |d| d.delete }
  end
end

class Folder
  include SQLiteORM
  persist_attr_accessor :name, :TEXT
  persist_attr :tombstone, :INTEGER
  persist_attr_accessor :description
  order_by_attr :name, :DESC
  relate_model self, :manyToOne #Folder can have parents
  relate_model Document, :oneToMany
  relate_model WEBrick::USA::Auth::ACL, :manyToOne
  attr_reader :id

  include Document_Model_Common

  def before_delete
    cnt = 0
    self.class.related.map {|x| x[0]}.uniq.each do |relation|
      cnt += relation.count_with :Folder, self if relation.new.respond_to? :Folder=
    end
    raise StandardError, "Unable to delete this #{ self.class.name } it is in use by #{ cnt.to_s } other objects." unless cnt == 0
  end

  def textPath
    getpath(self.parent_Folder)
  end

  #overide the default related_new Folder to inherit ACLs too
  def new_Folder
    f = Folder.new
    f.instance_variable_set(:@ACL, @ACL) #ugly
    f.instance_variable_set(:@Folder, @id) #ugly
    f
  end

  #ditto for Documents
  def new_Document
    d = Document.new
    d.instance_variable_set(:@ACL, @ACL) #ugly
    d.instance_variable_set(:@Folder, @id) #ugly
    d
  end

  private
  def getpath(fld)
    return '' if fld.parent_Folder == fld
    getpath(fld.parent_Folder) + '/' + fld.name
  end
end

class PubKey
  @@KEY_SIZE = 4096

  include SQLiteORM
  persist_attr_accessor :usertoken, :TEXT
  persist_attr_accessor :identtype, :TEXT
  persist_attr_reader :pubkey, :BLOB
  unique_attrs :usertoken, :identtype

  def self.load_by_identity(identity)
    key = nil
    self.each_with_ex([[:usertoken, identity.usertoken],[:identtype, identity.class.name]]) do |storedkey|
      key = storedkey
    end
    key
  end

  def pubkey=(v)
    @key = OpenSSL::PKey::RSA.new v #raise an e
    @pubkey = v
  rescue OpenSSL::PKey::RSAError
    raise ArgumentError, 'expected asn1 public key'
  end

  def after_load
    @key = OpenSSL::PKey::RSA.new @pubkey
  end

  def identity=(v)
    @usertoken = v.usertoken
    @identtype = v.class.name
  end

  def identity
    @usertoken ||= nil
    @identtype ||= 'WEBrick::USA::User::Identity'
    WEBrick::USA::User::Identity.get_type(@identtype).new.impersonate @usertoken
  end

  def generate_key
    private_key = OpenSSL::PKey::RSA.new @@KEY_SIZE
    @key = private_key.public_key
    @pubkey = @key.to_pem
    private_key
  end

  def cipher(text)
    enc_text = Base64.strict_encode64(text.to_s)
    raise ArgumentError, "Message \"#{ text }\" (#{enc_text.bytesize} encoded bytes) to long for #{ @@KEY_SIZE.to_s } keysize." if ((@@KEY_SIZE - 11) < enc_text.bytesize)
    Base64.strict_encode64(@key.public_encrypt(enc_text))
  end
end

class DocumentBody
  include SQLiteORM
  persist_attr_accessor :username, :TEXT
  persist_attr_reader :password, :TEXT
  persist_attr_accessor :password1, :TEXT
  persist_attr_accessor :password2, :TEXT
  persist_attr_accessor :password3, :TEXT
  persist_attr_accessor :description, :TEXT
  persist_attr_accessor :notes, :BLOB
  persist_attr_accessor :url, :TEXT
  persist_attr_accessor :expiretime, :TEXT
  persist_attr_reader :rekeyCnt, :INTEGER
  relate_model Document, :manyToOne
  relate_model PubKey, :manyToOne
  unique_attrs :Document, :PubKey

  def rekeyCnt!
    @rekeyCnt = 1 + @rekeyCnt.to_i
  end

  def password=(v)
    @password3 = @password2
    @password2 = @password1
    @password1 = @password
    @password = v
  end

  def password!(v)
    @password = v
  end

  def self.load_by_Document(document, pkey=nil)
    doc = nil
    self.each_with_ex([[:Document, document],[:PubKey, pkey]]) do |storeddoc|
      doc = storeddoc
    end
    doc
  end

end

#Add and an index
class Document
  unique_attrs :Folder, :name, :device
end

