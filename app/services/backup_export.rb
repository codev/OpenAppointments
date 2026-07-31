# Writes a timestamped backup pair (plain ODS and a zip holding the ODS plus
# every record picture) into storage/backups and prunes to the newest KEEP
# pairs. Filenames stay on a strict pattern so downloads can be validated.
module BackupExport
  KEEP = 5
  FILENAME = /\A(\d{4}-\d{2}-\d{2}-\d{6})-OpenAppointments\.(ods|zip)\z/

  # Injectable for tests (parallel processes need isolated directories).
  mattr_accessor :dir_override, default: nil

  module_function

  def dir = dir_override || Rails.root.join("storage", "backups")

  def run(now: Time.current)
    FileUtils.mkdir_p(dir)
    stamp = now.strftime("%Y-%m-%d-%H%M%S")
    ods = DataExport.generate

    ods_name = "#{stamp}-OpenAppointments.ods"
    File.binwrite(dir.join(ods_name), ods)

    zip_name = "#{stamp}-OpenAppointments.zip"
    write_zip(dir.join(zip_name), ods)

    prune
    { ods: ods_name, zip: zip_name }
  end

  # Newest first: [{ stamp:, date:, files: { "ods" => name, "zip" => name } }]
  def list
    return [] unless Dir.exist?(dir)

    Dir.children(dir)
       .filter_map { |name| (match = name.match(FILENAME)) && [ name, match ] }
       .group_by { |_name, match| match[1] }
       .map { |stamp, entries|
         { stamp: stamp, date: Time.strptime(stamp, "%Y-%m-%d-%H%M%S"),
           files: entries.to_h { |name, match| [ match[2], name ] } }
       }
       .sort_by { |backup| backup[:stamp] }.reverse
  end

  def valid_name?(name) = name.to_s.match?(FILENAME)

  def prune
    list.drop(KEEP).each do |backup|
      backup[:files].each_value { |name| File.delete(dir.join(name)) }
    end
  end

  def write_zip(path, ods)
    File.delete(path) if File.exist?(path)
    seen = Set.new
    Zip::OutputStream.open(path) do |stream|
      stream.put_next_entry("OpenAppointments.ods")
      stream.write(ods)

      picture_records.each do |record|
        filename = record.picture.filename.to_s
        next if filename.blank? || seen.include?(filename)

        seen << filename
        stream.put_next_entry(filename)
        stream.write(record.picture.download)
      end
    end
  end

  def picture_records
    [ ServiceCategory, Service, User ].flat_map { |klass|
      klass.with_attached_picture.select { |record| record.picture.attached? }
    }
  end
end
