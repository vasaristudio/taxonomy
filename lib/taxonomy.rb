require 'taxonomy/group_helper'
require 'taxonomy/has_taxonomy'
require 'taxonomy/has_tagger'
require 'taxonomy/tag'
require 'taxonomy/tag_list'
require 'taxonomy/tags_helper'
require 'taxonomy/tagging'

module Taxonomy
end

ActiveRecord::Base.send :include, ActiveRecord::Acts::Taxonomy
ActiveRecord::Base.send :include, ActiveRecord::Acts::Tagger
ActionView::Base.send :include, TagsHelper if defined?(ActionView::Base)