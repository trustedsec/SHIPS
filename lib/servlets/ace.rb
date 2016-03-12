class ServletACE <  WEBrick::USA::ERBSessionServlet

  def handle_GET(req, rsp, session)

    #Its be safe to open the ace before other checks
    if req.query['ace'].to_i == 0 #new ace
      session.variables['ace'] = session.variables['acl'].new_ACE
    else
      session.variables['ace'] = WEBrick::USA::Auth::ACE.new.load(req.query['ace'].to_i)
    end

    pre_flight(req, session)
    super req, rsp, session
  end

  def handle_POST(req, rsp, session)
    pre_flight(req, session)

    case req.query['action'].downcase
      when 'save'
        session.variables['ace'].read = ((req.query['read'] == 'true') ? true : false)
        session.variables['ace'].write = ((req.query['write'] == 'true') ? true : false)

        #raise an error if not a real type, by calling get_type on the Identity class.
        identclass = WEBrick::USA::User::Identity.get_type(req.query['identity'])
        session.variables['ace'].identity =  identclass.name
        if req.query['group'] == 'true'
          #verify valid group
          group = identclass.directory.get_group_by_token(req.query['group_token'])
          raise ArgumentError, 'invalid group' unless group
          session.variables['ace'].group =  WEBrick::USA::User::Group.new(nil, group.grouptoken)
        else
          #verify valid user
          raise ArgumentError, 'Cannot set empty user on ACE' if req.query['user_token'].to_s == ''
          user = identclass.directory.get_ident_by_token(req.query['user_token'])
          raise ArgumentError, 'invalid user' unless user
          session.variables['ace'].token = user.usertoken
        end

        #suppress an error that might have given to much away about the database structure
        begin
          session.variables['ace'].save
        rescue RuntimeError => e
          raise RuntimeError, 'ACE is not unique' if e.message.start_with? 'UNIQUE'
        end

      when 'delete'
        session.variables['ace'].delete
      else
        raise ArgumentError, 'action not in [\'save\', \'delete\']'
    end

    #redirect to /acl
    rsp.set_redirect WEBrick::HTTPStatus::SeeOther, "/acl?acl=#{req.query['acl'].to_i.to_s}"
  end

  private

  def pre_flight(req, session)
    #Non ACL authors have no reason to use this at all
    unless WEBrick::USA::Auth::ACL.acl_author? session.identity
      raise StandardError, 'You are not an ACL author, ACE editing is not permitted'
    end

    unless session.variables['acl'].id
      raise ArgumentError, 'No ACL open in session, open an ACL first.'
    end

    unless req.query['acl'].to_i == session.variables['acl'].id
      raise ArgumentError, 'Request values are inconsistent with session'
    end

    raise ArgumentError, 'Requested ACE object not found' unless session.variables['ace']

    raise StandardError, 'Bad relation ACE -> ACL' unless session.variables['ace'].ACL == session.variables['acl']

    #session is setup, auth ok, and integrity sees reasonable
  end
end