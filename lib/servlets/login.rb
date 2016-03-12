#This is just a tiny thing to essentially render an erb template
#needed because users of the logon page don't have a session yet
require 'erb'

class ServletLogin < WEBrick::HTTPServlet::AbstractServlet
  @@RESPONCE_OK = '200'

  def initialize(server, idents, ident_default, template, redirect_path)
    @idents = idents
    @ident_default = ident_default
    @template = template
    @redirect_path = redirect_path
    super server
  end

  def do_GET(request, response)
    response['X-Frame-Options'] = 'SAMEORIGIN'
    response['Content-Type'] = 'text/html'
    identTypes = @idents
    defaultIdent = @ident_default
    redirect_path = @redirect_path
    response.status = @@RESPONCE_OK
    response.body = @template.result(binding)
  end

end