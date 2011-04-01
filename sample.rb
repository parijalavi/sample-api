class Hash
  def symbolize_keys
    replace(inject({}) { |h,(k,v)| h[k.to_sym] = v; h })
  end
end

class Sample
  attr_accessor :person, :category, :catchphrase, :inserted_at, :updated_at, :approved
  
  def self.create
    q = self.new
    q.inserted_at = Time.now.to_i
    q.updated_at = q.inserted_at
    yield(q) if block_given?
    q
  end
  
  def initialize
  	self.approved = false
  end
  
  def approved?
  	approved
  end
  
  def self.from_hash(pure_hash)
    hash = pure_hash.symbolize_keys
    sample = self.create do |q|
      q.person= hash[:person]
      q.catchphrase = hash[:catchphrase]
      q.category = hash[:category]
      
      [:inserted_at, :updated_at, :approved].each do |attribute|
	 	unless hash[attribute].nil?
           q.send("#{attribute}=", hash[attribute])
         end
      end
    end
    sample
  end
  
  def to_hash
    {
      :person => person.to_s,
      :catchphrase => catchphrase.to_s,
      :category => category.to_s,
      :inserted_at => inserted_at,
      :updated_at => updated_at,
      :approved => approved
    }
  end
  
end
