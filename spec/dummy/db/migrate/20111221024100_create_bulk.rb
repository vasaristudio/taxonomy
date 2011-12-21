class CreateBulk < ActiveRecord::Migration
  def change
    create_table :taggable_models, :force => true do |t|
      t.string :name
      t.string :type
    end
    create_table :taggable_users, :force => true do |t|
      t.column :name, :string
    end
    create_table :other_taggable_models, :force => true do |t|
      t.column :name, :string
      t.column :type, :string
    end
    create_table :treed_models, :force => true do |t|
      t.string :name
    end
  end
end
