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
end
