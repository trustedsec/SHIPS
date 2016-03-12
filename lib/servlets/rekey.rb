class ServletReKey <  WEBrick::USA::ERBSessionServlet

  def moveRecord(docBody, publicKey, privateKey)
    docBody.rekeyCnt! #This might help data recovery processes
    docBody.username = publicKey.cipher(privateKey.decipher(docBody.username))
    docBody.password!  publicKey.cipher(privateKey.decipher(docBody.password))
    docBody.password1 = publicKey.cipher(privateKey.decipher(docBody.password1))
    docBody.password2 = publicKey.cipher(privateKey.decipher(docBody.password2))
    docBody.password3 = publicKey.cipher(privateKey.decipher(docBody.password3))
    docBody.description = publicKey.cipher(privateKey.decipher(docBody.description))
    docBody.notes = publicKey.cipher(privateKey.decipher(docBody.notes))
    docBody.url = publicKey.cipher(privateKey.decipher(docBody.url))
    docBody.expiretime = publicKey.cipher(privateKey.decipher(docBody.expiretime))
    docBody.save
  end

  def handle_GET(req, rsp, session)
    super req, rsp, session
    session.variables['results'] = nil
  end

  def handle_POST(req, rsp, session)
    publicKey = PubKey.load_by_identity session.identity
    raise StandardError, 'You do not have a valid public key' unless publicKey
    raise StandardError, 'Private key not sent' unless req.query['private_key']
    raise StandardError, 'Unexpected value for submit' unless req.query['submit'] == 'Ok'

    privateKey = PrivKey.new req.query['private_key']

    #This is actually ok with no ACL checks
    #we are only modifying data that is already stored and only belonging to the current session owner, implicitly
    i = DocumentBody.count_with(:PubKey, publicKey)
    if i < 31
      i = 0
      DocumentBody.each_with(:PubKey, publicKey) do |docBody|
        moveRecord docBody, publicKey, privateKey
        i += 1
      end
      session.variables['results'] = "Completed updating #{i} records!"
    else
      session.variables['results'] = "Record count is large (#{i.to_s}) job will run asynchronously!"
      @logger.warn "#{session.identity.username} (#{session.identity.class.name}) @ #{req.host} - Doing aysnc rekey"
      Pool.schedule do
        DocumentBody.each_with(:PubKey, publicKey) do |docBody|
          moveRecord docBody, publicKey, privateKey
        end
      end
    end

    handle_GET(req, rsp, session)
  end
end