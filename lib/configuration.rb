require 'yaml'

class Configuration
#This is a simple object the wraps YAML 
#This will allow reading from a config file, with defaults or raise an exception if there are no good defaults
  def initialize(path_spec)
    @settings = Hash.new
    raise RuntimeError, "#{ self.class.name }::initialize - file not found #{path_spec}" unless File.exist?(path_spec)
    YAML.load_file(path_spec).each { |k,v| @settings[k] = v }
  end

  def keys_to_sym(h)
    nh = Hash.new
    h.map {|k,v| [k.to_sym, v]}.each { |pair| nh[pair[0]] = pair[1]}
    nh
  end
                
  def [](subject,value=nil,default=nil)
    return keys_to_sym(@settings[subject]) unless value
    if @settings[subject]
      r = @settings[subject][value] || default 
    else
      r = default
    end
    raise ArgumentError, "#{ self.class.name }::[] - configuration value #{ value } was not defined but required." if r.nil?
    r
  end
end
                                    