class AnalyticsController < ApplicationController
  def index
    centric_view(params[:reset], 'none')
  end
end
