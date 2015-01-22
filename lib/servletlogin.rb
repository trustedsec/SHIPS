#webservice for admin functions
#has to reimplement alot of logon function sadly
class ServletLogin < WEBrick::HTTPServlet::AbstractServlet
  @@RESPONCE_OK = "200"
  
  def initialize(server, idents, ident_default, template)
    @idents = idents
    @ident_default = ident_default
    @template = template
    super server
  end
  
  
  def do_GET(request, response)
    identTypes = @idents
    defaultIdent = @ident_default
    response.status = @@RESPONCE_OK
    response.body = @template.result(binding)  
  end
  
end
