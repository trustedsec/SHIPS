class ServletManageMyKey <  WEBrick::USA::ERBSessionServlet

  def handle_POST(req, rsp, session)
    #important to update the existing key to preserve secure doc relationship
    pair = PubKey.load_by_identity session.identity
    unless pair #unless there is no existing key then its okay because no docs can exist
      pair = PubKey.new
      pair.identity = session.identity
    end

    case req.query['action']
      when 'generate'
        session.variables['private_key'] = pair.generate_key
        pair.save
        #A throwaway nonce to protect against a specific csrf case
        session.variables['nonce'] = (1 + SecureRandom.random_number(2147483646))
        rsp.set_redirect WEBrick::HTTPStatus::SeeOther, "/SHIPS_Private_Key?nonce=#{session.variables['nonce']}"
      when 'upload'
        if req.query['public_key']
          pair.pubkey = req.query['public_key']
        else
          raise ArgumentError, 'Request did not contain a public key'
        end
      else
        raise ArgumentError, 'action not in [\'generate\',\'upload\']'
    end
    pair.save
    rsp.set_redirect WEBrick::HTTPStatus::SeeOther, '/welcome'
  end

end