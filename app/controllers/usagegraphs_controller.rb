class UsagegraphsController < ApplicationController
  require 'csv'

  def index
    session[:chart_period] = params[:chart_period] if params[:chart_period]
    session[:chart_type] = params[:chart_type] if params[:chart_type]
    session[:col_p] = (session[:chart_type] == 'Users' ? (:tool_user) : (:report))
    @date_p = params[:datepicker]
    @datew_p = params[:weekpicker]
    @datemy_p = params[:monthpicker]
    unless @datew_p.to_s.strip.empty?
      @datew_s = @datew_p.partition(':').first
      @datew_e = @datew_p.partition(':').last
    end
    unless @datemy_p.to_s.strip.empty?
      @datem = @datemy_p.partition('-').first
      @datey = @datemy_p.partition('-').last
    end
    @dateqy_p = params[:quarterpicker]
    unless @dateqy_p.to_s.strip.empty?
      @dateq = @dateqy_p.partition('-').first[1].to_i
      @dateq_y = @dateqy_p.partition('-').last.to_i
    end
    @dateyy_p = params[:yearpicker]
    @datec_s = params[:cstartpicker].to_s.split.empty? ? nil : params[:cstartpicker]
    @datec_e = params[:cendpicker].to_s.split.empty? ? nil : params[:cendpicker]

    session[:date_val] = case
                         when !@date_p.to_s.strip.empty?
                           session[:data_src] = Analytic.where(dated: @date_p).group(session[:col_p]).sum(:count)
                           @date_p
                         when !@datew_p.to_s.strip.empty?
                           session[:data_src] = Analytic.where('dated between ? AND ?', @datew_s, @datew_e).group(session[:col_p]).sum(:count)
                           @datew_p
                         when !@datemy_p.to_s.strip.empty?
                           session[:data_src] = Analytic.where('extract(month from dated) = ? AND extract(year  from dated) = ?', @datem, @datey).group(session[:col_p]).sum(:count)
                           @datemy_p
                         when !@dateqy_p.to_s.strip.empty?
                           session[:data_src] = Analytic.by_quarter(@dateq, year: @dateq_y, field: :started).group(session[:col_p]).sum(:count)
                           @dateqy_p
                         when !@dateyy_p.to_s.strip.empty?
                           session[:data_src] = Analytic.where('extract(year  from dated) = ?', @dateyy_p).group(session[:col_p]).sum(:count)
                           @dateyy_p
                         when !@datec_s.to_s.strip.empty? || !@datec_e.to_s.strip.empty?
                           session[:data_src] = Analytic.where('dated between ? AND ?', @datec_s, @datec_e).group(session[:col_p]).sum(:count)
                           "[#{@datec_s} : #{@datec_e}]"
                         else
                           cur_date = session[:date_val]
                           nil
                         end

    respond_to { |format|
      format.html
      format.csv {
        data_csv = CSV.generate { |csv|
          csv << [session[:chart_type], "#{session[:chart_period]} Count"]
          session[:data_src].each { |e| csv << e }
        }    
        send_data data_csv,
                  :type => 'text/csv',
                  :filename => "#{session[:chart_period]}-(#{cur_date})-#{session[:chart_type]}-#{Time.now.to_s}.csv",
                  :disposition => 'attachment'
      }
    }
  end

end

