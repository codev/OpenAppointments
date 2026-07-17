# Session language switcher, port of EA's Localization controller.
class LocalizationController < ApplicationController
  include EmbeddableFrame
  # POST /localization/change_language
  def change_language
    language = params[:language].to_s
    raise ArgumentError, "Invalid language parameter." if language.blank?

    language = language.gsub(/[^a-zA-Z0-9_-]/, "")

    unless Localization.available_languages.include?(language)
      raise ArgumentError, "Translations for the given language does not exist."
    end

    session[:language] = language

    render json: { success: true }
  rescue StandardError => e
    json_exception(e)
  end
end
