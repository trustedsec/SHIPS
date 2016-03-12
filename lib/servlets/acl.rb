class ServletACL <  WEBrick::USA::ERBSessionServlet

  def handle_GET(req, rsp, session)
    #Get a valid acl to work with
    unless req.request_method == 'POST' #already have the acl in the session
      if req.query['acl'].to_i == 0 #new ACL
        acl = WEBrick::USA::Auth::ACL.new(session.identity)
      else #requested ACL
        acl = WEBrick::USA::Auth::ACL.new(session.identity).load req.query['acl'].to_i
      end
      #And if the requested was bogus the previously open ACL or finally the first
      acl ||= session.variables['acl']
      acl ||= WEBrick::USA::Auth::ACL.first session.identity
      session.variables['acl'] = acl #add it to the session
    end

    #determine this once per page view (save some object creation and back end queries)
    session.variables['acl_auth'] = WEBrick::USA::Auth::ACL.acl_author? session.identity
    session.variables['acl_auth'] = session.variables['acl_auth'] || WEBrick::USA::Auth::ACL.is_super?(session.identity)
    super req, rsp, session
  end

  def handle_POST(req, rsp, session)
    raise StandardError, 'No ACL is open in your session' unless session.variables['acl']
    unless req.query['acl'].to_i == session.variables['acl'].id.to_i #id might be nil, 0 might be valid if new unsaved acl
      raise ArgumentError, 'Request values are inconsistent with session'
    end

    unless WEBrick::USA::Auth::ACL.acl_author? session.identity
      raise StandardError, 'You are not an ACL author, requested changes are not permitted'
    end

    case req.query['action'].downcase
      when 'update'
        session.variables['acl'].name = req.query['name']
        session.variables['acl'].description = req.query['description']
        session.variables['acl'].save
      when 'save'
        session.variables['acl'].name = req.query['name']
        session.variables['acl'].description = req.query['description']
        session.variables['acl'].save
        req.query['acl'] = session.variables['acl'].id
      when 'delete'
        session.variables['acl'].delete
        session.variables['acl'] = WEBrick::USA::Auth::ACL.new(session.identity) #new object
      else
        raise ArgumentError, 'action not in [\'update\', \'new\', \'delete\']'
    end

    handle_GET(req, rsp, session)
  end
end