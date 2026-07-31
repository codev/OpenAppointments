class ProcessExistingPictures < ActiveRecord::Migration[8.1]
  def up
    PictureBackfill.run if defined?(PictureBackfill)
  end

  def down; end
end
