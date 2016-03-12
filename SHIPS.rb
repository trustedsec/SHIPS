#!/usr/bin/ruby
require 'time'
require_relative 'lib/configuration'
require 'SQLiteORM'
require_relative 'lib/directory_models'
require_relative 'lib/acl'
require_relative 'lib/document_models'
require_relative 'lib/servlets/login'
require_relative 'lib/servlets/managemykey'
require_relative 'lib/servlets/privkeydownload'
require_relative 'lib/servlets/folder'
require_relative 'lib/servlets/acl'
require_relative 'lib/servlets/ace'
require_relative 'lib/servlets/document'
require_relative 'lib/servlets/selecthelper'
require_relative 'lib/privkey'
require_relative 'lib/contrib/pool'
require_relative 'lib/servlets/rekey'
require_relative 'lib/identdevice'
require_relative 'lib/devicevalidator'
require_relative 'lib/devicevalidatorany'
require_relative 'lib/servlets/password'
require_relative 'lib/servlets/devicews'
require_relative 'lib/servlets/identsqlitechangepw'
require 'usa'
require 'webrick/https'

application_dir = File.expand_path(File.dirname(__FILE__))

begin

  #Read startup and configuration data
  settings = Configuration.new(ARGV[0] || application_dir + '/etc/conf')

  #daemonize
  unless settings['app','foreground', false]
    WEBrick::Daemon.start
    Dir.chdir application_dir #restore working directory
  end

  #Open key files
  database = SQLite3::Database.new(settings['data','dataPath',application_dir + '/var/data/SHIPS.sqlite'])
  database.busy_timeout = 500
  style_sheet = File.open(settings['data', 'styleSheet', application_dir + '/etc/style.css']).read
  weblog = File.open(settings['web','Log', application_dir + '/var/log/http.log'], 'a+')

  #bind the models to the application database
  database_lock = Mutex.new
  ObjectSpace.each_object(Class).select {|klass| klass < SQLiteORM }.each do |model|
    model.database = database
    model.lock = database_lock
  end

  #Parse Critical Web server Config sections
  webrick_options = Hash.new
  webrick_options[:Port] = settings['web','port', 443]
  webrick_options[:AccessLog] = [[weblog, WEBrick::AccessLog::COMBINED_LOG_FORMAT]]
  webrick_options[:SSLEnable] = true
  webrick_options[:SSLCertificate] = OpenSSL::X509::Certificate.new(File.open(settings['web','SSLCertificate', application_dir + '/etc/ssl.pem']).read)
  webrick_options[:SSLPrivateKey] = OpenSSL::PKey::RSA.new(File.open(settings['web','SSLPrivateKey', application_dir + '/etc/ssl.key']).read)
  webrick_options[:ServerSoftware] = "SHIPS/2.0 on Ruby/#{RUBY_VERSION}"
  webrick_options[:MaxClients] = settings['web','maxclients', 100]

  unless settings['app', 'syslog', false]
    #Share the access log for application log events
    webrick_options[:Logger] = WEBrick::Log::new(weblog)
  else
    require 'syslog/logger'
    webrick_options[:Logger] = Syslog::Logger.new 'SHIPS/2.0'
  end

  #Create a worker thread for long jobs
  Pool.instance 1

  #Start the server (bind ports etc)
  server = WEBrick::HTTPServer.new(webrick_options)
  webrick_options = nil
  #Switch User
  WEBrick::Utils.su settings['web','daemonUser', 'httpd'] unless 'nil' == settings['web','daemonUser', 'nil']

  #Setup the framework
  usa_options = Hash.new
  usa_options[:HTTPServer] = server #instance of HTTPServer to use
  usa_options[:serverName] = settings['web', 'serverName', WEBrick::Utils::getservername]
  usa_options[:styleSheet] = style_sheet #CSS text
  usa_options[:identityOptions] = settings['identityOptions'] #Options to pass to the Identity class instances when invoked from /login
  WEBrick::USA::initialize_usa(usa_options.merge settings['app'])
  usa_options = nil

  #setup validator options
  DeviceValidator.options = settings['validatorOptions']

  #Mount special servlets
  server.mount('/', ServletLogin,
               settings['app', 'allowedLoginIdents'].map { |i| WEBrick::USA::User::Identity.get_type(i) },
               settings['app', 'defaultLoginIdent'],
               ERB.new(File.open(application_dir + '/lib/views/login.erb').read, 0, '%<>'),
               '/client')

  server.mount('/password', ServletPassword, settings['devices', 'length', 10], settings['devices', 'age', 5])
  server.mount('/devicews', ServletDeviceWS, settings['app', 'allowedLoginIdents'], settings['app', 'defaultLoginIdent'])

  #Mount servlets
  server.mount_session_servlet '/assets/js/asn1', WEBrick::USA::AssetServlet, File.read(application_dir + '/lib/contrib/pidcrypt/asn1.js'), 'text/javascript'
  server.mount_session_servlet '/assets/js/jsbn', WEBrick::USA::AssetServlet, File.read(application_dir + '/lib/contrib/pidcrypt/jsbn.js'), 'text/javascript'
  server.mount_session_servlet '/assets/js/pidcrypt', WEBrick::USA::AssetServlet, File.read(application_dir + '/lib/contrib/pidcrypt/pidcrypt.js'), 'text/javascript'
  server.mount_session_servlet '/assets/js/pidcrypt_util', WEBrick::USA::AssetServlet, File.read(application_dir + '/lib/contrib/pidcrypt/pidcrypt_util.js'), 'text/javascript'
  server.mount_session_servlet '/assets/js/rsa', WEBrick::USA::AssetServlet, File.read(application_dir + '/lib/contrib/pidcrypt/rsa.js'), 'text/javascript'
  server.mount_session_servlet '/assets/js/string_extend', WEBrick::USA::AssetServlet, File.read(application_dir + '/lib/contrib/pidcrypt/string_extend.js'), 'text/javascript'
  server.mount_session_servlet '/assets/js/certparser', WEBrick::USA::AssetServlet, File.read(application_dir + '/lib/contrib/pidcrypt/certparser.js'), 'text/javascript'
  server.mount_session_servlet '/assets/js/prng4', WEBrick::USA::AssetServlet, File.read(application_dir + '/lib/contrib/pidcrypt/prng4.js'), 'text/javascript'
  server.mount_session_servlet '/assets/js/rng', WEBrick::USA::AssetServlet, File.read(application_dir + '/lib/contrib/pidcrypt/rng.js'), 'text/javascript'
  server.mount_session_servlet '/assets/img/logo', WEBrick::USA::AssetServlet, File.read(application_dir + '/etc/assets/logo.gif'), 'image/gif'
  server.mount_session_servlet '/assets/img/folder', WEBrick::USA::AssetServlet, File.read(application_dir + '/etc/assets/folder.gif'), 'image/gif'
  server.mount_session_servlet '/assets/img/document', WEBrick::USA::AssetServlet, File.read(application_dir + '/etc/assets/document.gif'), 'image/gif'

  #Mount session servlets
  server.mount_session_servlet '/test', WEBrick::USA::SessionServlet
  server.mount_session_servlet '/selecthelper', ServletSelectHelper
  server.mount_session_servlet '/client', WEBrick::USA::ERBSessionServlet, ERB.new(File.open(application_dir + '/lib/views/client.erb').read, 0, '%<>')
  server.mount_session_servlet '/welcome', WEBrick::USA::ERBSessionServlet, ERB.new(File.open(application_dir + '/lib/views/welcome.erb').read, 0, '%<>')
  server.mount_session_servlet '/managemykey', ServletManageMyKey, ERB.new(File.open(application_dir + '/lib/views/managemykey.erb').read, 0, '%<>')
  server.mount_session_servlet '/folder', ServletFolder, ERB.new(File.open(application_dir + '/lib/views/folder.erb').read, 0, '%<>')
  server.mount_session_servlet '/SHIPS_Private_Key', ServletPrivKeyDownload
  server.mount_session_servlet '/acl', ServletACL, ERB.new(File.open(application_dir + '/lib/views/acl.erb').read, 0, '%<>')
  server.mount_session_servlet '/ace', ServletACE, ERB.new(File.open(application_dir + '/lib/views/ace.erb').read, 0, '%<>')
  server.mount_session_servlet '/acls', WEBrick::USA::ERBSessionServlet, ERB.new(File.open(application_dir + '/lib/views/acls.erb').read, 0, '%<>')
  server.mount_session_servlet '/document', ServletDocument, ERB.new(File.open(application_dir + '/lib/views/document.erb').read, 0, '%<>')
  server.mount_session_servlet '/rekey', ServletReKey, ERB.new(File.open(application_dir + '/lib/views/rekey.erb').read, 0, '%<>')
  server.mount_session_servlet '/identsqlitechangepw', ServletIdentSQLiteChangePW, ERB.new(File.open(application_dir + '/lib/views/identsqlitechangepw.erb').read, 0, '%<>')

  #populate some database objects if none exist
  #must have at least one ACL
  if WEBrick::USA::Auth::ACL.count == 0
    acl = WEBrick::USA::Auth::ACL.new(WEBrick::USA::Auth::ACL.super_user)
    acl.name = 'Super User Read Write'
    acl.description = 'Initial ACL created by system'
    ace = WEBrick::USA::Auth::ACE.new
    ace.identity = WEBrick::USA::Auth::ACL.super_user
    ace.read = true
    ace.write = true
    acl.add_ace ace
    acl.save
  #need one special folder with itself as its own parent

    folder = Folder.new
    folder.name = '.'
    folder.description = 'Root folder created by system'
    folder.instance_variable_set(:@Folder, 1) #Special case root folder
    folder.ACL = acl
    folder.save
  elsif Folder.count == 0
    raise StandardError, 'SHIPS database document structure problem'
  end

rescue StandardError => e
  puts 'Encountered a fatal startup error!'
  puts "#{e.message} - #{e.backtrace[0]}"
  Kernel.exit! false
end

#Make it easy to stop the program with [ctrl]-[c]
trap('INT') { server.shutdown }
#Be nice to init scripts
trap('TERM') { server.shutdown }
#log rotate friendliness
trap('HUP') do
  weblog.flush
  weblog.reopen(settings['web','Log', application_dir + '/var/log/http.log'], 'a+')
end

#start the server
server.start

#Will run when server.start returns on server.shutdown event
Pool.shutdown
database.close
begin #give SQLite time to tidy up, and webrick at least one second
  sleep 1
end until database.closed?


