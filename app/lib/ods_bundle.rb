# Images zip for the manage-data import: image files the sheets reference by
# filename in their picture columns (an exported backup zip also carries the
# ODS itself, which the import ignores).
module OdsBundle
  module_function

  # Extracts every file entry flat into dir; returns the extracted ODS path
  # when the zip carries one.
  def unpack(path, dir)
    require "zip"
    FileUtils.mkdir_p(dir)
    ods_path = nil
    Zip::File.open(path) do |zip|
      zip.entries.each do |entry|
        next unless entry.file?

        name = File.basename(entry.name)
        next if name.empty? || name.start_with?(".")

        entry.extract(name, destination_directory: dir)
        ods_path ||= File.join(dir, name) if ods_entry?(entry)
      end
    end
    ods_path
  end

  def ods_entry?(entry)
    entry.name.downcase.end_with?(".ods") && !File.basename(entry.name).start_with?(".")
  end
end
