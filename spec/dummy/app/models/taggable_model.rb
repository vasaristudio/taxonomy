class TaggableModel < ActiveRecord::Base
  acts_as_taggable
  has_taxonomy_on :languages
  has_taxonomy_on :skills
  has_taxonomy_on :needs, :offerings
end
