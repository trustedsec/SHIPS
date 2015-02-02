require 'erb'

class ServletUsers < WEBrick::USA::SessionServlet
  
  def initialize(server, smgr, login, enabled, template)
    @template = template
    @enabled = enabled
    super(server, smgr, login)
  end
  
  def handle_GET(request, response, session)
    raise ArgumentError, 'Page not available for configured Ident methods' unless @enabled
    raise SecurityError, 'Only the superuser may access this page'  unless WEBrick::USA::Auth::ACL.is_super?(session.identity)
    request.query.each { |k,v| v.force_encoding('UTF-8') }
    
    #Setup variables for the renderer
    if session.variables['user'] = IdentSQLite.new.load(request.query['username'] || '')
      username = session.variables['user'].username
      submit = 'Save'
      delete = 'Delete'
    else
      session.variables['user'] = IdentSQLite.new
      username = 'New User'
      submit = 'New'
      delete = false
    end 
    response['Content-Type'] = 'text/html'
    #produce the content with the current variable bindings
    response.body = html_container('Computer Password Service',@template.result(binding))
    session.variables['message'] = ''
  end
  
  def handle_POST(request, response, session)
    request.query.each { |k,v| v.force_encoding('UTF-8') }
    raise SecurityError, 'Page not available for configured Ident methods' unless @enabled
    raise SecurityError, 'Only the superuser may access this page'  unless WEBrick::USA::Auth::ACL.is_super?(session.identity)
    raise ArgumentError, 'No user object in session' unless session.variables['user']
    if request.query['New']
      raise ArgumentError, 'The user account already exists' if IdentSQLite.new.load(request.query['username'])
      raise ArgumentError, 'Password may not be blank' unless request.query['password'].length > 0
      raise ArgumentError, 'Passwords do not match' unless request.query['password'] == request.query['confirm']
      session.variables['user'].username = request.query['username']
      session.variables['user'].password = request.query['password']
      session.variables['user'].save
      Syslog.notice("#{ session.identity.username } created the user #{ session.variables['user'].username }") if Syslog.opened?
    else 
      raise ArgumentError, 'Username does not match object in session, reopen user' unless session.variables['user'].username == request.query['username']    
      if request.query['Save']
        raise ArgumentError, 'Password may not be blank' unless request.query['password'].length > 0
        raise ArgumentError, 'Passwords do not match' unless request.query['password'] == request.query['confirm']
        session.variables['user'].password = request.query['password']
        session.variables['user'].save
        Syslog.notice("#{ session.identity.username } modified the user #{ session.variables['user'].username }") if Syslog.opened?
      elsif request.query['Delete']
        session.variables['user'].delete
        Syslog.notice("#{ session.identity.username } deleted the user #{ session.variables['user'].username }") if Syslog.opened?
        session.variables['user'] = nil
      end
    end
    session.variables['message'] = 'User updated'
    #Treat as get
    handle_GET(request, response, session)
  rescue ArgumentError => e
    session.variables['message'] = e.message
    handle_GET(request, response, session)  
  end
  
end
