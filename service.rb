require "rubygems"
require 'bundler/setup'

require File.join(File.dirname(__FILE__), "sample")
require File.join(File.dirname(__FILE__), "helpers")
require "sinatra"
require "mongo"
require "json"
require "crack"
require "uri"

helpers Helpers

configure :development do
  set :username, "admin"
  set :password, "admin"
  set :hostname, "http://localhost"
  set :db_string, Helpers.db_string(:development)
  set :mongo_db, Proc.new { Mongo::Connection.new.db(db_string) }
end

configure :test do
  set :username, "admin"
  set :password, "admin"
  set :hostname, ""
  set :db_string, Helpers.db_string(:test)
  set :mongo_db, Proc.new { Mongo::Connection.new.db(db_string) }
end

configure :production do
  #username/password are API credentials
  set :username, "sharp"
  set :password, "moon"
  set :hostname, "http://sharp-moon-211.heroku.com"
  set :db_string, Helpers.db_string(:production)
  set :mongo_db, Helpers.production_connection
end

before do
  @samples_collection = (settings.mongo_db).collection("samples") 
end

get "/" do
  erb :index
end

get "/sample/id/:sample_id" do
  validate_sample_id_correct_format
  
  content_type :json
  sample = @samples_collection.find_one(:_id => BSON::ObjectId(sample_id))
  if sample.nil?
    halt(404, "No sample with matching ID found.")
  elsif !sample["approved"]
    halt(400, "sample has not been approved.")
  else
    status(200)
    sample.to_json  
  end
end

get "/unapproved/:number_of_samples" do
  content_type :json
  limit_max = params[:number_of_samples].to_i
  unless limit_max < 1 
    find_by_approved_query = {"approved" => false}
    samples_found = @samples_collection.find(find_by_approved_query).limit(limit_max).map {|being_very_good| being_very_good } 
    {"samples" => samples_found}.to_json
  else
    halt(400)
  end
  
end

post "/sample/id/:sample_id" do
  protected!
  validate_sample_id_correct_format
  
  status(201)
  sample = {"_id" => BSON::ObjectId(sample_id)}
  values = parse_body_to_json
  values["updated_at"] = Time.now.to_i
  @samples_collection.update(sample, {"$set" => values})
  response["Location"] = settings.hostname + "/sample/id/" + sample_id
end

delete "/sample/id/:sample_id" do
  protected!
  validate_sample_id_correct_format
  status(200)
  sample = {:_id => BSON::ObjectId(sample_id)}
  @samples_collection.remove(sample)
end

post "/sample" do
  protected!
  q = parse_body_to_json
  validate_required_params_present_for_new_sample(q) 
  status(201)
  set_creation_times(q)
  r = @samples_collection.insert(q)
  new_sample_id = r.to_s
  response["Location"] = settings.hostname + "/sample/id/" + new_sample_id
  new_sample_id
end

post "/unapproved" do
  protected!
  if (request.media_type == "application/json") 
    status(201)
    samples_hash = parse_body_to_json
    samples_hash["samples"].each {|sample| @samples_collection.insert(Sample.from_hash(sample).to_hash)}
    nil
  else
    halt(400, "No media type specified")
  end 
end

