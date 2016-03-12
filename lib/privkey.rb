require 'openssl'
require 'base64'
class PrivKey
  def initialize(pem)
    @key = OpenSSL::PKey::RSA.new pem
  end

  def decipher(ctext)
    return '' unless ctext
    ptext = @key.private_decrypt(Base64.decode64(ctext))
    Base64.decode64(ptext)
  end
end