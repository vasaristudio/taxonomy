class TaxonomyMigration < ActiveRecord::Migration
  def self.up
    create_table :tags do |t|
      t.integer :parent_id
      t.integer :lft
      t.integer :rgt
      t.string  :name
      t.string  :context
      t.string  :slug
    end

    create_table :taggings do |t|
      t.references :tag

      # You should make sure that the column created is
      # long enough to store the required class names.
      t.references :taggable, :polymorphic => true
      t.references :tagger, :polymorphic => true

      t.datetime :created_at
    end
    
    add_index :tags, [:parent_id]
    add_index :tags, [:lft, :rgt]
    add_index :tags, :context
    add_index :tags, :slug

    add_index :taggings, :tag_id
    add_index :taggings, [:taggable_id, :taggable_type, :context]
  end

  def self.down
    drop_table :taggings
    drop_table :tags
  end
end
