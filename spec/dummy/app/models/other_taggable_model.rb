class OtherTaggableModel < ActiveRecord::Base
  has_taxonomy_on :tags, :languages
  has_taxonomy_on :needs, :offerings
end
