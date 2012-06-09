require 'spec_helper'


describe Utils do
  describe 'process file' do
    it "doesn't throw a nil error'" do
      user = FactoryGirl.create(:user)
      design = FactoryGirl.create(:design, :processed_file_path=>"/tmp/color_test.psd.json")
      design.user = user
      design.save!
      design.parse
      design.generate_markup
    end
  end
end