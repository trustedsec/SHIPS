require 'net/ldap'

module LDAP_Helpers
  # https://github.com/ruby-ldap/ruby-net-ldap/issues/222
  # http://blogs.msdn.com/b/oldnewthing/archive/2004/03/15/89753.aspx
  def get_sid_string(data)
    sid = data.to_s.unpack('b x nN V*')
    sid[1, 2] = Array[nil, b48_to_fixnum(sid[1], sid[2])]
    'S-' + sid.compact.join('-')
  end

  # https://github.com/ruby-ldap/ruby-net-ldap/issues/222
  def b48_to_fixnum(i16, i32)
    i32 + (i16 * (2**32))
  end
end

