require File.dirname(__FILE__) + '/../spec_helper'

describe "Taggable" do
  before(:each) do
    # clean_database!
    @taggable = TaggableModel.new(:name => "Bob Jones")
  end

  it "should have tag types" do
      for type in [:tags, :languages, :skills, :needs, :offerings]
        TaggableModel.tag_types.should include type.to_s
      end
      @taggable.tag_types.should == TaggableModel.tag_types
  end

  it "should have tag_counts_on" do
    TaggableModel.tag_counts_on(:tags).should be_empty

    @taggable.tag_list = ["awesome", "epic"]
    @taggable.save
    
    TaggableModel.tag_counts_on(:tags).length.should == 2
    @taggable.tag_counts_on(:tags).length.should == 2
  end

  it "should be able to create tags" do
    @taggable.skill_list = "ruby, rails, css"
    @taggable.instance_variable_get("@skill_list").instance_of?(Hash).should be_true
    @taggable.instance_variable_get("@skill_list")[nil].instance_of?(TagList).should be_true
    @taggable.save

    Tag.find(:all).size.should == 3
  end

  it "should be able to create tags through the tag list directly" do
    @taggable.tag_list_on(:test).add("hello")
    @taggable.tag_list_cache_on(:test).should_not be_empty
    @taggable.save
    @taggable.save_tags
    @taggable.reload
    @taggable.tag_list_on(:test).should == ["hello"]
  end

  it "should differentiate between contexts" do
    @taggable.skill_list = "ruby, rails, css"
    @taggable.tag_list = "ruby, bob, charlie"
    @taggable.save
    @taggable.reload
    @taggable.skill_list.should include("ruby")
    @taggable.skill_list.should_not include("bob")
  end

  it "should be able to remove tags through list alone" do
    @taggable.skill_list = "ruby, rails, css"
    @taggable.save
    @taggable.reload
    @taggable.should have(3).skills
    @taggable.skill_list = "ruby, rails"
    @taggable.save
    @taggable.reload
    @taggable.should have(2).skills
  end

  it "should be able to find by tag" do
    @taggable.skill_list = "ruby, rails, css"
    @taggable.save
    TaggableModel.find_tagged_with("skill", "ruby").first.should == @taggable
  end

  it "should be able to find by tag with context" do
    @taggable.skill_list = "ruby, rails, css"
    @taggable.tag_list = "bob, charlie"
    @taggable.save
    
    TaggableModel.find_tagged_with("skill", "ruby").first.should == @taggable
    TaggableModel.find_tagged_with("skills", "bob").first.should_not == @taggable
    TaggableModel.find_tagged_with("tags", "bob").first.should == @taggable
  end

  it "should be able to use the tagged_with named scope" do
    @taggable.skill_list = "ruby, rails, css"
    @taggable.tag_list = "bob, charlie"
    @taggable.save
    
    TaggableModel.tagged_with("ruby", :on => :skills).first.should == @taggable
    TaggableModel.tagged_with("ruby, css", :on => :skills).first.should == @taggable
    TaggableModel.tagged_with("ruby, nonexistingtag", :on => :skills).should be_empty
    TaggableModel.tagged_with("bob", :on => :skills).first.should_not == @taggable
    TaggableModel.tagged_with("bob", :on => :tags).first.should == @taggable
  end

  it "should not care about case" do
    bob = TaggableModel.create(:name => "Bob", :tag_list => "ruby")
    frank = TaggableModel.create(:name => "Frank", :tag_list => "Ruby")

    Tag.find(:all).size.should == 1
    TaggableModel.find_tagged_with("tag", "ruby").should == TaggableModel.find_tagged_with("tag", "Ruby")
  end

  it "should be able to get tag counts on model as a whole" do
    bob = TaggableModel.create(:name => "Bob", :tag_list => "ruby, rails, css")
    frank = TaggableModel.create(:name => "Frank", :tag_list => "ruby, rails")
    charlie = TaggableModel.create(:name => "Charlie", :skill_list => "ruby")
    TaggableModel.tag_counts.should_not be_empty
    TaggableModel.skill_counts.should_not be_empty
  end

  it "should be able to get all tag counts on model as whole" do
    bob = TaggableModel.create(:name => "Bob", :tag_list => "ruby, rails, css")
    frank = TaggableModel.create(:name => "Frank", :tag_list => "ruby, rails")
    charlie = TaggableModel.create(:name => "Charlie", :skill_list => "ruby")

    TaggableModel.all_tag_counts.should_not be_empty
    TaggableModel.all_tag_counts[2].count.should == 3 # ruby
  end

  it "should not return read-only records" do
    TaggableModel.create(:name => "Bob", :tag_list => "ruby, rails, css")
    
    TaggableModel.tagged_with("ruby", :on => :tags).first.should_not be_readonly
  end

  it "should be able to get scoped tag counts" do
    bob = TaggableModel.create(:name => "Bob", :tag_list => "ruby, rails, css")
    frank = TaggableModel.create(:name => "Frank", :tag_list => "ruby, rails")
    charlie = TaggableModel.create(:name => "Charlie", :skill_list => "ruby")
    
    TaggableModel.tagged_with("ruby").tag_counts[2].count.should == 2   # ruby
    TaggableModel.tagged_with("ruby").skill_counts.first.count.should == 1 # ruby
  end

  it "should be able to get all scoped tag counts" do
    bob = TaggableModel.create(:name => "Bob", :tag_list => "ruby, rails, css")
    frank = TaggableModel.create(:name => "Frank", :tag_list => "ruby, rails")
    charlie = TaggableModel.create(:name => "Charlie", :skill_list => "ruby")

    TaggableModel.tagged_with("ruby").all_tag_counts[2].count.should == 3 # ruby
  end

  it "should be able to set a custom tag context list" do
    bob = TaggableModel.create(:name => "Bob")
    bob.set_tag_list_on(:rotors, "spinning, jumping")
    bob.tag_list_on(:rotors).should == ["spinning","jumping"]
    bob.save
    bob.reload
    bob.tags_on(:rotors).should_not be_empty
  end

  it "should be able to find tagged" do
    bob = TaggableModel.create(:name => "Bob", :tag_list => "fitter, happier, more productive", :skill_list => "ruby, rails, css")
    frank = TaggableModel.create(:name => "Frank", :tag_list => "weaker, depressed, inefficient", :skill_list => "ruby, rails, css")
    steve = TaggableModel.create(:name => 'Steve', :tag_list => 'fitter, happier, more productive', :skill_list => 'c++, java, ruby')

    TaggableModel.find_tagged_with("skill", "ruby", :order => 'taggable_models.name').should == [bob, frank, steve]
    TaggableModel.find_tagged_with("skill", "ruby, rails", :order => 'taggable_models.name').should == [bob, frank]
    TaggableModel.find_tagged_with("skill", ["ruby", "rails"], :order => 'taggable_models.name').should == [bob, frank]    
  end

  it "should be able to find tagged with any tag" do
    bob = TaggableModel.create(:name => "Bob", :tag_list => "fitter, happier, more productive", :skill_list => "ruby, rails, css")
    frank = TaggableModel.create(:name => "Frank", :tag_list => "weaker, depressed, inefficient", :skill_list => "ruby, rails, css")
    steve = TaggableModel.create(:name => 'Steve', :tag_list => 'fitter, happier, more productive', :skill_list => 'c++, java, ruby')

    TaggableModel.find_tagged_with("tag", ["ruby", "java"], :order => 'taggable_models.name', :any => true).should == [bob, frank, steve]
    TaggableModel.find_tagged_with("tag", ["c++", "fitter"], :order => 'taggable_models.name', :any => true).should == [bob, steve]
    TaggableModel.find_tagged_with("tag", ["depressed", "css"], :order => 'taggable_models.name', :any => true).should == [bob, frank]    
  end

  it "should be able to find tagged on a custom tag context" do
    bob = TaggableModel.create(:name => "Bob")
    bob.set_tag_list_on(:rotors, "spinning, jumping")
    bob.tag_list_on(:rotors).should == ["spinning","jumping"]
    bob.save
    TaggableModel.find_tagged_with("rotors", "spinning").should == [bob]
  end

  it "should be able to use named scopes to chain tag finds" do
    bob = TaggableModel.create(:name => "Bob", :tag_list => "fitter, happier, more productive", :skill_list => "ruby, rails, css")
    frank = TaggableModel.create(:name => "Frank", :tag_list => "weaker, depressed, inefficient", :skill_list => "ruby, rails, css")
    steve = TaggableModel.create(:name => 'Steve', :tag_list => 'fitter, happier, more productive', :skill_list => 'c++, java, python')

    # Let's only find those productive Rails developers
    TaggableModel.tagged_with('rails', :on => :skills, :order => 'taggable_models.name').all.should == [bob, frank]
    TaggableModel.tagged_with('happier', :on => :tags, :order => 'taggable_models.name').all.should == [bob, steve]
    TaggableModel.tagged_with('rails', :on => :skills).tagged_with('happier', :on => :tags).should == [bob]
    TaggableModel.tagged_with('rails', :on => :skills).tagged_with('happier', :on => :tags).should == [bob]
  end

  it "should be able to find tagged with only the matching tags" do
    bob = TaggableModel.create(:name => "Bob", :tag_list => "lazy, happier")
    frank = TaggableModel.create(:name => "Frank", :tag_list => "fitter, happier, inefficient")
    steve = TaggableModel.create(:name => 'Steve', :tag_list => "fitter, happier")

    TaggableModel.find_tagged_with("tags", "fitter, happier", :match_all => true).should == [steve]    
  end

  it "should be able to find tagged with some excluded tags" do
    bob = TaggableModel.create(:name => "Bob", :tag_list => "happier, lazy")
    frank = TaggableModel.create(:name => "Frank", :tag_list => "happier")
    steve = TaggableModel.create(:name => 'Steve', :tag_list => "happier")

    TaggableModel.find_tagged_with("tags", "lazy", :exclude => true).should == [frank, steve]    
  end

  it "should not create duplicate taggings" do
    bob = TaggableModel.create(:name => "Bob")
    lambda {
      bob.tag_list << "happier"
      bob.tag_list << "happier"
      bob.save
    }.should change(Tagging, :count).by(1)
  end
  
  describe "Single Table Inheritance" do
    before do
      [TaggableModel, Tag, Tagging, TaggableUser].each(&:delete_all)
      @taggable = TaggableModel.new(:name => "taggable")
      @inherited_same = InheritingTaggableModel.new(:name => "inherited same")
      @inherited_different = AlteredInheritingTaggableModel.new(:name => "inherited different")
    end

    it "should be able to save tags for inherited models" do
      @inherited_same.tag_list = "bob, kelso"
      @inherited_same.save
      InheritingTaggableModel.find_tagged_with("tag", "bob").first.should == @inherited_same
    end

    it "should find STI tagged models on the superclass" do
      @inherited_same.tag_list = "bob, kelso"
      @inherited_same.save
      TaggableModel.find_tagged_with("tag", "bob").first.should == @inherited_same
    end

    it "should be able to add on contexts only to some subclasses" do
      @inherited_different.part_list = "fork, spoon"
      @inherited_different.save
      InheritingTaggableModel.find_tagged_with("parts", "fork").should be_empty
      AlteredInheritingTaggableModel.find_tagged_with("parts", "fork").first.should == @inherited_different
    end

    it "should have different tag_counts_on for inherited models" do
      @inherited_same.tag_list = "bob, kelso"
      @inherited_same.save!
      @inherited_different.tag_list = "fork, spoon"
      @inherited_different.save!

      InheritingTaggableModel.tag_counts_on(:tags).map(&:name).should == %w(bob kelso)
      AlteredInheritingTaggableModel.tag_counts_on(:tags).map(&:name).should == %w(fork spoon)
      TaggableModel.tag_counts_on(:tags).map(&:name).should == %w(bob fork kelso spoon)
    end
    
    it 'should store same tag without validation conflict' do
      @taggable.tag_list = 'one'
      @taggable.save!
      
      @inherited_same.tag_list = 'one'
      @inherited_same.save!
      
      @inherited_same.update_attributes! :name => 'foo'
    end
  end
end
