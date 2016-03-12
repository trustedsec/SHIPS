class ServletFolder <  WEBrick::USA::ERBSessionServlet

  def handle_GET(req, rsp, session)
    ifolder = req.query['folder'].to_i
    if ifolder == 0
      folder = session.variables['folder']
    else
      folder = Folder.new.load ifolder
    end

    unless folder #get root folder if passed invalid folder id
      Folder.each_with(:name, '.') { |f| folder = f}
    end
    session.variables['folder'] = folder
    #now having the requested folder, the old session value, or the root - security test
    acl = session.variables['folder'].ACL(session.identity)
    unless acl.read?
      session.variables['folder'] = nil #let user navigate back to readable folder
      raise StandardError, 'No read permissions on this folder!'
    end

    #keep the current acl in the session for use in display decisions on views
    #NEVER make security decisions based on the in session acl
    session.variables['acl'] = acl
    #render the view
    super req, rsp, session
  end

  def handle_POST(req, rsp, session)

    #We should only be altering the folder that was last viewed
    raise StandardError, 'No folder is open in your session' unless session.variables['folder']
    unless req.query['folder'].to_i == session.variables['folder'].id.to_i #Unsaved folders id will be nil .to_i will be 0
      raise ArgumentError, 'Request values are inconsistent with session'
    else
      req.query['folder'] = '0' #save a db hit sending the page back
    end

    unless session.variables['folder'].ACL(session.identity).write?
      raise StandardError, 'No write permissions on this folder!'
    end

    case req.query['action'].downcase
      when 'update'
        unless session.variables['folder'].name == '.' #special not allowed conditions
          session.variables['folder'].name = req.query['name']
        end
        session.variables['folder'].description =  req.query['description']
        if acl = WEBrick::USA::Auth::ACL.new(session.identity).load(req.query['acl'])
          session.variables['folder'].ACL = acl if acl.write? #don't let someone take away their own write permission
        end
        session.variables['folder'].save
      when 'new subfolder'
        folder = session.variables['folder'].new_Folder
        folder.name  = 'New'
        folder.description = 'New child folder in ' + session.variables['folder'].name
        session.variables['folder'] = folder #when handle_get runs user gets the new folder
        session.variables['folder'].save
      when 'delete'
        folder = session.variables['folder'].parent_Folder
        session.variables['folder'].delete
        session.variables['folder'] = folder
      else
        raise ArgumentError, 'action not in [\'update\', \'new\', \'delete\']'
    end
  handle_GET(req, rsp, session)
  end
end