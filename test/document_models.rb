#Enviornment setup
require_relative 'common'
require_relative '../lib/acl'
require_relative '../lib/document_models'

database = SQLite3::Database.new(':memory:')
database_lock = Mutex.new
ObjectSpace.each_object(Class).select {|klass| klass < SQLiteORM }.each do |model|
  model.database = database
  model.lock = database_lock
end

testUser = UserAccount.new
testUser.username = 'testuser'
testUser.password = 'P@$$w0rd'
testUser.save
testUser = nil

testGroup = GroupAccount.new
testGroup.name = 'TestGroup'
testGroup.description = 'testing'
testGroup.save

testUser = UserAccount.new
testUser.username = 'user1'
testUser.password = 'P@$$w0rd'
testUser.save


testGroup = GroupAccount.new
testGroup.name = 'Group1'
testGroup.description = 'testing1'
testGroup.save

membership = GroupUserRelation.new
membership.UserAccount = testUser
membership.GroupAccount = testGroup
membership.save

testUser = UserAccount.new
testUser.username = 'user2'
testUser.password = 'P@$$w0rd'
testUser.save

testGroup = GroupAccount.new
testGroup.name = 'Group2'
testGroup.description = 'testing2'
testGroup.save

membership = GroupUserRelation.new
membership.UserAccount = testUser
membership.GroupAccount = testGroup
membership.save

testuser = nil
testUser = IdentSQLite.new.login( {'username'=> 'testuser', 'password'=> 'P@$$w0rd'})

begin
#####Tests#########
key = PubKey.new
raise RuntimeError, 'Could not initialize PubKey' unless key.kind_of? PubKey

key.identity = testUser
raise RuntimeError, 'Key model identity' unless key.identity == testUser
key.generate_key
key.save

acl = WEBrick::USA::Auth::ACL.new testUser
raise RuntimeError, 'Could not initialize ACL' unless acl.kind_of? WEBrick::USA::Auth::ACL
acl.name = 'User1 reader ACL'
acl.description = 'User1 is allowed to read'

acl2 = WEBrick::USA::Auth::ACL.new IdentSQLite.new.login( {'username'=> 'user1', 'password'=> 'P@$$w0rd'})
begin
  acl2.name = 'User1 reader ACL'
  raise Exception, 'ACL Author Security'
rescue StandardError, SecurityError
  acl2 = nil
end

ace = WEBrick::USA::Auth::ACE.new
raise RuntimeError, 'Could not initialize ACE' unless ace.kind_of? WEBrick::USA::Auth::ACE

ace.identity = IdentSQLite.new.login( {'username'=> 'user1', 'password'=> 'P@$$w0rd'})
ace.read = true

unless ace.identity == IdentSQLite.new.login( {'username'=> 'user1', 'password'=> 'P@$$w0rd'})
    raise RuntimeError, 'ACE model identity'
end

acl.add_ace ace
raise RuntimeError, 'delete ace' unless ace == acl.del_ace(ace)

acl.add_ace ace
raise RuntimeError, 'acl super eval before save' unless acl.read?
acl.save
raise RuntimeError, 'acl super eval after save' unless acl.read?
acl.load
raise RuntimeError, 'acl super eval after load' unless acl.read?
acl = nil

acl = WEBrick::USA::Auth::ACL.new(IdentSQLite.new.login( {'username'=> 'user1', 'password'=> 'P@$$w0rd'})).load 1
raise RuntimeError, 'acl user eval after load' unless acl.read?

acl = WEBrick::USA::Auth::ACL.new(IdentSQLite.new.login( {'username'=> 'user2', 'password'=> 'P@$$w0rd'})).load 1
raise RuntimeError, 'acl false user eval after load' if acl.read?

raise RuntimeError, 'acl.readers' unless acl.readers.length == 2

#add group
acl = WEBrick::USA::Auth::ACL.new testUser
acl.name = 'Group2 can read'
acl.description = 'test user2 can read by group membership'
ace = WEBrick::USA::Auth::ACE.new
u2 = IdentSQLite.new.login( {'username'=> 'user2', 'password'=> 'P@$$w0rd'})
ace.identity = 'IdentSQLite'
ace.group = u2.get_groups[0]
ace.write = true
acl.add_ace ace
acl.save
acl = nil
ace.to_s
ace = nil
u2 = nil

acl = WEBrick::USA::Auth::ACL.new IdentSQLite.new.login( {'username'=> 'user2', 'password'=> 'P@$$w0rd'})
acl.load 2
raise RuntimeError, 'acl group eval after load' unless acl.write?

acl = nil
acl = WEBrick::USA::Auth::ACL.new IdentSQLite.new.login( {'username'=> 'user1', 'password'=> 'P@$$w0rd'})
acl.load 2
raise RuntimeError, 'acl negative group eval after load' if acl.write?

f1 = Folder.new
f1.name = '.'

f1.delete #test reference count logic

f1.ACL = acl

f1.instance_variable_set(:@Folder, 1) #Special case root folder
f1.save

f2 = f1.new_Folder
f2.name = 'Test Folder'

raise ArgumentError, 'folder acl patch' unless f2.ACL == f1.ACL

f2.save

begin
  f1.delete
  raise RuntimeError, 'Folder Reference counter delete'
rescue StandardError
  f1 = nil
end

doc = f2.new_Document
doc.name = 'Test Doc'
  doc.username = 'foo'
  doc.password = 'bar'
  doc.url = 'http://example.com'
  doc.type = :plain
  doc.save
  doc = nil

f3 = f2.new_Folder
f3.name = 'test fld #3'
f3.save
f4 = f3.new_Folder
f4.name = 'test fld #4'
raise StandardError, 'Folder model textPath' unless f4.textPath == '/Test Folder/test fld #3'

doc = Document.new.load(1)
raise RuntimeError, 'document acl inherit from folder' unless doc.ACL == f2.ACL

raise RuntimeError, 'Doc load' unless doc.name == 'Test Doc'
  doc.open_document
raise RuntimeError, 'Plain doc body load' unless doc.url == 'http://example.com'

doc = f2.new_Document
  doc.name = 'Secure test'
  doc.username = 'bar'
  doc.password = 'foo'
  doc.url = 'https://example.com'
  doc.type = :secure
  doc.save

  key = PubKey.new
  key.identity = IdentSQLite.new.login( {'username'=> 'user2', 'password'=> 'P@$$w0rd'} )
  key.generate_key
  key.save
  doc.save

raise RuntimeError, 'DocumentBody Keying' unless 1 == DocumentBody.count_with( :Document, doc)

  doc = nil

doc = Document.new.load 2
  doc.open_document testUser
  raise RuntimeError, 'Secure doc isnt' if doc.url == 'https://example.com'

#####End Tests#######
  puts 'Document models related tests completed without error'
rescue Exception => e
  puts "#{e.class.name} - #{e.message}"
  puts e.backtrace
end
