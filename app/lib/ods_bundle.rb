# Zip import bundle: a .zip containing one .ods plus image files that the
# sheets reference by filename in their picture columns. A plain ODS is itself
# a zip but contains no .ods entry, so bundle? tells the two apart.
module OdsBundle
  module_function

  def bundle?(path)
    require "zip"
    Zip::File.open(path) { |zip| zip.entries.any? { |entry| ods_entry?(entry) } }
  rescue StandardError
    false
  end

  # Extracts every file entry flat into dir; returns the extracted ODS path.
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
