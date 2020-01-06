class ApplicationController < ActionController::Base
  require 'yaml'
  after_action :usage_analytics
  SYMB = %w[AND OR = > < >= <= ( )].freeze
  OPR = %w[= > < >= <=].freeze


  def usage_analytics
    report_dict = YAML.load(File.read("#{Rails.root}/reportnames.yml"))
    ssouser_name = request.headers['HTTP_USERNAME']
    ssouser_email = request.headers['HTTP_USEREMAIL']
    ssouser_groups = request.headers['HTTP_USERGROUPS']
    controller = self.controller_name.singularize.camelize
    dated_on = Date.today
    started_at = Time.now
    count = 1
    report_name = report_dict[controller] + (action_name == 'api' ? ' API' : '')
    analytic_record = Analytic.find_by(tool_user: ssouser_name, controller: controller, action: action_name, dated: dated_on)
    if analytic_record
      analytic_record.count += 1
      analytic_record.save
    else
      Analytic.create(tool_user: ssouser_name, controller: controller, action: action_name,
                      report: report_name, started: started_at, count: count, dated: dated_on,
                      email: ssouser_email, groups: ssouser_groups)
    end
  end

  def api
    sql_params = []
    filters = ''
    sql_params_v = []
    oci_a = []
    params_cond = case
    when subset_params.key?('api_filters')
      oci = subset_params[:api_filters]
      oci.split(/'/).collect(&:strip).each {|i|
        if i.match? Regexp.union(SYMB)
          i = i.gsub(/\s+/, '')
          while !i.empty?
            first_sym = SYMB.map { |sym| [sym, i.index(sym)] }.to_h.compact.sort_by {|_k, v| v}.to_h.keys.first
            oci_a << i.partition(first_sym).first unless first_sym.nil? || i.partition(first_sym).first.to_s.strip.empty?
            if first_sym.nil?
              oci_a << i
              i = ''
            else
              oci_a << first_sym
              i = i.partition(first_sym).last
            end
          end
        else
          oci_a << i
        end
      }
      while oci_a.length > 1
        not_sym = true
        first_ind = OPR.map {|i| oci_a.index(i)}.compact.sort!.first
        filters += " #{oci_a[0..first_ind-1].map(&:to_s).join(' ')}"
        case
        when (oci_a[first_ind + 1].match? Regexp.union(SYMB))
          filters << " #{oci_a[first_ind]}#{oci_a[first_ind + 1]} ?"
          sql_params_v << oci_a[first_ind + 2]
          not_sym = false
        when oci_a[first_ind + 1].include?('*')
          filters << ' LIKE ?'
          sql_params_v << oci_a[first_ind + 1].gsub!('*', '%')
        else
          filters << " #{oci_a[first_ind]} ?"
          sql_params_v << oci_a[first_ind + 1]
        end
        oci_a = oci_a[(first_ind + (not_sym ? 2 : 3))..-1]
      end
      filters << ' )' if oci_a[0] == ')'
      sql_params << filters
      (sql_params << sql_params_v).flatten!
      sql_params
    when subset_params.values.first.to_s.include?('*')
      subset_params.each {|k, v| filters = filters + " #{k} LIKE ? AND"}
      filters = filters[0...filters.rindex(' ')]
      sql_params << filters
      subset_params.each {|k, v| v.include?('*') ? sql_params << v.gsub!('*', '%') : sql_params << v}
      sql_params
    else
      subset_params
    end
    render json: @datarest = self.controller_name.singularize.camelize.constantize.where(params_cond)
  rescue
    render json: {'Error Message': "Invalid filter params passed. Filter params should belong to report's json hash keys."}
  end

  protected

  def subset_params
    params.key?(self.controller_name.singularize) ? params.fetch(self.controller_name.singularize.to_sym, {}).permit! : params.except(:controller, :action).permit!
  end

end
