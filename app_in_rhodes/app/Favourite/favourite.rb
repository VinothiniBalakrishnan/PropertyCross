class Favourite
  include Rhom::PropertyBag
  def self.find_all_by_guid(guid)
    find(:all, :conditions => { "guid" => guid })
  end
end
