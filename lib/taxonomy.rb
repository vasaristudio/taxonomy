module Taxonomy
  mattr_accessor :nested_set_options
  @@nested_set_options = { :parent_column => 'parent_id',
                           :left_column => 'lft',
                           :right_column => 'rgt',
                           :dependent => :destroy
                         }

  def self.setup
    yield self
    @@nested_set_options.symbolize_keys!
  end
end

require 'taxonomy/group_helper'
require 'taxonomy/has_taxonomy'
require 'taxonomy/has_tagger'
require 'taxonomy/tag'
require 'taxonomy/tag_list'
require 'taxonomy/tags_helper'
require 'taxonomy/tagging'

ActiveRecord::Base.send :include, ActiveRecord::Acts::Taxonomy
ActiveRecord::Base.send :include, ActiveRecord::Acts::Tagger
ActionView::Base.send :include, TagsHelper if defined?(ActionView::Base)