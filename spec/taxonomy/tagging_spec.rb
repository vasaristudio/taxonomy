require File.dirname(__FILE__) + '/../spec_helper'

describe Tagging do
  before(:each) do
    # clean_database!
    @tagging = Tagging.new
  end
  
  it "should not be valid with a invalid tag" do
    @tagging.taggable = TaggableModel.create(:name => "Bob Jones")
    @tagging.tag = Tag.new(:context => "languages", :name => "")

    @tagging.should_not be_valid
    @tagging.errors[:tag_id].should == ["can't be blank"]
  end
  
  it "should not create duplicate taggings" do
    @taggable = TaggableModel.create(:name => "Bob Jones")
    @tag = Tag.create(:context => "lanugages", :name => "awesome")
    
    lambda {
      2.times { Tagging.create(:taggable => @taggable, :tag => @tag) }
    }.should change(Tagging, :count).by(1)
  end
end