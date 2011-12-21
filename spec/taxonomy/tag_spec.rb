require File.dirname(__FILE__) + '/../spec_helper'

describe Tag do
  before(:each) do
    clean_database!
    @tag = Tag.new
    @user = TaggableModel.create(:name => "Pablo")
  end
  
  describe "named like any" do
    before(:each) do
      Tag.create(:context => "skills", :name => "awesome")
      Tag.create(:context => "skills", :name => "epic")
    end
    
    it "should find both tags" do
      Tag.named_like_any("skills", ["awesome", "epic"]).should have(2).items
    end
  end
  
  describe "find or create by name" do
    before(:each) do
      @tag.name = "awesome"
      @tag.save
    end
    
    it "should find by name" do
      Tag.find_or_create_with_like_by_name("skills", "awesome").should == @tag
    end
    
    it "should find by name case insensitive" do
      Tag.find_or_create_with_like_by_name("skills", "AWESOME").should == @tag
    end
    
    it "should create by name" do
      lambda {
        Tag.find_or_create_with_like_by_name("skills", "epic")
      }.should change(Tag, :count).by(1)
    end
  end
  
  describe "find or create all by any name" do
    before(:each) do
      @tag.name = "awesome"
      @tag.context = "skills"
      @tag.save
    end
    
    it "should find by name" do
      Tag.find_or_create_all_with_like_by_name("skills", "awesome").should == [@tag]
    end
    
    it "should find by name case insensitive" do
      Tag.find_or_create_all_with_like_by_name("skills", "AWESOME").should == [@tag]
    end
    
    it "should create by name" do
      lambda {
        Tag.find_or_create_all_with_like_by_name("skills", "epic")
      }.should change(Tag, :count).by(1)
    end
    
    it "should find or create by name" do
      lambda {
        Tag.find_or_create_all_with_like_by_name("skills", "awesome", "epic").map(&:name).should == ["awesome", "epic"]
      }.should change(Tag, :count).by(1)      
    end
    
    it "should return an empty array if no tags are specified" do
      Tag.find_or_create_all_with_like_by_name("skills", []).should == []
    end
  end

  it "should require a name" do
    @tag.valid?
    @tag.errors[:name].should == ["can't be blank"]
    @tag.name = "something"
    @tag.valid?
    @tag.errors[:name].should be_blank
  end
  
  it "should equal a tag with the same name" do
    @tag.name = "awesome"
    new_tag = Tag.new(:name => "awesome")
    new_tag.should == @tag
  end
  
  it "should return its name when to_s is called" do
    @tag.name = "cool"
    @tag.to_s.should == "cool"
  end
  
  it "have scope named(context, something)" do
    @tag.name = "cool"
    @tag.context = "foo"
    @tag.save!
    Tag.named('foo', 'cool').should include(@tag)
  end
  
  it "have scope named_like(something)" do
    @tag.name = "cool"
    @tag.context = "foo"
    @tag.save!
    @another_tag = Tag.create!(:context => "foo", :name => "coolip")
    Tag.named_like('foo', 'cool').should include(@tag, @another_tag)
  end
  
  describe "treed tags" do
    before(:each) do
      [TreedModel, Tag, Tagging].each(&:delete_all)
      @taggable = TreedModel.new(:name => "Tyler Durden")
      @taggable.save
    end
    
    it "should respond to treed_taggings_for" do
      Tag.should respond_to(:treed_taggings_for)
    end
    
    it "should have scope named treed_taggings_for(categories)" do
      @tag.name = "foo"
      @tag.save
      @taggable.category_list = "foo, bar"
      @taggable.save
      Tag.treed_taggings_for(:categories).all.should include(@tag)
    end
    
    it "should on creation, set automatically lft and rgt to the end of the tree" do
      t = Tag.create(:name => "Movies")
      t.save
      @taggable.category_list = "FightClub"
      @taggable.save
      t = Tag.find_by_name("FightClub")
      t.lft.should == Tag.maximum(:lft)
      t.rgt.should == Tag.maximum(:rgt)
    end
    
    it "should move to child of" do
      t = Tag.create(:name => "Movies")
      t.save
      @taggable.category_list = "FightClub"
      @taggable.save
      fc = Tag.find_by_name("FightClub")
      fc.move_to_child_of(t.id)
      fc.parent.should == t
    end
    
    it "should find self and descendants" do
      t = Tag.create(:name => "Trees")
      t.save
      f = Tag.create(:name => "Fern")
      f.save
      f.move_to_child_of(t.id)
      t.self_and_descendants.all.should == [t,f]
    end
    
    it "should find descendants" do
      t = Tag.create(:name => "Trees")
      t.save
      f = Tag.create(:name => "Fern")
      f.save
      f.move_to_child_of(t.id)
      t.self_and_descendants.all.should == [t,f]
      t.descendants.all.should == [f]
    end
    
    it "should destroy descendants" do
      t = Tag.create(:name => "Trees")
      t.save
      @taggable.category_list = "Fern"
      @taggable.save
      f = Tag.find_by_name("Fern")
      f.move_to_child_of(t.id)
      t.destroy
      Tag.find_by_name("Fern").should be_nil
    end
    
    it "should find roots and leaves without overlap" do
      t = Tag.create(:name => "Books")
      t.save
      @taggable.category_list = "One, Two"
      @taggable.save
      @taggable.categories.each do |cat|
        cat.move_to_child_of(t.id)
        cat.save
      end
      Tag.leaves.should_not include(t)
    end
    
    it "should find leaves" do
      t = Tag.create(:name => "Books")
      t.save
      @taggable.category_list = "BendersGame"
      @taggable.save
      cat = Tag.find_by_name("BendersGame")
      cat.move_to_child_of(t.id)
      cat.should be_leaf
    end
    
    it "should return child correctly" do
      t = Tag.create(:name => "Games")
      t.save
      @taggable.category_list = "Shooter"
      @taggable.save
      cat = Tag.find_by_name("Shooter")
      cat.move_to_child_of(t.id)
      cat.should be_child
      t.should_not be_child
    end
    
    it "should default to root" do
      t = Tag.create(:name => "Gum")
      t.save
      t.should be_root
    end
    
    it "should find self and ancestors when two deep" do
      r = Tag.create(:name => "Root")
      r.save
      s = Tag.create(:name => "otherRoot")
      s.save
      c = Tag.create(:name => "child")
      c.save
      c.move_to_child_of(r.id)
      c.self_and_ancestors.all.should == [r,c]
    end
    
    it "should find self and siblings with two siblings" do
      root = Tag.create(:name => "root")
      root.save
      l = Tag.create(:name => "left")
      l.save
      r = Tag.create(:name => "right")
      r.save
      l.move_to_child_of(root.id)
      r.move_to_child_of(root.id)
      r.self_and_siblings.all.should == [l,r]
    end
    
    it "should find ancestors with self" do
      root = Tag.create(:name => "root")
      root.save
      child = Tag.create(:name => "child")
      child.save
      child.move_to_child_of(root.id)
      child.self_and_ancestors.all.should == [root, child]
    end
        
    it "should find ancestors without self" do
      root = Tag.create(:name => "root")
      root.save
      child = Tag.create(:name => "child")
      child.save
      child.move_to_child_of(root.id)
      child.ancestors.all.should == [root]
    end
    
    it "should find siblings without self" do
      root = Tag.create(:name => "parent")
      root.save
      l = Tag.create(:name => "child1")
      l.save
      r = Tag.create(:name => "child2")
      r.save
      l.move_to_child_of(root.id)
      r.move_to_child_of(root.id)
      r.siblings.all.should == [l]
      l.siblings.all.should == [r]
    end
    
    it "should find leaf nodes" do
      root = Tag.create(:name => "root")
      root.save
      l = Tag.create(:name => "left")
      l.save
      r = Tag.create(:name => "right")
      r.save
      l.move_to_child_of(root.id)
      r.move_to_child_of(root.id)
      root.leaves.all.should == [l,r]
    end
    
    it "should count level 0" do
      a = Tag.create(:name => "one")
      a.save
      a.level.should == 0
    end
    
    it "should count level 1 and 2" do
      a = Tag.create(:name => "one")
      a.save
      b = Tag.create(:name => "b")
      b.move_to_child_of(a.id)
      c = Tag.create(:name => "c")
      c.move_to_child_of(b.id)
      
      b.level.should == 1
      c.level.should == 2
    end
    
    describe "sibblings" do
      before(:each) do
        root = Tag.create(:name => "root")
        root.save
        @b = Tag.create(:name => "b")
        @b.move_to_child_of(root.id)
        @c = Tag.create(:name => "c")
        @c.move_to_child_of(root.id)
      end
      
      it "left_siblings should find left siblings" do
        @c.left_sibling.should == @b
      end
      
      it "right_siblings should find right siblings" do
        @b.right_sibling.should == @c
      end
      
      it "left_siblings should return nil when no left sibling" do 
        @b.left_sibling.should be_nil
      end
      
      it "right_siblings should return nil when no right sibling" do 
        @c.right_sibling.should be_nil
      end
      
      it "should move right of given tag" do 
        @b.move_to_right_of(@c)
        @b.left_sibling.should == @c
      end
      
      it "should move left of given tag" do 
        @c.move_to_left_of(@b)
        @c.right_sibling.should == @b
      end
      
      it "should move right" do 
        @b.move_right
        @b.left_sibling.should == @c
      end
      
      it "should move left" do 
        @c.move_left
        @c.right_sibling.should == @b
      end
    end
    
    describe "with invalid tree" do
      before(:each) do
        @root = Tag.create(:name => "root")
        @root.save
        @b = Tag.create(:name => "b")
        @b.move_to_child_of(@root.id)
        @c = Tag.create(:name => "c")
        @c.move_to_child_of(@root.id)
        @orphan = Tag.create(:name => "orphan")
        @orphan.save
      end
      it "should not be valid when lft arbitrarily set to zero" do
        Tag.update_all "lft = 0", "id = #{@c.id}" # have to work to break things
        Tag.should_not be_valid
      end
      it "rebuild! should make valid when lft arbitrarily set to zero" do
        Tag.update_all "lft = 0", "id = #{@c.id}" # have to work to break things
        Tag.rebuild!
        Tag.should be_valid
      end
      it "should not be valid when parents wrongly set to nil" do 
        Tag.update_all "parent_id = null", "id = #{@c.id}"
        Tag.should_not be_valid
      end
      it "rebuild! should make valid when parents wrongly set to nil" do
        Tag.update_all "parent_id = null", "id = #{@c.id}"
        Tag.rebuild!
        Tag.should be_valid
      end
    end
    
    describe "" do
      before(:each) do
        @root = Tag.create(:name => "root")
        @root.save
        @b = Tag.create(:name => "b")
        @b.move_to_child_of(@root.id)
        @c = Tag.create(:name => "c")
        @c.move_to_child_of(@root.id)
        @orphan = Tag.create(:name => "orphan")
        @orphan.save
      end
      describe "simple tree" do 
        it "should be letf and right valid" do
          Tag.should be_left_and_rights_valid
        end
        it "should not have duplicates in the left and right columns" do 
          Tag.should be_no_duplicates_for_columns
        end
        it "should have all valid roots" do 
          Tag.should be_all_roots_valid
        end
        it "should be valid" do
          Tag.should be_valid
        end
      end
      describe "descendant" do
        it "is_descendant_of should find descendant" do
          @b.is_descendant_of?(@root).should == true
        end
        
        it "is_descendant_of should not find descendant when its self" do
          @root.is_descendant_of?(@root).should == false
        end
        
        it "is_descendant_of should not find descendant when its orphan" do 
          @orphan.is_descendant_of?(@root).should == false
        end
      
        it "is_or_is_descendant_of should find descendant" do 
          @b.is_or_is_descendant_of?(@root).should == true
        end
      
        it "is_or_is_descendant_of sholud find self" do
          @root.is_or_is_descendant_of?(@root).should == true
        end  
        
        it "is_or_is_descendant_of should not find descendant when its orphan" do 
          @orphan.is_or_is_descendant_of?(@root).should == false
        end
      end
      describe "ancestor" do
        it "is_ancestor_of should find ancestor" do
          @root.is_ancestor_of?(@b).should == true
        end
        
        it "is_ancestor_of should not find ancestor when its an orphan" do
          @orphan.is_ancestor_of?(@root).should == false
        end
        
        it "is_or_is_ancestor_of should find ancestor" do
          @root.is_or_is_ancestor_of?(@b).should == true
        end
        
        it "is_or_is_ancestor_of should not find ancestor when its an orphan" do
          @orphan.is_or_is_ancestor_of?(@root).should == false
        end
        
        it "is_or_is_ancestor_of should find self" do
          @root.is_or_is_ancestor_of?(@root).should == true
        end
      end
    end
  end
  
  describe "without tree" do 
    before(:each) do
      [TaggableModel, Tag, Tagging].each(&:delete_all)
      @taggable = TaggableModel.new(:name => "Bob Jones")
    end
    
    # it "should not add lft, rgt or parent id for untreed contexts" do
    #   fail
    # end
  end
end
