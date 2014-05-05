class Tagging < ActiveRecord::Base #:nodoc:
  if Rails::VERSION::MAJOR < 4
    attr_accessible :tag, :tag_id,
                    :taggable, :taggable_type, :taggable_id,
                    :tagger, :tagger_type, :tagger_id
  end

  belongs_to :tag
  belongs_to :taggable, :polymorphic => true
  belongs_to :tagger, :polymorphic => true

  validates :tag_id, :presence => true, :uniqueness => {:scope => [:taggable_type, :taggable_id, :tagger_id, :tagger_type]}

end
