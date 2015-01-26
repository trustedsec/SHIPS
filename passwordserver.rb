#!/usr/bin/ruby
require 'webrick'
require 'webrick/https'
require 'uri'
require 'yaml'
require 'erb'

require 'usa'
require 'usa/identetc' if /linux/ =~ RUBY_PLATFORM

require_relative 'lib/identsqlite'
require_relative 'lib/computer'
require_relative 'lib/configuration'
require_relative 'lib/computervalidator'
require_relative 'lib/validateany'
require_relative 'lib/servletdocument.rb'

#Load builtin LDAP validator and ident, or not
begin
  require 'ldap'
  ldapPresent = true
rescue LoadError
  puts "Ruby-Ldap not installed starting without LDAP support."
  ldapPresent = false
end
require_relative 'lib/validateldap.rb' if ldapPresent
require_relative 'lib/identldap.rb' if ldapPresent

#servlets
require_relative 'lib/servletpassword'
require_relative 'lib/servletadmin'
require_relative 'lib/servletexport'
require_relative 'lib/servletusers'
require_relative 'lib/servletadminws'
require_relative 'lib/servletlogin.rb'

application_dir = File.expand_path(File.dirname(__FILE__))
settings = Configuration.new(ARGV[0] || application_dir + '/etc/conf')

#Syslog is not present on all platforms load only if called for
if settings['app','syslog', false]
  require 'syslog'
else #monkey it up
  class Syslog
    def self.opened?
      false
    end
  end
end

def identClass(v)
  if WEBrick::USA::User::Identity.ident_types.map { |c| c.name }.include?(v)
    return eval(v)
  else
    raise RuntimeError, "#{v} does not name an identity class."
  end
end

#Setup some options for to pass to HTTPServer
weblog = File.open(settings['web','Log', application_dir + '/var/log/passwordserver.log'], 'a+')
webrick_options = Hash.new
webrick_options[:Port] = settings['web','port', 443]
webrick_options[:Logger] = WEBrick::Log::new(weblog)
webrick_options[:AccessLog] = [[weblog, WEBrick::AccessLog::COMBINED_LOG_FORMAT]] 
webrick_options[:SSLEnable] = true
webrick_options[:SSLCertificate] = OpenSSL::X509::Certificate.new(File.open(settings['web','SSLCertificate', application_dir + '/etc/ssl.pem']).read)
webrick_options[:SSLPrivateKey] = OpenSSL::PKey::RSA.new(File.open(settings['web','SSLPrivateKey', application_dir + '/etc/ssl.key']).read)

server = WEBrick::HTTPServer.new(webrick_options)
WEBrick::Utils.su settings['web','daemonUser','www'] #ports are bound switch user

#Setup some options to initialize the USA (Users Sessions Authentication) framework
usa_options = Hash.new
usa_options[:serverName] = settings['web', 'serverName', WEBrick::Utils::getservername]
usa_options[:directory] = WEBrick::USA::User::Directory #use the base directory class
usa_options[:sessionTimeout] = settings['web', 'sessionTimeout', 300] 
usa_options[:directoryOptions] = Hash.new #Any options you want to pass to the directory object
usa_options[:superUserIdent] = identClass(settings['app', 'owner_ident', 'IdentSQLite']) #Identity class const type ACL will treat as a super user
usa_options[:superUser] = settings['app', 'owner_uid', 'admin'] #Token ACL should treat as super user
usa_options[:aclAuthorsIdents] = WEBrick::USA::User::Identity #Identity class const that can call ACL.save
usa_options[:aclAuthorsGroup] = settings['app', 'ACL_gid', 'NotUsed398tufgsj'] #Grp token that can call ACL.save (not used)
usa_options[:styleSheet] = File.open(settings['app', 'styleSheet', application_dir + '/etc/style.css']).read #CSS text
usa_options[:allowedLoginIdents] = settings['app', 'login_idents', ['IdentSQLite']].map { |i| identClass(i) } #Acceptable Identity class consts for login
usa_options[:defaultLoginIdent] = identClass(settings['app', 'defaultIdent', 'IdentSQLite'])  #What do use if "method" is not specified to /login
usa_options[:identOptions] = settings['moduleOptions'] #Options to pass to the Identity class instances when invoked from /login
usa_options[:HTTPServer] = server #instance of HTTPServer to use

sessionManager, directory = WEBrick::USA::initialize_usa(usa_options) #Start the framework

#Prepare templates for some servlets
erbAdmin = ERB.new(File.open(application_dir + '/lib/admin.erb').read, 0, "%<>")
erbUsers = ERB.new(File.open(application_dir + '/lib/users.erb').read, 0, "%<>")
erbAdminWS = ERB.new(File.open(application_dir + '/lib/adminws.erb').read, 0, "%<>")
erbLogin = ERB.new(File.open(application_dir + '/lib/login.erb').read, 0, "%<>")
logogif = File.open(settings['app', 'logoGIF', application_dir + '/etc/logo.gif']).read

#Before opening files and creating child threads
WEBrick::Daemon.start unless settings['app','forground', false]

#Setup Syslog
Syslog.open('PasswordServer', Syslog::LOG_CONS | Syslog::LOG_PID, Syslog::LOG_DAEMON | Syslog::LOG_AUTHPRIV) if settings['app','syslog',false]

begin
#Setup database
if File.exists? settings['app','datapath',application_dir + '/var/data/passwordserver.sqlite']
  databaseConnection = SQLite3::Database.new(settings['app','datapath',application_dir + '/var/data/passwordserver.sqlite'])
else
  databaseConnection = SQLite3::Database.new(settings['app','datapath',application_dir + '/var/data/passwordserver.sqlite'])
  databaseConnection.execute(File.open(application_dir + '/lib/sql/computer.sql').read,[])
  databaseConnection.execute(File.open(application_dir + '/lib/sql/identsqlite.sql').read,[])
  databaseConnection.execute(File.open(application_dir + '/lib/sql/identsqlite_user.sql').read,[])
end
Computer.db_connection = databaseConnection
IdentSQLite.db_connection = databaseConnection

#Other Computer properties
Computer.password_age = settings['rules', 'age', 10]
Computer.password_length = settings['rules', 'length', 20]

#Setup computer lookup sources
validators = ComputerValidator.createObjects(settings['moduleOptions']).select { |v| settings['app', 'ComputerValidators', []].include? v.class.name }

#Application session sevlets
server.mount('/test', WEBrick::USA::SessionServlet, sessionManager, identClass(settings['app', 'defaultIdent', 'IdentSQLite']))
server.mount('/admin', ServletAdmin, sessionManager, identClass(settings['app', 'defaultIdent', 'IdentSQLite']), erbAdmin)
server.mount('/export', ServletExport, sessionManager, identClass(settings['app', 'defaultIdent', 'IdentSQLite']))
server.mount('/users', ServletUsers, sessionManager, identClass(settings['app', 'defaultIdent', 'IdentSQLite']),
	settings['app', 'login_idents', ['IdentSQLite']].include?('IdentSQLite'), erbUsers)

#Webservice servlets
server.mount('/password', ServletPassword, validators)
server.mount('/adminws', ServletAdminWS, settings['app', 'login_idents', ['IdentSQLite']].map { |i| identClass(i) },
	identClass(settings['app', 'defaultIdent', 'IdentSQLite']), erbAdminWS, settings['moduleOptions'])

#other sessionless servlets
server.mount('/logo.gif', ServletDocument, 'image/gif', logogif) 
server.mount('/', ServletLogin, settings['app', 'login_idents', ['IdentSQLite']].map { |i| identClass(i) },
        identClass(settings['app', 'defaultIdent', 'IdentSQLite']), erbLogin)

rescue StandardError => e
  Syslog.crit("#{e.message} - #{e.backtrace}")  if Syslog.opened?
  puts "#{e.message} - #{e.backtrace}" if settings['app','forground', false]
  databaseConnection.close
  exit(1)
end

#Make it easy to stop the program with [ctrl]-[c]
trap("INT") { server.shutdown }
#Be nice to init scripts
trap("TERM") { server.shutdown }
#allow logrotate
trap("HUP") { weblog.reopen(settings['web','Log', application_dir + '/var/log/passwordserver.log'], 'a+') }

#start the web server; program is not listing until this call
server.start
#If the server stops exit clean
databaseConnection.close; sleep 5; exit(0)