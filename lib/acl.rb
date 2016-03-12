require 'usa'
require 'SQLiteORM'

#patches to the ACL and ACE classes.
#Not inherited because frame work initialization would only apply to ACL not its children
#adds persistence into the SQLiteDB

class WEBrick::USA::Auth::ACL
  #persistence (turn it into a data model)
  include SQLiteORM
  persist_attr :name, :TEXT
  persist_attr :description, :TEXT
  order_by_attr :name, :DESC
  attr_reader :id

  def after_load
    #empty the ace array, replace with database content
    @aces.clear
    self.each_ACE { |ace| @aces << ace} #can't use add ace b/c auth check
  end

 def after_save
   @aces.each { |ace| ace.ACL = self; ace.save }
 end

  def before_delete
    cnt = 0
    self.class.related.map {|x| x[0]}.reject {|model| model.name == 'ACE' }.uniq.each do |relation|
        cnt += relation.count_with :ACL, self if relation.new.respond_to? :ACL=
    end
    raise StandardError, "Unable to delete this #{ self.class.name } it is in use by #{ cnt.to_s } other objects." unless cnt == 0
    self.each_ACE { |ace| ace.delete }
  end

  alias_method :orig_del_ace, :del_ace
  private :orig_del_ace
  def del_ace(ace)
    tmp = orig_del_ace ace
    ace.delete if tmp
    tmp
  end

end

class WEBrick::USA::Auth::ACE
  #persistence (turn it into a data model)
  include SQLiteORM
  persist_attr :grouptoken, :TEXT
  persist_attr :token, :TEXT
  persist_attr_reader :ident_class, :TEXT
  persist_attr :canread, :TEXT
  persist_attr :canwrite, :TEXT
  relate_model WEBrick::USA::Auth::ACL, :manyToOne
  unique_attrs :ACL, :token, :ident_class, :grouptoken
  order_by_attr :token, :DESC #so similar items will group together in lists
  attr_reader :id

  def after_load
    @group = ((@grouptoken == 'true') ? true : false)
    @read =  ((@canread == 'true') ? true : false)
    @write = ((@canwrite == 'true') ? true : false)
  end

  def before_save
    @grouptoken = (@group ? 'true' : 'false')
    @canread = (@read ? 'true' : 'false')
    @canwrite = (@write ? 'true' : 'false')
  end

  def to_s
    if @group
      "Members of #{group_name} authenticated by #{@ident_class} have #{english}."
    else
      "User #{user_name} authenticated by #{@ident_class} has #{english}."
    end
  end

  private

  def group_name
    if grp = self.identity.directory.get_group_by_token(@token)
      "[#{grp.groupname}]"
    else
      "[#{@token}]"
    end
  end

  def user_name
    if usr = self.identity.username
      "[#{usr}]"
    else
      "[#{@token}]"
    end
  end

  def english
    if @read
      if @write
        return 'permissions read and write'
      end
      return 'permission read only'
    elsif @write
      return 'permission write only'
    end
    'no permission'
  end

end