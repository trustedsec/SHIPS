require 'erb'

class ServletAdmin < WEBrick::USA::SessionServlet
  
  def initialize(server, smgr, login, template)
    @template = template
    super(server, smgr, login)
  end
  
  def handle_GET(request, response, session)
    superuser = WEBrick::USA::Auth::ACL.is_super?(session.identity)
    #Setup variables for the renderer
    computer = session.variables['computer'].name if session.variables['computer']
    response['Content-Type'] = 'text/html'
    #produce the content with the current variable bindings
    response.body = html_container('Computer Password Service',@template.result(binding))
  end
  
  def handle_POST(request, response, session)
    superuser = WEBrick::USA::Auth::ACL.is_super?(session.identity)
    request.query.each { |k,v| v.force_encoding('UTF-8') }
    case
    when request.query['New']
      raise SecurityError, 'Only the super user can insert computers into the database' unless superuser
      session.variables['computer'] = Computer.new
      session.variables['computer'].name = request.query['computer']
      session.variables['computer'].password = nil
      session.variables['computer'].nonce = '0' #special wildcard value
      session.variables['message'] = 'New Computer, click Save to add to the database'
    when request.query['Lookup']
      session.variables['computer'] = Computer.new.load(request.query['computer']) || nil
      Syslog.notice("#{ session.identity.username } retrieved passwords for #{ request.query['computer'] }") if Syslog.opened?
    when request.query['Delete']
      raise SecurityError, 'Only the super user can delete computer from the database' unless superuser
      raise ArgumentError, 'Must lookup computer first / no active computer in session' unless session.variables['computer']
      session.variables['computer'].delete
      session.variables['computer'] = nil
      session.variables['message'] = 'Computer object deleted' 
      Syslog.notice("#{ session.identity.username } deleted the computer #{ session.variables['computer'].name } and its passwords") if Syslog.opened?
    when request.query['Save']
      raise ArgumentError, 'Must lookup computer first / no active computer in session' unless session.variables['computer']
      unless session.variables['computer'].password === request.query['password0']
        session.variables['computer'].password = request.query['password0']
      end
      session.variables['computer'].save
      session.variables['message'] = 'Computer object saved'
      Syslog.notice("#{ session.identity.username } modified the computer #{ session.variables['computer'].name }") if Syslog.opened?
    when request.query['Clear']
      raise ArgumentError, 'Must lookup computer first / no active computer in session' unless session.variables['computer']
      session.variables['computer'].nonce = '0'
      session.variables['computer'].save
      session.variables['message'] = 'Computer nonce/check value cleared!'
      Syslog.notice("#{ session.identity.username } cleared nonce value for #{ session.variables['computer'].name }") if Syslog.opened?
    end
    #Treat as get
    handle_GET(request, response, session)
  end
  
end
