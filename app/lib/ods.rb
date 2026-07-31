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
  rescue StandardError => e
    # rubyzip is loaded lazily by roo, so Zip::Error cannot be referenced here.
    raise ArgumentError, "Not an ODS spreadsheet: #{e.message}"
  end

  # Numeric cells come back as floats from roo; the import expects strings.
  def format_cell(value)
    return "" if value.nil?
    return value.to_i.to_s if value.is_a?(Float) && value == value.to_i

    value.to_s
  end

  def content_xml(sheets)
    widths = sheets.map { |_name, rows| column_widths(rows) }
    builder = +<<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
        xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0"
        xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
        xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0"
        xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0" office:version="1.2">
      <office:automatic-styles>
      <style:style style:name="bold" style:family="table-cell"><style:text-properties fo:font-weight="bold"/></style:style>
    XML
    widths.each_with_index do |sheet_widths, sheet_index|
      sheet_widths.each_with_index do |width, column_index|
        builder << %(<style:style style:name="co-#{sheet_index}-#{column_index}" style:family="table-column">) <<
                   %(<style:table-column-properties style:column-width="#{width}cm"/></style:style>)
      end
    end
    builder << "</office:automatic-styles><office:body><office:spreadsheet>"
    sheets.each_with_index do |(name, rows), sheet_index|
      builder << %(<table:table table:name="#{escape(name)}">)
      widths[sheet_index].each_index do |column_index|
        builder << %(<table:table-column table:style-name="co-#{sheet_index}-#{column_index}"/>)
      end
      rows.each_with_index do |row, row_index|
        builder << "<table:table-row>"
        cell_style = row_index.zero? ? %( table:style-name="bold") : ""
        row.each do |cell|
          builder << %(<table:table-cell#{cell_style} office:value-type="string"><text:p>#{escape(cell)}</text:p></table:table-cell>)
        end
        builder << "</table:table-row>"
      end
      builder << "</table:table>"
    end
    builder << "</office:spreadsheet></office:body></office:document-content>"
  end

  # Rough fit: ~0.19cm per character of the longest cell, clamped so huge
  # values (working plans, settings blobs) do not produce absurd columns.
  def column_widths(rows)
    (0...rows.map(&:length).max.to_i).map do |index|
      chars = rows.map { |row| row[index].to_s.length }.max.to_i
      ((1.0 + chars * 0.19).clamp(1.8, 12.0)).round(2)
    end
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
