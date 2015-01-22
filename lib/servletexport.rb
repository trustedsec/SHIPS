require 'erb'

class ServletExport < WEBrick::USA::SessionServlet
  
  def handle_GET(request, response, session)
    superuser = WEBrick::USA::Auth::ACL.is_super?(session.identity)
    raise SecurityError, 'Only the Super User may export passwords' unless superuser
    response['Content-Type'] = 'text/plain'
    #produce the content with the current variable bindings
    response.body = "computername\tnonce\ttombstone\tpassword\n"
    Computer.each { |c| response.body += c.to_array.join("\t") + "\n" }
  end
  
  def handle_POST(r, rs, s)
    handle_GET(r, rs, s)
  end
  
end
