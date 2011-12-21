class Tagging < ActiveRecord::Base #:nodoc:
  attr_accessible :tag, :tag_id,
                  :taggable, :taggable_type, :taggable_id,
                  :tagger, :tagger_type, :tagger_id

  belongs_to :tag
  belongs_to :taggable, :polymorphic => true
  belongs_to :tagger, :polymorphic => true
  
  validates :tag_id, :presence => true, :uniqueness => {:scope => [:taggable_type, :taggable_id, :tagger_id, :tagger_type]}
  
end
