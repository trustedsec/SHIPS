#Little servelet to provide options lists for select tags
#help reduce some database operations when the information isn't needed

class ServletSelectHelper <  WEBrick::USA::ERBSessionServlet

  def handle_GET(req, rsp, session)
    rsp.status = 200
    rsp['Content-Type'] = 'text/plain'

    case req.query['type']
      when 'acl'
        read_filter = false
        write_filter = false
        read_filter = true if req.query['read'] == 'true'
        write_filter = true if req.query['write'] == 'true'
        rsp.body = options_ACL(session.identity, req.query['selected'].to_i, read_filter, write_filter)
      when 'identTypes'
        rsp.body = option_identTypes(req.query['selected'])
      when 'users'
        rsp.body = option_users(req.query['identType'], req.query['selected'].to_s)
      when 'groups'
        rsp.body = option_groups(req.query['identType'], req.query['selected'])
      else
        rsp.body = ''
    end
  rescue ArgumentError => e
    rsp.body = e.message
    rsp.status = 500
  end

  def to_options(selected, value, body)
    if selected
      "<option selected=\"selected\" value=\"#{value}\">#{body}</option>"
    else
      "<option value=\"#{value}\">#{body}</option>"
    end
  end

  def option_users(ident, selected='')
    directory = WEBrick::USA::User::Identity.get_type(ident).directory
    directory.get_idents.each.map { |identity| to_options((identity.usertoken == selected), identity.usertoken.html_esc, identity.username.html_esc) }.join "\n"
  end

  def option_groups(ident, selected='')
    directory = WEBrick::USA::User::Identity.get_type(ident).directory
    directory.get_groups.each.map { |group| to_options((group.grouptoken == selected), group.grouptoken.html_esc, group.groupname.html_esc) }.join "\n"
  end

  def option_identTypes(selected='')
    ObjectSpace.each_object(Class).select {|klass| klass < WEBrick::USA::User::Identity }.map { |ident|
      to_options((ident.name == selected), ident.name.html_esc, ident.name.html_esc)
    }.join "\n"
  end

  def options_ACL(identity, selected=nil, read_filter=false, write_filter=false)
    acls = Array.new
    WEBrick::USA::Auth::ACL.each(identity) do |acl|
      next unless (not read_filter) or acl.read?
      next unless (not write_filter) or acl.write?
        acls << to_options((acl.id == selected), acl.id.to_s, acl.name.html_esc)
    end
    acls.join "\n"
  end

end