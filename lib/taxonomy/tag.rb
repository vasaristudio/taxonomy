require 'iconv' # for slug generation, this should go away
class Tag < ActiveRecord::Base
  attr_accessible :name, :context
  attr_accessor :skip_before_destroy
  
  ### ASSOCIATIONS:
  has_many :taggings, :dependent => :destroy
  
  ### VALIDATIONS:
  validates :name, :presence => true, :uniqueness => {:scope => :context}
  validates :slug, :presence => true, :uniqueness => {:scope => :context}
  
  before_validation :permalize
  before_validation :strip_name
  before_create  :set_default_left_and_right
  before_save    :store_new_parent
  after_save     :move_to_new_parent
  before_destroy :destroy_descendants

  belongs_to :parent, :class_name => self.base_class.to_s,
    :foreign_key => Taxonomy.nested_set_options[:parent_column]
  has_many :children, :class_name => self.base_class.to_s,
    :foreign_key => Taxonomy.nested_set_options[:parent_column], :order => Taxonomy.nested_set_options[:left_column]
                
  # no assignment to structure fields
  [Taxonomy.nested_set_options[:left_column], Taxonomy.nested_set_options[:right_column]].each do |column|
    module_eval <<-"end_eval", __FILE__, __LINE__
      def #{column}=(x)
        raise ActiveRecord::ActiveRecordError, "Unauthorized assignment to #{column}: it's an internal field handled by nested set code, use move_to_* methods instead."
      end
    end_eval
  end
  
  define_callbacks("before_move", "after_move")

  ### NESTED SCOPES
  
  # calling parent_column_name in a where cause makes migrations explode in beta4, probably an AREL bug
  # use :conditions for now
#  scope :roots, where(parent_column_name => nil).order(quote_column_name(Taxonomy.nested_set_options[:left_column]))
  scope :roots, where(Taxonomy.nested_set_options[:parent_column] => nil).order(Taxonomy.nested_set_options[:left_column])
  scope :leaves, where("#{Taxonomy.nested_set_options[:right_column]} - #{Taxonomy.nested_set_options[:left_column]} = 1").order(Taxonomy.nested_set_options[:left_column])
  
  ### TAG SCOPES:
  
  scope :named, lambda { |context, name| 
    where("context = ? AND name LIKE ?", context, name) 
  }
  scope :named_any, lambda { |context, list| 
    where(list.map { |tag| sanitize_sql(["name LIKE ?", tag.to_s]) }.join(" OR ")).where(sanitize_sql(["(context = ?)", context]))
  }
  scope :named_like, lambda { |context, name| 
    where("name LIKE ?", "%#{name}%") 
  }
  scope :named_like_any, lambda { |context, list| 
    where(list.map { |tag| sanitize_sql(["name LIKE ?", "%#{tag.to_s}%"]) }.join(" OR ")).where(sanitize_sql(["(context = ?)", context]))
  }
  
  ### CLASS METHODS:
  
  def self.root
    roots.first
  end
  
  def self.find_context_with_slug!(context, slug)
    ret = self.where(:context => context, :slug => slug).first
    raise ActiveRecord::RecordNotFound if ret.nil?
    ret
  end
  
  def self.find_or_create_with_like_by_name(context, name)
    named_like(context, name).first || create(:context => "#{context.singularize.to_s}", :name => name)
  end
  
  def self.find_or_create_all_with_like_by_name(context, *list)
    list = [list].flatten
    
    return [] if list.empty?
    
    existing_tags = Tag.named_any(context, list).all
    new_tag_names = list.reject { |name| existing_tags.any? { |tag| tag.name.downcase == name.downcase } }
    created_tags  = new_tag_names.map { |name| Tag.create(:context => "#{context.singularize.to_s}", :name => name) }
  
    existing_tags + created_tags    
  end
  
  def self.valid?
    left_and_rights_valid? && no_duplicates_for_columns? && all_roots_valid?
  end
  
  def self.treed_taggings_for(context, options = {})
    self.where("tags.context" => context.to_s.singularize)
  end
  
  def self.left_and_rights_valid?
    self.base_class.joins("LEFT OUTER JOIN #{quoted_table_name} AS parent ON " +
        "#{quoted_table_name}.#{connection.quote_column_name(Taxonomy.nested_set_options[:parent_column])} = parent.#{primary_key}").where(
        "#{quoted_table_name}.#{connection.quote_column_name(Taxonomy.nested_set_options[:left_column])} IS NULL OR " +
        "#{quoted_table_name}.#{connection.quote_column_name(Taxonomy.nested_set_options[:right_column])} IS NULL OR " +
        "#{quoted_table_name}.#{connection.quote_column_name(Taxonomy.nested_set_options[:left_column])} >= " +
          "#{quoted_table_name}.#{connection.quote_column_name(Taxonomy.nested_set_options[:right_column])} OR " +
        "(#{quoted_table_name}.#{connection.quote_column_name(Taxonomy.nested_set_options[:parent_column])} IS NOT NULL AND " +
          "(#{quoted_table_name}.#{connection.quote_column_name(Taxonomy.nested_set_options[:left_column])} <= parent.#{connection.quote_column_name(Taxonomy.nested_set_options[:left_column])} OR " +
          "#{quoted_table_name}.#{connection.quote_column_name(Taxonomy.nested_set_options[:right_column])} >= parent.#{connection.quote_column_name(Taxonomy.nested_set_options[:right_column])}))"
    ).count == 0
  end
  
  def self.no_duplicates_for_columns?
    [connection.quote_column_name(Taxonomy.nested_set_options[:left_column]), connection.quote_column_name(Taxonomy.nested_set_options[:right_column])].all? do |column|
      # No duplicates
      self.base_class.select("#{column}, COUNT(#{column})").group("#{column} HAVING COUNT(#{column}) > 1").first.nil?
    end
  end
  
  def self.all_roots_valid?
    left = right = 0
    roots.all? do |root|
      g_returning(root.left > left && root.right > right) do
        left = root.left
        right = root.right
      end
    end
  end
  
  # Rebuilds the left & rights if unset or invalid.  Also very useful for converting from acts_as_tree.
  def self.rebuild!
    # Don't rebuild a valid tree.
    return true if valid?
    
    scope = lambda{|node|}
    if Taxonomy.nested_set_options[:scope]
      scope = lambda{|node| 
        scope_column_names.inject(""){|str, column_name|
          str << "AND #{connection.quote_column_name(column_name)} = #{connection.quote(node.send(column_name.to_sym))} "
        }
      }
    end
    indices = {}
    
    set_left_and_rights = lambda do |node|
      # set left
      node[Taxonomy.nested_set_options[:left_column]] = indices[scope.call(node)] += 1
      # find
      find(:all, :conditions => ["#{connection.quote_column_name(Taxonomy.nested_set_options[:parent_column])} = ? #{scope.call(node)}", node], :order => "#{connection.quote_column_name(Taxonomy.nested_set_options[:left_column])}, #{connection.quote_column_name(Taxonomy.nested_set_options[:right_column])}, id").each{|n| set_left_and_rights.call(n) }
      # set right
      node[Taxonomy.nested_set_options[:right_column]] = indices[scope.call(node)] += 1    
      node.save!    
    end
                        
    # Find root node(s)
    root_nodes = find(:all, :conditions => "#{connection.quote_column_name(Taxonomy.nested_set_options[:parent_column])} IS NULL", :order => "#{connection.quote_column_name(Taxonomy.nested_set_options[:left_column])}, #{connection.quote_column_name(Taxonomy.nested_set_options[:right_column])}, id").each do |root_node|
      # setup index for this scope
      indices[scope.call(root_node)] ||= 0
      set_left_and_rights.call(root_node)
    end
  end
  
  ### INSTANCE METHODS:
  
  def ==(object)
    super || (object.is_a?(Tag) && name == object.name)
  end
  
  def to_s
    name
  end
  
  def count
    read_attribute(:count).to_i
  end
  
  ### INSTANCE METHODS FOR MOVING ITEMS IN NESTED SET
  
  # Returns true if this is a root node
  def root?
    parent_id.nil?
  end
  # Value of the parent column
  def parent_id
    self[Taxonomy.nested_set_options[:parent_column]]
  end
  
  # Value of the left column
  def left
    self[Taxonomy.nested_set_options[:left_column]]
  end
  
  # Value of the right column
  def right
    self[Taxonomy.nested_set_options[:right_column]]
  end
  
  # Returns the level of this object in the tree
  # root level is 0
  def level
    parent_id.nil? ? 0 : ancestors.count
  end
  
  def leaf?
    !new_record? && right - left == 1
  end
  
  # Returns true is this is a child node
  def child?
    !parent_id.nil?
  end
  
  # Returns the array of all parents and self
  def self_and_ancestors
    self.reload
    nested_set_scope.where("#{self.class.quoted_table_name}.#{connection.quote_column_name(Taxonomy.nested_set_options[:left_column])} <= ? AND #{self.class.quoted_table_name}.#{connection.quote_column_name(Taxonomy.nested_set_options[:right_column])} >= ?", left, right)
  end
  
  # Returns a set of itself and all of its nested children
  def self_and_descendants
    self.reload
    nested_set_scope.where("#{self.class.quoted_table_name}.#{connection.quote_column_name(Taxonomy.nested_set_options[:left_column])} >= ? AND #{self.class.quoted_table_name}.#{connection.quote_column_name(Taxonomy.nested_set_options[:right_column])} <= ?", left, right)
  end
  
  # Returns the scope of all children of the parent, including self
  def self_and_siblings
    # Rails 3, but not really. scoped.where(Taxonomy.nested_set_options[:parent_column] => parent_id)
    nested_set_scope.where(["#{Taxonomy.nested_set_options[:parent_column]} == #{parent_id}"])
  end
  
  # Check if other model is in the same scope
  def same_scope?(other)
    Array(Taxonomy.nested_set_options[:scope]).all? do |attr|
      self.send(attr) == other.send(attr)
    end
  end
  
  # Returns a set of all of its nested children which do not have children  
  def leaves
    descendants.where "#{self.class.quoted_table_name}.#{connection.quote_column_name(Taxonomy.nested_set_options[:right_column])} - #{self.class.quoted_table_name}.#{connection.quote_column_name(Taxonomy.nested_set_options[:left_column])} = 1"
  end

  # Returns a set of all of its children and nested children
  def descendants
    without_self(self_and_descendants) 
  end
  
  # Returns an array of all parents
  def ancestors
    without_self(self_and_ancestors) 
  end
  
  # Returns the array of all children of the parent, except self
  def siblings
    without_self(self_and_siblings)
  end
  
  # Move the node to the child of another node (you can pass id only)
  def move_to_child_of(node)
    move_to node, :child
  end
  
  # Find the first sibling to the left
  def left_sibling
    siblings.where("#{self.class.quoted_table_name}.#{connection.quote_column_name(Taxonomy.nested_set_options[:left_column])} < ?", left).order(
      "#{self.class.quoted_table_name}.#{connection.quote_column_name(Taxonomy.nested_set_options[:left_column])} DESC").first
  end

  # Find the first sibling to the right
  def right_sibling
    siblings.where("#{self.class.quoted_table_name}.#{connection.quote_column_name(Taxonomy.nested_set_options[:left_column])} > ?", left).first
  end
  
  # Move the node to the left of another node (you can pass id only)
  def move_to_left_of(node)
    move_to node, :left
  end
  # Move the node to the left of another node (you can pass id only)
  def move_to_right_of(node)
    move_to node, :right
  end
  # Shorthand method for finding the left sibling and moving to the left of it.
  def move_left
    move_to_left_of left_sibling
  end
  # Shorthand method for finding the right sibling and moving to the right of it.
  def move_right
    move_to_right_of right_sibling
  end
  
  # Move the node to root nodes
  def move_to_root
    move_to nil, :root
  end
  
  def is_descendant_of?(other)
    other.reload
    other.left < self.left && self.left < other.right && same_scope?(other)
  end
  
  def is_or_is_descendant_of?(other)
    other.reload
    other.left <= self.left && self.left < other.right && same_scope?(other)
  end

  def is_ancestor_of?(other)
    self.reload
    self.left < other.left && other.left < self.right && same_scope?(other)
  end
  
  def is_or_is_ancestor_of?(other)
    self.reload
    self.left <= other.left && other.left < self.right && same_scope?(other)
  end
  
  
  def move_possible?(target)
    self != target && # Can't target self
    same_scope?(target) && # can't be in different scopes
    # !(left..right).include?(target.left..target.right) # this needs tested more
    # detect impossible move
    !((left <= target.left && right >= target.left) or (left <= target.right && right >= target.right))
  end

protected

  def permalize
    if (changed.include?(self.name) && !changed.include?(:slug)) || self.slug.nil? || self.slug.blank?
      s = Iconv.iconv('ascii//ignore//translit', 'utf-8', self.name).to_s
      s.gsub!(/\'/, '')   # remove '
      s.gsub!(/\W+/, ' ') # all non-word chars to spaces
      s.strip!            # ohh la la
      s.downcase!         #
      s.gsub!(/\ +/, '-') # spaces to dashes, preferred separator char everywhere
      # self.send("#{self.sluggable_conf[:slug_column]}=", s)
      write_attribute(:slug, s)
    end
  end
  
  def strip_name
    self.name.strip!
  end
  
  def without_self(s)
    s.where("#{self.class.quoted_table_name}.#{self.class.primary_key} != ?", self)
  end
  
  # on creation, set automatically lft and rgt to the end of the tree
  def set_default_left_and_right
    maxright = nested_set_scope.maximum(Taxonomy.nested_set_options[:right_column]) || 0
    # adds the new node to the right of all existing nodes
    self[Taxonomy.nested_set_options[:left_column]] = maxright + 1
    self[Taxonomy.nested_set_options[:right_column]] = maxright + 2
  end
  
  def store_new_parent
    @move_to_new_parent_id = send("#{Taxonomy.nested_set_options[:parent_column]}_changed?") ? parent_id : false
    true # force callback to return true
  end
  
  def move_to_new_parent
    if @move_to_new_parent_id.nil?
      move_to_root
    elsif @move_to_new_parent_id
      move_to_child_of(@move_to_new_parent_id)
    end
  end
  
  # reload left, right, and parent
  def reload_nested_set
    reload(:select => "#{connection.quote_column_name(Taxonomy.nested_set_options[:left_column])}, " +
      "#{connection.quote_column_name(Taxonomy.nested_set_options[:right_column])}, #{connection.quote_column_name(Taxonomy.nested_set_options[:parent_column])}")
  end
  
  # All nested set queries should use this nested_set_scope, which performs finds on
  # the base ActiveRecord class, using the :scope declared in the acts_as_nested_set
  # declaration.
  def nested_set_scope
    self.class.base_class.scoped.order(connection.quote_column_name(Taxonomy.nested_set_options[:left_column])) # options
  end
  
  # Prunes a branch off of the tree, shifting all of the elements on the right
  # back to the left so the counts still work.
  def destroy_descendants
    return if right.nil? || left.nil? || skip_before_destroy
    
    self.class.base_class.transaction do
      if Taxonomy.nested_set_options[:dependent] == :destroy
        descendants.each do |model|
          model.skip_before_destroy = true
          model.destroy
        end
      else
        nested_set_scope.delete_all(
          ["#{connection.quote_column_name(Taxonomy.nested_set_options[:left_column])} > ? AND #{connection.quote_column_name(Taxonomy.nested_set_options[:right_column])} < ?",
            left, right]
        )
      end
      
      # update lefts and rights for remaining nodes
      diff = right - left + 1
      nested_set_scope.update_all(
        ["#{connection.quote_column_name(Taxonomy.nested_set_options[:left_column])} = (#{connection.quote_column_name(Taxonomy.nested_set_options[:left_column])} - ?)", diff],
        ["#{connection.quote_column_name(Taxonomy.nested_set_options[:left_column])} > ?", right]
      )
      nested_set_scope.update_all(
        ["#{connection.quote_column_name(Taxonomy.nested_set_options[:right_column])} = (#{connection.quote_column_name(Taxonomy.nested_set_options[:right_column])} - ?)", diff],
        ["#{connection.quote_column_name(Taxonomy.nested_set_options[:right_column])} > ?", right]
      )
      
      # Don't allow multiple calls to destroy to corrupt the set
      self.skip_before_destroy = true
    end
  end
  
  def move_to(target, position)
    raise ActiveRecord::ActiveRecordError, "You cannot move a new node" if self.new_record?
    return if run_callbacks(:before_move) == false
    transaction do
      if target.is_a? self.class.base_class
        target.reload_nested_set
      elsif position != :root
        # load object if node is not an object
        target = nested_set_scope.find(target)
      end
      self.reload_nested_set
    
      unless position == :root || move_possible?(target)
        raise ActiveRecord::ActiveRecordError, "Impossible move, target node cannot be inside moved tree."
      end
      
      bound = case position
        when :child;  target[Taxonomy.nested_set_options[:right_column]]
        when :left;   target[Taxonomy.nested_set_options[:left_column]]
        when :right;  target[Taxonomy.nested_set_options[:right_column]] + 1
        when :root;   1
        else raise ActiveRecord::ActiveRecordError, "Position should be :child, :left, :right or :root ('#{position}' received)."
      end
    
      if bound > self[Taxonomy.nested_set_options[:right_column]]
        bound = bound - 1
        other_bound = self[Taxonomy.nested_set_options[:right_column]] + 1
      else
        other_bound = self[Taxonomy.nested_set_options[:left_column]] - 1
      end

      # there would be no change
      return if bound == self[Taxonomy.nested_set_options[:right_column]] || bound == self[Taxonomy.nested_set_options[:left_column]]
    
      # we have defined the boundaries of two non-overlapping intervals, 
      # so sorting puts both the intervals and their boundaries in order
      a, b, c, d = [self[Taxonomy.nested_set_options[:left_column]], self[Taxonomy.nested_set_options[:right_column]], bound, other_bound].sort

      new_parent = case position
        when :child;  target.id
        when :root;   nil
        else          target[Taxonomy.nested_set_options[:parent_column]]
      end
      
      self.class.base_class.update_all([
        "#{connection.quote_column_name(Taxonomy.nested_set_options[:left_column])} = CASE " +
          "WHEN #{connection.quote_column_name(Taxonomy.nested_set_options[:left_column])} BETWEEN :a AND :b " +
            "THEN #{connection.quote_column_name(Taxonomy.nested_set_options[:left_column])} + :d - :b " +
          "WHEN #{connection.quote_column_name(Taxonomy.nested_set_options[:left_column])} BETWEEN :c AND :d " +
            "THEN #{connection.quote_column_name(Taxonomy.nested_set_options[:left_column])} + :a - :c " +
          "ELSE #{connection.quote_column_name(Taxonomy.nested_set_options[:left_column])} END, " +
        "#{connection.quote_column_name(Taxonomy.nested_set_options[:right_column])} = CASE " +
          "WHEN #{connection.quote_column_name(Taxonomy.nested_set_options[:right_column])} BETWEEN :a AND :b " +
            "THEN #{connection.quote_column_name(Taxonomy.nested_set_options[:right_column])} + :d - :b " +
          "WHEN #{connection.quote_column_name(Taxonomy.nested_set_options[:right_column])} BETWEEN :c AND :d " +
            "THEN #{connection.quote_column_name(Taxonomy.nested_set_options[:right_column])} + :a - :c " +
          "ELSE #{connection.quote_column_name(Taxonomy.nested_set_options[:right_column])} END, " +
        "#{connection.quote_column_name(Taxonomy.nested_set_options[:parent_column])} = CASE " +
          "WHEN #{self.class.base_class.primary_key} = :id THEN :new_parent " +
          "ELSE #{connection.quote_column_name(Taxonomy.nested_set_options[:parent_column])} END",
        {:a => a, :b => b, :c => c, :d => d, :id => self.id, :new_parent => new_parent}
      ], nested_set_scope.where_values)
    end
    target.reload_nested_set if target
    self.reload_nested_set
    run_callbacks(:after_move)
  end
  
private
  def self.g_returning(value)
    yield(value)
    value
  end

end
