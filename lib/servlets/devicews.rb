require_relative '../document_models'
require 'securerandom'
require 'base64'
require 'time'

class ServletDeviceWS < WEBrick::HTTPServlet::AbstractServlet

  def initialize(server, valid_idents, default)
    @allowed_methods = valid_idents
    @default_method = default
    super server
  end

  def body(ident_type)
    <<HTML
<!DOCTYPE html>
<html>
<head>
  <meta http-equiv="content-type" content="text/html; charset=UTF-8">
</head>
<body>
  <form action="/devicews" method="post" accept-charset="UTF-8">
  <table>
  <tbody>
    <tr>
      <td>method: the identity type to use for authentication, default is use the configured default login identity</td>
      <td><input type="text" name="method"></td>
    </tr>
    <tr>
      <td>Login fields: (required) for (#{ident_type.name.html_esc}) </td>
      <td>#{ident_type.form_inner_html}</td>
    </tr>
    <tr>
      <td>name: (required) name of document or device, must be unique in a given folder</td>
      <td><input type="text" name="name"></td>
    </tr>
    <tr>
      <td>folder: (required) the id of the folder that contains the document to modify</td>
      <td><input type="text" name="folder"></td>
    </tr>
    <tr>
      <td>document_secure: &#x22;secure&#x22; or &#x22;plain&#x22;, storage option for document body default is &#x22;plain&#x22;</td>
      <td><input type="text" name="document_secure"></td>
    </tr>
    <tr>
      <td>document_description: value for document description</td>
      <td><input type="text" name="document_description"></td>
    </tr>
    <tr>
      <td>document_username: value for document username</td>
      <td><input type="text" name="document_username"></td>
    </tr>
    <tr>
      <td>document_password: value for document password</td>
      <td><input type="text" name="document_password"></td>
    </tr>
    <tr>
      <td>document_url: value for document url</td>
      <td><input type="text" name="document_url"></td>
    </tr>
    <tr>
      <td>document_expiretime: value for document expiration time, as UNIX time</td>
      <td><input type="text" name="document_expiretime"></td>
    </tr>
    <tr>
      <td>document_notes: value for document notes</td>
      <td><input type="text" name="document_notes"></td>
    </tr>
    <tr>
    <td>Action: (required) operation to be performed</td>
    </tr>
    <tr>
    <td>Lookup: test if a device is in the db and return the current password</td>
    <td><input type="submit" name="action" value="lookup"></td>
    </tr>
    <tr>
    <td>update: create or update device same as update</td>
    <td><input type="submit" name="action" value="update"></td>
    </tr>
    <tr>
    <td>delete: remove a device from the database</td>
    <td><input type="submit" name="action" value="delete"></td>
    </tr>
    <tr>
    <td>clear: reset the nonce value for the device</td>
    <td><input type="submit" name="action" value="clear"></td>
    </tr>
  </tbody>
  </table>
  </form>
</body>
</html>
HTML
  end

  def do_GET(req, rsp)
    rsp['Content-Type'] = 'text/html'
    rsp.status = '200'
    req.query.each { |k,v| v.force_encoding('UTF-8') }
    ident = get_ident req.query['method']
    rsp.body = body(ident)
    rescue StandardError, ArgumentError => ex
    rsp.status = '500'
    rsp.body = response_document(false, 'unable to process request')
    @logger.warn "Unknown (#{ident.name}) @ #{req.host} - #{ex.message} @ #{ex.backtrace[0]}".gsub("\n",'\n')
  end

  def do_POST(req, rsp)
    rsp['Content-Type'] = 'text/html'
    rsp.status = '200'
    req.query.each { |k,v| v.force_encoding('UTF-8') }
    ident = get_ident req.query['method']
    identity = ident.new.login(req.query)

    raise StandardError, 'Authentication failed' unless identity

    case req.query['action'].downcase
      when 'lookup'
        rsp.body = lookup req.query['name'], req.query['folder'], identity, req.host
      when 'update'
        rsp.body = update req.query, identity, req.host
      when 'delete'
        rsp.body = delete req.query['name'], req.query['folder'], identity, req.host
      when 'clear'
        rsp.body = clear req.query['name'], req.query['folder'], identity, req.host
      else
        raise ArgumentError, 'Invalid value for action specified'
    end

  rescue StandardError, ArgumentError => ex
    rsp.status = '500'
    rsp.body = response_document(false, 'unable to process request')
    @logger.warn "#{req.query['username']} (#{ident.name}) @ #{req.host} - #{ex.message} @ #{ex.backtrace[0]}".gsub("\n",'\n')
  end

  private

  def delete(name, fldr, identity, host)
    @logger.warn "#{identity.username} (#{identity.class.name}) @ #{host} - Request to Delete Document: #{name} in folder: #{fldr}".gsub("\n",'\n')
    doc = get_document name, fldr
    if doc
      doc.delete if doc.ACL(identity).write? #always respond true so this can't be used for document enum
    end
    response_document true, 'deleted'
  end

  def clear(name, fldr, identity, host)
    @logger.warn "#{identity.username} (#{identity.class.name}) @ #{host} - Request to clear nonce for Document: #{name} in folder: #{fldr}".gsub("\n",'\n')
    doc = get_document name, fldr
    if doc
      if doc.ACL(identity).write? #always respond true so this can't be used for document enum
        doc.reset!
        doc.save
      end
    end
    response_document true, 'nonce cleared'
  end

  def lookup(name, fldr, identity, host)
    found = false
    password = ''
    @logger.warn "#{identity.username} (#{identity.class.name}) @ #{host} - Searched for Document: #{name} in folder: #{fldr}".gsub("\n",'\n')
    folder = Folder.new.load fldr
    raise ArgumentError, 'Invalid folder' unless folder
    raise StandardError, 'No folder permissions' unless folder.ACL(identity).read?
    doc = get_document name, folder
    if doc
      @logger.warn "#{identity.username} (#{identity.class.name}) @ #{host} - Retrieved Document: #{doc.name} with id: #{doc.id.to_s}".gsub("\n",'\n')
      found = true
      if doc.ACL(identity).read?
        doc.open_document identity
        if doc.type == :secure
          password = doc.password #already based64 encoded
        else
          password = Base64.strict_encode64(doc.password)
        end
      end
    end
    response_document found, password
  end

  def update(query, identity, host)
    #See if the document exists
    doc = get_document query['name'], query['folder']
    unless doc
      #We need to create a new one
      folder = Folder.new.load(query['folder'].to_i)
      raise ArgumentError, 'Invalid folder' unless folder
      doc = folder.new_Document #Will get the ACL of the folder
      doc.device!
    else
      doc.open_document identity
    end
    raise StandardError, 'no permission to modify document' unless doc.ACL(identity).write?
    doc.name = query['name']
    doc.type = ((query['document_secure'] == 'secure') ? :secure : :plain) if query['document_secure']
    doc.description = query['document_description'] if query['document_description']
    doc.username = query['document_username'] if query['document_username']
    doc.url = query['document_url'] if query['document_url']
    doc.notes = query['document_notes'] if query['document_notes']
    doc.password = query['document_password'] if query['document_password']
    doc.expiretime = query['document_expiretime'] if query['document_expiretime']
    doc.save
    @logger.warn "#{identity.username} (#{identity.class.name}) @ #{host} - Updated Document: #{query['name']} with id: #{doc.id.to_s}".gsub("\n",'\n')
    response_document true, 'document updated'
  end

  def html(str)
    "<!DOCTYPE html><html><body>#{ str.to_s }</body></html>"
  end

  def get_document(name, folder)
    doc = nil
    Document.each_with_ex([[:device, nil, :present], [:name, name, :equal], [:Folder, folder, :equal]]) { |x| doc = x }
    doc
  end

  def response_document(result, payload)
    html("#{ result.to_s },#{ payload }")
  end

  def get_ident(method)
    if @allowed_methods.include? method
      ident = WEBrick::USA::User::Identity.get_type(method)
    else
      ident = WEBrick::USA::User::Identity.get_type(@default_method)
    end
    ident
  end

end