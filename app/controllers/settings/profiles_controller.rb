# frozen_string_literal: true

class Settings::ProfilesController < Settings::BaseController
  include ObfuscateFilename

  before_action :set_account

  obfuscate_filename [:account, :avatar]
  obfuscate_filename [:account, :header]

  def show
    @account.build_fields
  end

  def update
    Rails.cache.delete("formatted_account:#{@account.id}")

    if UpdateAccountService.new.call(@account, account_params)
      ActivityPub::UpdateDistributionWorker.perform_async(@account.id)
      redirect_to settings_profile_path, notice: I18n.t('generic.changes_saved_msg')
    else
      @account.build_fields
      render :show
    end
  end

  private

  def account_params
    params.require(:account).permit(:display_name, :note, :avatar, :header, :replies, :locked, :hidden, :unlisted, :block_anon, :gently, :kobold, :adult_content, :bot, :discoverable, :filter_undescribed, fields_attributes: [:name, :value])
  end

  def set_account
    @account = current_account
  end
end
