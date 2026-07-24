# ODS spreadsheet support for the manage-data page: a minimal stdlib writer
# (store-only zip) for the export, roo for reading imports.
module Ods
  MIMETYPE = "application/vnd.oasis.opendocument.spreadsheet".freeze

  module_function

  # sheets: ordered {"Sheet name" => [[header, ...], [row, ...], ...]}.
  # Returns the .ods file as a binary string.
  def generate(sheets)
    entries = [
      [ "mimetype", MIMETYPE ],
      [ "META-INF/manifest.xml", manifest_xml ],
      [ "styles.xml", styles_xml ],
      [ "content.xml", content_xml(sheets) ]
    ]
    zip(entries)
  end

  # Parses an .ods file into {"Sheet name" => [[cell, ...], ...]} with string cells.
  def parse(path)
    book = Roo::OpenOffice.new(path, file_warning: :ignore)
    book.sheets.each_with_object({}) do |name, sheets|
      sheet = book.sheet(name)
      sheets[name] =
        if sheet.first_row
          (sheet.first_row..sheet.last_row).map { |index| sheet.row(index).map { |cell| format_cell(cell) } }
        else
          []
        end
    end
  rescue Zip::Error, ArgumentError => e
    raise ArgumentError, "Not an ODS spreadsheet: #{e.message}"
  end

  # Numeric cells come back as floats from roo; the import expects strings.
  def format_cell(value)
    return "" if value.nil?
    return value.to_i.to_s if value.is_a?(Float) && value == value.to_i

    value.to_s
  end

  def content_xml(sheets)
    builder = +<<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
        xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0"
        xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" office:version="1.2">
      <office:body><office:spreadsheet>
    XML
    sheets.each do |name, rows|
      builder << %(<table:table table:name="#{escape(name)}">)
      rows.each do |row|
        builder << "<table:table-row>"
        row.each do |cell|
          builder << %(<table:table-cell office:value-type="string"><text:p>#{escape(cell)}</text:p></table:table-cell>)
        end
        builder << "</table:table-row>"
      end
      builder << "</table:table>"
    end
    builder << "</office:spreadsheet></office:body></office:document-content>"
  end

  def escape(value)
    value.to_s.encode(xml: :text)
  end

  def manifest_xml
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.2">
        <manifest:file-entry manifest:full-path="/" manifest:media-type="#{MIMETYPE}"/>
        <manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>
        <manifest:file-entry manifest:full-path="styles.xml" manifest:media-type="text/xml"/>
      </manifest:manifest>
    XML
  end

  def styles_xml
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <office:document-styles xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" office:version="1.2"/>
    XML
  end

  # Store-only zip writer: mimetype must be first and uncompressed per the spec.
  def zip(entries)
    output = +"".b
    central = +"".b
    entries.each do |name, data|
      data = data.b
      offset = output.bytesize
      crc = Zlib.crc32(data)
      header = [ 0x04034b50, 20, 0, 0, 0, 0x21, crc, data.bytesize, data.bytesize,
                 name.bytesize, 0 ].pack("VvvvvvVVVvv")
      output << header << name << data
      central << [ 0x02014b50, 20, 20, 0, 0, 0, 0x21, crc, data.bytesize, data.bytesize,
                   name.bytesize, 0, 0, 0, 0, 0, offset ].pack("VvvvvvvVVVvvvvvVV")
      central << name
    end
    eocd_offset = output.bytesize
    output << central
    output << [ 0x06054b50, 0, 0, entries.size, entries.size, central.bytesize, eocd_offset, 0 ].pack("VvvvvVVv")
    output
  end
end
