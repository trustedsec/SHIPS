#webservice for setting computer passwords
class ServletPassword < WEBrick::HTTPServlet::AbstractServlet
  @@RESPONCE_OK = "200"
  @@RESPONCE_REJECT = "500"
  
  def initialize(server, validators)
    @validators = validators
    super server
  end
  
  def html(str)
    "<!DOCTYPE html><html><body>#{ str.to_s }</body></html>"
  end
  
  def response_document(result, payload, nonce='0', date='1900-01-01 00:00:00')
    html("#{ result.to_s },#{ payload },#{ nonce },#{ date }") 
  end
  
  def validComputer(name)
    result = false
    @validators.each { |obj| result ||= obj.send(:lookup, name) }
    result
  end
  
  def do_GET(request, response)
    raise ArgumentError, 'Query did not include name' unless request.query['name']  
    name = request.query['name'].force_encoding('UTF-8') 
    nonce = request.query['nonce'].force_encoding('UTF-8') if request.query['nonce']
    nonce = request.query['nouonce'].force_encoding('UTF-8') if request.query['nouonce'] #legacy spelling
    
    if (computer = Computer.new.load(name)) #ok in the database
      raise ArgumentError, 'Nonce value is incorrect' unless ((computer.nonce == nonce) or (computer.nonce == '0'))
    elsif validComputer(name) #alright its in 'a' database
      computer = Computer.new
      computer.name = name
    else
      raise ArgumentError, 'Specified computer does not exist or is disallowed'
    end
    
    computer.nonce = nil #replace the values with new defaults
    computer.password = nil
    computer.save #write the changes
    
    Syslog.info("Sent password update to #{ computer.name }") if Syslog.opened?
    response.status = @@RESPONCE_OK
    response.body = response_document(true, computer.enc_password, computer.nonce, computer.expire_time)
    
  rescue ArgumentError => e
    Syslog.err("#{ name || 'unknown' } - #{ e.message }") if Syslog.opened?
    response.status = @@RESPONCE_REJECT = "500"
    response.body = response_document(false, e.message)
  rescue StandardError => e
    response.status = @@RESPONCE_REJECT = "500"
    response.body = response_document(false, 'Unable to process request')
    Syslog.crit("#{ e.message } - #{ e.backtrace }") if Syslog.opened? 
  end
  
  def do_POST(request, response)
    do_GET(request, response) #Allow the same operation via POST
  end
end
