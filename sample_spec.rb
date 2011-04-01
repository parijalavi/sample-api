require 'bundler/setup'
require File.join(File.dirname(__FILE__), "sample")

describe Sample do
  it "should have person, catchphrase, category, insert time, and update time" do
    sample = Sample.create do |q|
      q.person= "person"
      q.catchphrase= "Test catchphrase"
      q.category = "Test Category"
    end
    sample.person.should == "person"
    sample.catchphrase.should == "Test catchphrase"
    sample.category.should == "Test Category"
    (sample.inserted_at > 0).should be_true
    sample.updated_at.should == sample.inserted_at
  end
  
  it "should set approved to false by default" do 
  	sample = Sample.create
  	sample.approved?.should be(false)
  	sample.approved = true
  	sample.approved?.should be(true)
  end
  
  it "should provide a to_hash method for making JSON serialization easy" do
    q = Sample.create
    h = q.to_hash
    h[:person].should be_empty
    h[:catchphrase].should be_empty
    h[:category].should be_empty
    h[:inserted_at].should_not be_nil
    h[:approved].should_not be_nil
    h[:updated_at].should_not be_nil
    h[:inserted_at].should == h[:updated_at]
  end
  
  it "should provide a factory method to create an object from a hash" do
    timestamp = Time.now.to_i

    sample = Sample.from_hash({:person=> "Apple", :catchphrase => "Banana", :category => "Cherry Pie", :inserted_at => timestamp, :updated_at => timestamp, :approved => true})
    sample.person.should == "Apple"
    sample.catchphrase.should == "Banana"
    sample.category.should == "Cherry Pie"
    sample.inserted_at.should == timestamp
    sample.updated_at.should == timestamp
    sample.approved.should be(true)
  end
  
  it "should provide a factory method to create an object from a hash" do
    sample = Sample.from_hash({:person=> "Apple", :catchphrase => "Banana", :category => "Cherry Pie"})
    sample.person.should == "Apple"
    sample.catchphrase.should == "Banana"
    sample.category.should == "Cherry Pie"
    sample.inserted_at.should_not be_nil
    sample.updated_at.should_not be_nil
    sample.inserted_at.should == sample.updated_at
    sample.approved.should be(false)
  end
end
