class TreedModel < ActiveRecord::Base
  has_taxonomy_on :tags, {:treed => [:categories]}
end
