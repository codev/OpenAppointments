require "test_helper"

class OdsTest < ActiveSupport::TestCase
  def write(sheets)
    path = Rails.root.join("tmp", "ods-test-#{SecureRandom.hex(4)}.ods").to_s
    File.binwrite(path, Ods.generate(sheets))
    @paths ||= []
    @paths << path
    path
  end

  teardown { Array(@paths).each { |path| FileUtils.rm_f(path) } }

  test "round trips sheets, ragged rows and special characters" do
    sheets = {
      "People" => [ %w[id name notes], [ "7", %(Ada "quoted" & <spécial>), "" ], [ "8", "Bob" ] ],
      "Empty" => []
    }
    parsed = Ods.parse(write(sheets))
    assert_equal [ "People", "Empty" ], parsed.keys
    assert_equal %w[id name notes], parsed["People"].first
    assert_equal [ "7", %(Ada "quoted" & <spécial>) ], parsed["People"][1].first(2)
    assert_equal "8", parsed["People"][2][0]
    assert_equal [], parsed["Empty"]
  end

  test "the file is a valid zip with the ODS mimetype stored first" do
    data = File.binread(write("S" => [ [ "a" ] ]))
    assert data.start_with?("PK")
    assert_equal "mimetype", data[30, 8]
    assert_includes data[0, 100], Ods::MIMETYPE
  end

  test "parses a deflated zip as written by LibreOffice" do
    original = write("Sheet" => [ %w[a b], %w[1 2] ])
    deflated = Rails.root.join("tmp", "ods-test-deflated-#{SecureRandom.hex(4)}.ods").to_s
    @paths << deflated

    require "zip"
    Zip::OutputStream.open(deflated) do |zip|
      Zip::File.open(original) do |source|
        source.each do |entry|
          zip.put_next_entry(entry.name)
          zip.write(entry.get_input_stream.read)
        end
      end
    end

    assert_equal [ %w[a b], %w[1 2] ], Ods.parse(deflated)["Sheet"]
  end

  test "numeric cells from an edited file come back as integer strings" do
    assert_equal "30", Ods.format_cell(30.0)
    assert_equal "12.5", Ods.format_cell(12.5)
    assert_equal "", Ods.format_cell(nil)
  end

  test "a non-ods file raises a clean argument error" do
    path = Rails.root.join("tmp", "ods-test-bogus-#{SecureRandom.hex(4)}.ods").to_s
    (@paths ||= []) << path
    File.write(path, "name,email\na,b@example.org\n")
    error = assert_raises(ArgumentError) { Ods.parse(path) }
    assert_match(/Not an ODS spreadsheet/, error.message)
  end

  test "headers are bold and columns roughly fit their contents" do
    data = Ods.generate("Sheet" => [ %w[name description], [ "ab", "a much longer description cell" ] ])
    content = nil
    Zip::File.open_buffer(StringIO.new(data)) do |zip|
      content = zip.read("content.xml")
    end

    assert_includes content, 'fo:font-weight="bold"'
    header_row = content[/<table:table-row>.*?<\/table:table-row>/m]
    assert_includes header_row, 'table:style-name="bold"'
    data_rows = content.split("</table:table-row>").drop(1).join
    assert_not_includes data_rows, 'table:style-name="bold"'

    widths = content.scan(/style:column-width="([\d.]+)cm"/).flatten.map(&:to_f)
    assert_equal 2, widths.size
    assert_operator widths[1], :>, widths[0]

    # Huge cells clamp instead of producing absurd columns.
    clamped = Ods.generate("Sheet" => [ %w[a], [ "x" * 500 ] ])
    Zip::File.open_buffer(StringIO.new(clamped)) do |zip|
      content = zip.read("content.xml")
    end
    assert_includes content, 'style:column-width="12.0cm"'
  end
end
