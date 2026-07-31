require "test_helper"

# Images zip import: the ODS references images by filename, the zip carries them.
class OdsBundleTest < ActiveSupport::TestCase
  def build_files(dir)
    require "zip"
    ods = Ods.generate(
      "Service Categories" => [ %w[name description picture],
                                [ "Bundle Cat", "Category text", "picture.png" ] ],
      "Services" => [ %w[name duration price currency category description color attendants_number is_private picture],
                      [ "Bundle Service", 30, 10, "GBP", "Bundle Cat", "Service text", "", 1, "0", "picture.png" ] ],
      "Providers" => [ %w[name email phone_number timezone services working_plan username about services_description picture],
                       [ "Bundle Provider", "bundleprov@example.org", "", "Europe/London", "Bundle Service",
                         "{}", "bundleprov", "About text", "Provided services text", "picture.png" ] ]
    )
    ods_path = File.join(dir, "import.ods")
    File.binwrite(ods_path, ods)
    zip_path = File.join(dir, "images.zip")
    Zip::OutputStream.open(zip_path) do |stream|
      stream.put_next_entry("picture.png")
      stream.write(file_fixture("picture.png").binread)
    end
    [ ods_path, zip_path ]
  end

  test "an ods with a separate images zip imports records, texts and pictures" do
    Dir.mktmpdir do |dir|
      ods_path, zip_path = build_files(dir)
      images_dir = File.join(dir, "unpacked")
      OdsBundle.unpack(zip_path, images_dir)

      data = OdsExtract.new(ods_path).call
      result = TenToEight::Load.new(
        data, phases: %w[categories services providers], create_providers: true, images_dir: images_dir
      ).call
      assert_empty result[:errors]

      category = ServiceCategory.find_by!(name: "Bundle Cat")
      assert_equal "Category text", category.description
      assert category.picture.attached?
      assert category.picture_padded.attached? && category.picture_zoomed.attached?, "import must create both variants"

      service = Service.find_by!(name: "Bundle Service")
      assert_equal "Service text", service.description
      assert service.picture.attached?

      provider = User.providers.find_by!(email: "bundleprov@example.org")
      assert_equal "About text", provider.about
      assert_equal "Provided services text", provider.services_description
      assert provider.picture.attached?
      assert_includes provider.services.map(&:name), "Bundle Service"
    end
  end

  test "the export sheets carry the picture and description columns" do
    sheets = DataExport.sheets
    assert_equal %w[name description picture is_hidden sort_order], sheets["Service Categories"].first
    assert_includes sheets["Services"].first, "picture"
    assert_includes sheets["Providers"].first, "about"
    assert_includes sheets["Providers"].first, "services_description"
    assert_includes sheets["Providers"].first, "picture"
  end
end
