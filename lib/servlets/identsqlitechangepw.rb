class ServletIdentSQLiteChangePW <  WEBrick::USA::ERBSessionServlet

  def handle_GET(req, rsp, session)
    preflight(session.identity)
    super req, rsp, session
    session.variables['IdentSQLiteChangePW'] = ''
  end

  def handle_POST(req, rsp, session)
    preflight(session.identity)
    useraccount = UserAccount.new.load session.identity.usertoken
    raise ArgumentError, 'Password incorrect!' unless useraccount.password? req.query['old_password']
    raise ArgumentError, 'Passwords do not match!' unless req.query['password'] == req.query['password1']

    useraccount.password = req.query['password']
    useraccount.save
    @logger.info "#{session.identity.username} (#{session.identity.class.name}) @ #{req.host} - changed identSQLite password"
    session.variables['IdentSQLiteChangePW'] = 'Password updated'
  rescue ArgumentError => ex
    session.variables['IdentSQLiteChangePW'] = ex.message
  ensure
    handle_GET req, rsp, session
  end

  private

  def preflight(ident)
    raise 'Page only available when authenticated by IdentSQLite' unless ident.class.name == 'IdentSQLite'
  end
end