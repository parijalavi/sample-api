module Helpers
  DB_STRINGS = {:test => "sample_db_test", :development => "sample_db_dev", :production => "flame.mongohq.com"}

  def self.db_string(environment)
    DB_STRINGS[environment]
  end
  
  def self.credentials
    ["sample", "sample"]
  end
  
  def self.production_connection
    Proc.new do 
      auth = Helpers.credentials
      c = Mongo::Connection.new(Helpers.db_string(:production), 27094)
      db = c.db("sample_api")
      db.authenticate(auth.first, auth.last)
      db
    end
  end
  
  def protected!
    unless personized?
      response['WWW-Authenticate'] = %(Basic realm="Testing HTTP Auth")
      throw(:halt, [401, "Not personized\n"])
    end
  end

  def personized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [settings.username, settings.password]
  end
  
  def grab_sample
    sample.from_hash(params)
  end
  
  def sample_id
    params[:sample_id]
  end
  
  def params_missing?(param)
    params[param].nil? or params[param].empty?
  end
  
  def parse_body_to_json
    request.body.rewind
    Crack::JSON.parse(request.body.read)
  end
  
  def validate_sample_id_correct_format
    begin
      BSON::ObjectId(sample_id)
    rescue BSON::InvalidObjectId
      halt(400, "ID not in valid format.")
    end
  end
  
  def validate_tags_present
    halt(400, "Must supply at least one tag in search.") if params_missing?(:tags)
  end
  
  def set_creation_times(q)
    timestamp = Time.now.to_i
    q[:inserted_at] = timestamp
    q[:updated_at] = timestamp
  end
  
  def validate_required_params_present_for_new_sample(q)
 	["person", "catchphrase"].each do |required_param|
      halt(400, "Missing required field :#{required_param}") unless q.key?(required_param)
    end
  end
end
