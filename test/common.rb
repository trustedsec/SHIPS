require 'usa'
require_relative '../lib/identsqlite'

WEBrick::USA::Auth::ACL.super_user = WEBrick::USA::User::Identity.new_of_type('IdentSQLite').impersonate('1', 'testuser')
WEBrick::USA::Auth::ACL.authors_ident_type = WEBrick::USA::User::Identity.get_type('IdentSQLite')
WEBrick::USA::Auth::ACL.authors_group = WEBrick::USA::User::Group.new('TestGroup', '1')
