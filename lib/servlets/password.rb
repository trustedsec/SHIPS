require_relative '../identdevice'
require_relative '../document_models'
require 'securerandom'
require 'base64'
require 'time'

#The device password service
class ServletPassword < WEBrick::HTTPServlet::AbstractServlet

  def initialize(server, length, age)
    @password_length = length
    @password_time = age
    super server
  end

  def do_GET(req, rsp)
    rsp['Content-Type'] = 'text/html'
    rsp.status = '200'
    req.query.each { |k,v| v.force_encoding('UTF-8') }

    identity = login(req.query)
    @logger.info "#{req.query['name']} (IdentDevice) @ #{req.host} - #{identity.loginMessage}".gsub("\n",'\n')

    if identity.Document
      raise StandardError 'No permission to update associated document' unless identity.Document.ACL(identity).write?
      doc = identity.Document
    else
      raise StandardError 'No folder for device identity configuration error' unless identity.Folder
      raise StandardError 'No permission to create associated document' unless identity.Folder.ACL(identity).write?
      doc = identity.Folder.new_Document
      doc.name = identity.username
      doc.device!
    end

    if doc.type == :secure
      doc.clear! #no way to read existing values - so flush'em
    else
      doc.open_document identity
    end
    doc.expiretime = expire_time #This is really just a suggestion, the client can't be forced to do this
    doc.password = generate_password #This one is up to the server!

    #Set the values the client wishes, don't modify values that are not sent for the sake of plain docs
    doc.type = ((req.query['secure'] == 'secure') ? :secure : :plain) if req.query['secure']
    doc.description = req.query['description'] if req.query['description']
    doc.username = req.query['username'] if req.query['username']
    doc.url = req.query['url'] if req.query['url']
    doc.notes = req.query['notes'] if req.query['notes']
    rsp.body = response_document(true, Base64.strict_encode64(doc.password), doc.nonce!, doc.expiretime)
    doc.save
    @logger.info "#{req.query['name']} (IdentDevice) @ #{req.host} - Updated Document #{doc.name} id: #{doc.id.to_s}".gsub("\n",'\n')

  rescue StandardError, ArgumentError => ex
    rsp.status = '500'
    rsp.body = response_document(false, 'unable to process request', 0, Time.new)
    @logger.warn "#{req.query['name']} (IdentDevice) @ #{req.host} - #{ex.message} @ #{ex.backtrace[0]}".gsub("\n",'\n')
  end

  alias_method :do_POST, :do_GET

  private
  def html(str)
    "<!DOCTYPE html><html><body>#{ str.to_s }</body></html>"
  end

  def response_document(result, payload, nonce='0', date='0')
    html("#{ result.to_s },#{ payload },#{ nonce },#{ Time.at(date.to_i).strftime('%F %T') }")
  end

  def login(form_data)
    identity = IdentDevice.new
    unless identity.login(form_data)
      raise StandardError, identity.loginMessage
    end
    identity
  end

  def generate_password
    #generates password with complexity 3 of upper/lower/number/special
    complex = 0
    while complex < 3 do
      newpwd = Array.new(@password_length) { SecureRandom.random_number(94) + 32 } #array of printing chars
      complex = complex + 1 if newpwd.index { |a| (65..90).include? a } #upper
      complex = complex + 1 if newpwd.index { |a| (97..122).include? a } #lower
      complex = complex + 1 if newpwd.index { |a| (48..57).include? a } #number
      complex = complex + 1 if newpwd.index { |a| ((32..47).include? a) or #specials
          ((58..64).include? a) or
          ((91..96).include? a) or
          ((123..126).include? a) }
    end
    newpwd.map { |a| a.chr }.join
  end

  def expire_time
    #Adds 7 hours of fuzziness to the expiry
    Time.new.to_i + (3600 * 24 * @password_time) + (rand(8) * 3600)
  end

end