#webservice for admin functions
#has to reimplement alot of logon function sadly
class ServletAdminWS < WEBrick::HTTPServlet::AbstractServlet
  @@RESPONCE_OK = "200"
  @@RESPONCE_REJECT = "500"
  @@RESPONCE_UNAUTH = "403"
  
  def initialize(server, idents, ident_default, template, optional=nil)
    @idents = idents
    @ident_default = ident_default
    @optional = optional
    @template = template
    super server
  end
  
  def html(str)
    "<!DOCTYPE html><html><head><meta charset=\"UTF-8\"></head><body>#{ str.to_s.html_esc }</body></html>"
  end
  
  def get_ident(method)
    ident = nil
    if method
      ident = @idents.select { |s| s.name == method }[0]
      raise SecurityError, 'Specified Ident method not permitted' unless ident
    else
      ident = @ident_default
    end    
    ident
  end
  
  def auth(method, form_data, optional)
    ident = get_ident(method)
    user = ident.new(optional)
    raise SecurityErorr, 'logon credientials invalid' unless user.login(form_data)
    return user
  end
  
  def exec_request(query, superuser)
    message = ''
    computer = Computer.new.load query['computer']
    case query['action']
    when 'lookup'
      message = computer ? 'true' : 'false'
    when 'new'
      raise SecurityError, 'only the super user can create a new computer' unless superuser
      raise ArgumentError, 'computer already exists' if computer
      computer = Computer.new
      computer.name = query['computer']
      computer.password = query['password0'] || nil
      computer.save
      message = 'true'
    when 'password'
      raise ArgumentError, 'computer not found' unless computer
      computer.password = query['password0']
      computer.save
      message = 'true'
    when 'delete' 
      raise SecurityError 'only the super user can delete computers' unless superuser
      computer.delete if computer
      message = 'true'
    when 'clear'
      raise ArgumentError, 'computer not found' unless computer
      computer.nonce = 0
      computer.save
      message = 'true'
    else
      raise ArgumentError, 'action is not valid'
    end
  end
  
  def do_GET(request, response)
    response['Content-Type'] = 'text/html'
    request.query.each { |k,v| v.force_encoding('UTF-8') }
    ident = get_ident(request.query['method'])
    response.status = @@RESPONCE_OK
    response.body = @template.result(binding)  
  rescue SecurityError => e
    response.status = @@RESPONCE_UNAUTH
    response.body = html(e.message)  
  rescue StandardError => e
    response.status = @@RESPONCE_REJECT 
    response.body = html("There was a problem processing this request") 
    Syslog.crit("#{ e.message } - #{ e.backtrace }") if Syslog.opened? 
  end
  
  def do_POST(request, response)
    response['Content-Type'] = 'text/html'
    request.query.each { |k,v| v.force_encoding('UTF-8') }
    ident = auth(request.query['method'], request.query, @optional)
    response.body = html(exec_request(request.query, WEBrick::USA::Auth::ACL.is_super?(ident)))
    response.status = @@RESPONCE_OK
  rescue SecurityError => e
    response.status = @@RESPONCE_UNAUTH
    response.body = html(e.message)  
  rescue StandardError => e
    response.status = @@RESPONCE_REJECT 
    response.body = html("There was a problem processing this request") 
    Syslog.crit("#{ e.message } - #{ e.backtrace }") if Syslog.opened?    
  end
end
