class Configuration
#This is a simple object the wraps YAML 
#This will allow us to read values from a config file, with defaults or raise an exception if there are no good defaults
  def initialize(pathspec)
    @settings = Hash.new
    raise RuntimeError, "#{ self.class.name }::initialize - file not found #{pathspec}" unless File.exist?(pathspec)
    YAML.load_file(pathspec).each { |k,v| @settings[k] = v }
  end
                
  def [](subject,value=nil,default=nil)
    return @settings[subject] unless value
    if @settings[subject]
      r = @settings[subject][value] || default 
    else
      r = default
    end
    raise ArgumentError, "#{ self.class.name }::[] - configuration value #{ value } was not defined but required." if r.nil?
    r
  end
end
                                    