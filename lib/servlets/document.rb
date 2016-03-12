class ServletDocument <  WEBrick::USA::ERBSessionServlet

  def handle_GET(req, rsp, session)
    #create or open document
    session.variables['document'] = nil
    if req.query['document'] == 'new'
      raise StandardError, 'No folder in session' unless session.variables['folder']
      session.variables['document'] = session.variables['folder'].new_Document
    else
      session.variables['document'] = Document.new.load(req.query['document'].to_i)
    end

    #Test for success
    if session.variables['document']
      session.variables['documentACL'] = session.variables['document'].ACL(session.identity)
      #Test permissions
      unless session.variables['documentACL'].read?
        raise StandardError, 'You do not have permission to view this Document'
      end
      #load the document body
      session.variables['document'].open_document(session.identity) #will work for both types
    else
      raise ArgumentError, 'Invalid document'
    end
    @logger.warn "#{session.identity.username} (#{session.identity.class.name}) @ #{req.host} - Retrieved Document: #{session.variables['document'].name} with id: #{session.variables['document'].id.to_s}".gsub("\n",'\n')
    super req, rsp, session
  end

  def handle_POST(req, rsp, session)
    raise StandardError, 'No Document open in session' unless session.variables['document']
    raise StandardError, 'No Document ACL information' unless session.variables['documentACL']
    unless (session.variables['document'].id == req.query['document'].to_i) or session.variables['document'].id.nil?
      raise ArgumentError, 'Request values are inconsistent with session'
    end
    unless session.variables['documentACL'].write?
      raise StandardError, 'You either do not have permission to alter this Document or to create a Document in this Folder'
    end

    case req.query['action'].downcase
      when 'save'
        session.variables['document'].name = req.query['name']
        session.variables['document'].type = ((req.query['secure'] == 'secure') ? :secure : :plain)
        session.variables['document'].device! if (req.query['device'] == 'device')
        session.variables['document'].description = req.query['description']
        session.variables['document'].expiretime = Time.at(req.query['expiretime'].to_i)
        session.variables['document'].password = req.query['password']
        session.variables['document'].username = req.query['username']
        session.variables['document'].url = req.query['url']
        session.variables['document'].notes = req.query['notes']
        if acl = WEBrick::USA::Auth::ACL.new(session.identity).load(req.query['acl'].to_i)
          session.variables['document'].ACL = acl if acl.write?
        end
        session.variables['document'].reset! if session.variables['document'].device? #Clear out of sync nonce by end user
        session.variables['document'].save
        @logger.warn "#{session.identity.username} (#{session.identity.class.name}) @ #{req.host} - Updated Document: #{session.variables['document'].name} with id: #{session.variables['document'].id.to_s}".gsub("\n",'\n')
        req.query['document'] = session.variables['document'].id #patch up for the get handler, for new docs
      when 'delete'
        @logger.warn "#{session.identity.username} (#{session.identity.class.name}) @ #{req.host} - Deleted Document: #{session.variables['document'].name} with id: #{session.variables['document'].id.to_s}".gsub("\n",'\n')
        session.variables['document'].delete
        session.variables['document'] = nil
        session.variables['documentACL'] = nil
        rsp.set_redirect WEBrick::HTTPStatus::SeeOther, '/folder'
      else
        raise ArgumentError, 'action not in [\'save\', \'new\', \'delete\']'
    end

    handle_GET req, rsp, session
  end

end
