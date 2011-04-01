require 'bundler/setup'
require "json"
require "mongo"
require 'rack/test'
require 'sinatra'
require "base64"
require 'uri'

# setup test environment
set :environment, :test
set :raise_errors, true
set :logging, false

#Load order matters here - these requires must come after the set statements above.
require File.join(File.dirname(__FILE__), "service")
require File.join(File.dirname(__FILE__), "sample")
require File.join(File.dirname(__FILE__), "helpers")

Spec::Runner.configure do |conf|
  conf.include Rack::Test::Methods
  conf.include Helpers
end

describe "Sample Service" do
  include Rack::Test::Methods   
    
  def drop_test_database
    connection = Mongo::Connection.new
    connection.drop_database(Helpers.db_string(:test))
    connection.close
  end
  
  def app
    Sinatra::Application
  end
  
  def create_unapproved_sample
    post "/sample", {:person=> "Apple", :category=> "Banana", :catchphrase => "I love Nutella."}.to_json, {'CONTENT_TYPE' => 'application/json', 'HTTP_AUTHORIZATION'=> encode_credentials('admin', 'admin')}
    last_response.headers["Location"]
  end
  
  def create_approved_sample
  	post "/sample", {:person=> "Apple", :category=> "Banana", :catchphrase => "I love Nutella.", :approved => true}.to_json, {'CONTENT_TYPE' => 'application/json', 'HTTP_AUTHORIZATION'=> encode_credentials('admin', 'admin')}
    last_response.headers["Location"]
  end
    
  def encode_credentials(username, password)
      "Basic " + Base64.encode64("#{username}:#{password}")
  end
  
  def get_sample_by(sample_id)
    get "#{sample_id}"
    last_response.status.should be(200)
    body = last_response.body
    body.should_not be_nil
    body.should_not be_empty
    last_response_returned_json
    parsed_body = JSON.parse(body)
    Sample.from_hash(parsed_body)
  end
  
  def last_response_was_200
    last_response.status.should be(200)
  end
  
  def last_response_returned_json
    last_response.content_type.should == "application/json"
  end
  
  before :all do
    drop_test_database
  end
  
  context "helpers" do
    it "should provide database connection strings" do
      Helpers.db_string(:test).should == "sample_db_test"
      Helpers.db_string(:development).should == "sample_db_dev"
    end
  end
  
  context "when creating a sample" do
    it "should be possible to look up a sample by id" do
      create_approved_sample
      last_response.status.should be(201)
      sample_id = last_response.headers["Location"]
      get "#{sample_id}"
      last_response.status.should be(200)
      body = last_response.body
      body.should_not be_nil
      body.should_not be_empty
      last_response_returned_json
      parsed_body = JSON.parse(body)
      sample = Sample.from_hash(parsed_body)
      sample.person.should == "Apple"
      sample.category.should == "Banana"
      sample.catchphrase.should == "I love Nutella."
      sample.approved.should be(true)
    end    
    
    it "should respect field values set when creating" do
      create_approved_sample
      last_response.status.should be(201)
      sample_id = last_response.headers["Location"]
      get "#{sample_id}"
      parsed_body = JSON.parse(last_response.body)
      sample = Sample.from_hash(parsed_body)
      sample.approved.should be(true)
    end

    it "should be possible to get a list of all sample id's in the system where inserted_at & updated_at are the same" do
      pending
    end

    it "should return a 400 if the id is not valid BSON format" do
      get "/sample/id/yargablabla"
      last_response.status.should be(400)
      last_response.body.should == "ID not in valid format."
    end
    
    it "should return a 404 if the sample is not found" do
      bad_id = BSON::ObjectId.new.to_s
      get "/sample/id/#{bad_id}"
      last_response.status.should be(404)
      last_response.body.should == "No sample with matching ID found."
    end
  end
  
  context "when creating a sample" do
    it "should set the Location response header to the id of the newly created sample" do
      create_unapproved_sample
      last_response.status.should be(201)
      last_response.headers["Location"].should_not be_nil
      last_response.headers["Location"].should_not be_empty
    end
        
    it "should require all parameters to be present except for category" do
      post "/sample", {:category => "Banana", :catchphrase => "I love Nutella."}.to_json, {'HTTP_AUTHORIZATION'=> encode_credentials('admin', 'admin'), 'CONTENT_TYPE' => 'application/json'}
      last_response.status.should be(400)
      last_response.body.should == "Missing required field :person"
      post "/sample", {:person => "Apple", :category => "Banana"}.to_json, {'HTTP_AUTHORIZATION'=> encode_credentials('admin', 'admin'), 'CONTENT_TYPE' => 'application/json'}
      last_response.status.should be(400)
      last_response.body.should == "Missing required field :catchphrase"
    end
  end
  
  context "when dealing with unapproved samples" do 
  	it "should accept a JSON document with samples to save a batch of new unapproved samples" do
  	  document = {}
  	  document["samples"] = []
  	  document["samples"] << {:person => "Pari Bug", :catchphrase => "I LOVE dogs!"}
  	  document["samples"] << {:person => "Pari Bug", :catchphrase => "I want to go to Fiji!"}
  	  post "/unapproved", document.to_json, {'HTTP_AUTHORIZATION'=> encode_credentials('admin', 'admin'), 'CONTENT_TYPE' => 'application/json'}
  	  last_response.status.should be(201)  	  
  	end
  	
  	it "should return an error if Content-Type is not application/json" do
  	  document = {}
  	  document["samples"] = []
  	  document["samples"] << {:person => "Pari Bug", :catchphrase => "I LOVE dogs!"}
  	  document["samples"] << {:person => "Pari Bug", :catchphrase => "I want to go to Fiji!"}
  	  post "/unapproved", document.to_json, {'HTTP_AUTHORIZATION'=> encode_credentials('admin', 'admin'), 'CONTENT_TYPE' => 'application/octet'}
  	  last_response.status.should be(400) 
  	end
  	
  	it "should let a client get n unapproved samples" do
  	 document = {}
  	  document["samples"] = []
  	  document["samples"] << {:person => "Pari Bug", :catchphrase => "I LOVE dogs!"}
  	  document["samples"] << {:person => "Pari Bug", :catchphrase => "I want to go to Fiji!"}
  	  document["samples"] << {:person => "sebCell", :catchphrase => "I want a rocket ship to go to Mars!"}
  	  post "/unapproved", document.to_json, {'HTTP_AUTHORIZATION'=> encode_credentials('admin', 'admin'), 'CONTENT_TYPE' => 'application/json'}
  	  get "/unapproved/2"
  	  last_response.status.should be(200)
  	  last_response_returned_json
  	  samples = JSON.parse(last_response.body)
  	  samples["samples"].should_not be_empty
  	  samples["samples"].first["approved"].should be(false)
  	  samples["samples"].size.should == 2
  	end
  	
  	it "should only let clients get approved samples from the CRUD api" do
  	  document = {"samples" => [{:person => "Pari Bug", :catchphrase => "I want to go to Fiji!"}]}
  	  post "/unapproved", document.to_json, {'HTTP_AUTHORIZATION'=> encode_credentials('admin', 'admin'), 'CONTENT_TYPE' => 'application/json'}
  	  get "/unapproved/1"
  	  samples = JSON.parse(last_response.body) 
  	  sample_id = samples["samples"].first["_id"]["$oid"]
  	  get "/sample/id/#{sample_id}"
  	  last_response.status.should be(400)
  	  post "/sample/id/#{sample_id}", {:approved => true, :person => "SebCell"}.to_json, {'HTTP_AUTHORIZATION'=> encode_credentials('admin', 'admin'), 'CONTENT_TYPE' => 'application/json'}
  	  last_response.status.should be(201)
  	  get "/sample/id/#{sample_id}"
  	  last_response.status.should be(200)
  	  sample = JSON.parse(last_response.body)
  	  sample["approved"].should be(true)
  	  sample["updated_at"].should_not == sample["created_at"]
  	end
  	  	
  	it "should return the id for unapproved samples" do
  	  document = {"samples" => [{:person => "Pari Bug", :catchphrase => "I want to go to Fiji!"}]}
  	  post "/unapproved", document.to_json, {'HTTP_AUTHORIZATION'=> encode_credentials('admin', 'admin'), 'CONTENT_TYPE' => 'application/json'}
  	  get "/unapproved/1"
	  last_response_returned_json
  	  samples = JSON.parse(last_response.body) 
  	  samples["samples"].first.key?("_id").should be(true)
  	end
  	
  	it "should not let a client request a non-integer amount of unapproved samples" do
  	  get "/unapproved/abcd"
  	  last_response.status.should be(400)
  	end
  	
  	it "should not allow negative numbers" do
	  get "/unapproved/-3"
  	  last_response.status.should be(400)  	
  	end
  end

  context "when deleting a sample by id" do
    it "should look up the sample by id and then delete it from the backing data store" do
      id = create_approved_sample
      q = get_sample_by id
      last_response_was_200
      delete "#{id}", {}, {'HTTP_AUTHORIZATION'=> encode_credentials('admin', 'admin')}
      last_response_was_200
      get "#{id}"
      last_response.status.should be(404)
    end
  end
    
  context "when updating a sample by id" do

    it "should return a 400 if the id is not valid BSON format" do
      post "/sample/id/yargablabla", {}, {'HTTP_AUTHORIZATION'=> encode_credentials('admin', 'admin')}
      last_response.status.should be(400)
      last_response.body.should == "ID not in valid format."
    end
    
    it "should allow you to update the category" do
      id = create_approved_sample
      q = get_sample_by id
      q.category = "I love cherry pie."
      updated_values = q.to_hash
      post "#{id}", updated_values.to_json, {'HTTP_AUTHORIZATION'=> encode_credentials('admin', 'admin'), 'CONTENT_TYPE' => 'application/json'}
      last_response.status.should be(201)
      last_response.headers["Location"].should == id
      q = get_sample_by id
      q.category.should == "I love cherry pie."
    end

    it "should allow you to update the person" do 
      id = create_approved_sample
      q = get_sample_by id
      q.person = "Pari"
      updated_values = q.to_hash
      post "#{id}", updated_values.to_json, {'HTTP_AUTHORIZATION'=> encode_credentials('admin', 'admin'), 'CONTENT_TYPE' => 'application/json'}
      last_response.status.should be(201)
      last_response.headers["Location"].should == id
      q = get_sample_by id
      q.person.should == "Pari"
    end

    it "should allow you to update the catchphrase" do 
      id = create_approved_sample
      q = get_sample_by id
      q.catchphrase = "White Chocolate is not chocolate."
      updated_values = q.to_hash
      post "#{id}", updated_values.to_json, {'HTTP_AUTHORIZATION'=> encode_credentials('admin', 'admin'), 'CONTENT_TYPE' => 'application/json'}
      last_response.status.should be(201)
      last_response.headers["Location"].should == id
      q = get_sample_by id
      q.catchphrase.should == "White Chocolate is not chocolate."
    end

    it "should allow you to update multiple attributes at the same time" do 
      id = create_approved_sample
      q = get_sample_by id
      q.catchphrase = "White Chocolate is not chocolate."
      q.person = "Willy Wonka"
      q.category = "Delectable Advice"
      updated_values = q.to_hash
      post "#{id}", updated_values.to_json, {'HTTP_AUTHORIZATION'=> encode_credentials('admin', 'admin'), 'CONTENT_TYPE' => 'application/json'}
      last_response.status.should be(201)
      last_response.headers["Location"].should == id
      q = get_sample_by id
      q.catchphrase.should == "White Chocolate is not chocolate."
      q.person.should == "Willy Wonka"
      q.category.should == "Delectable Advice"
    end
    
  end
end
