class ServletPrivKeyDownload < WEBrick::USA::SessionServlet

  def handle_GET(req, rsp, session)
    unless req.query['nonce'] == session.variables['nonce'].to_s
      raise StandardError, 'cross site request policy violation'
    end
    req.query['nonce'] = (1 + SecureRandom.random_number(2147483646)) #make it an unknown value
    rsp.status = 200
    rsp['Content-Type'] = 'application/octet-steam'
    rsp.body = session.variables['private_key'].to_s
  end
end