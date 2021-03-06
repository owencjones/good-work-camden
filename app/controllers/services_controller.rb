require 'date'

class ServicesController < ApplicationController

  def show
    @template= ""
    #REMEMBER - Step is a string in the URL params so needs quotes or .to_s whenever you assign to it
    @step = "1"
    @errors = Hash.new

    if params[:step].present?
        @step = (params[:step].to_i + 1).to_s
    end

    # Check we have a valid postcode
    if params[:loc].present? then
      postcode = params[:loc].upcase
      @ward = Postcode.where({"postcode3": postcode}).select("wardname").first
      if !@ward then
          @errors["loc"] = "Not a Camden postcode"
          @step = "1"
      end
    end



    @persist = params.except('step')
    
    #Check question pre-requistes have been met
    case @step
      when "3"
        if !params[:sprt].present? then
          @errors["sprt"] = "Support requirements not specified"
          @step = "2"
        end
    end

    #Check DOB is valid
    if params[:dob_day].present? then
      day = params[:dob_day].to_i
      month = params[:dob_month].to_i
      year = params[:dob_year].to_i
      @age = age(day, month, year)
      if (@age < 16) then
        @errors["dob_year"] = "You have told us you are too young to use this service (" + @age.to_s  + ")"
        @step = "4"
      end
      if (@age > 125) then
          @errors["dob_year"] = "You have told us you are over " + @age.to_s + " years old. Please enter the year in the format DD/MM/YYYY."
          @step = "4"
      end
    end

    case @step
      when "2"
        @sprt = params[:sprt].present? ? params[:sprt] : []
        @template = "services/questions/support/"
      when "3"
        @employ = params[:emp].present? ? params[:emp] : []
        @house = params[:hou].present? ? params[:hou] : []
        @template = "services/questions/about_you/"
      when "4"
        @template = "services/questions/additional/"
      when "5"
        @template = "services/questions/type/"
      when "6"
        case params[:type]
          when "adviser"
            @template = "services/adviser/"
          when "search"
            @filters = []
            
            # ADD SUPPORT TO FILTERS
            if params[:sprt].present? then
              f = params[:sprt].split(' ')
              f.each do |s|
                @filters.append(s)
              end
            end

            # ADD GENDER TO FILTERS
            if params[:gender].present? then
                @filters.append(params[:gender])
            end
            # ADD ETHNICITY TO FILTERS
            if params[:ethnic].present? then
                @filters.append(params[:ethnic])
            end
            # ADD EMPLOYMENT TO FILTERS
            if params[:emp].present? then
              f = params[:emp].split(' ')
              f.each do |s|
                @filters.append(s)
              end
            end
            # ADD HOUSING TO FILTERS
            if params[:hou].present? then
              f = params[:hou].split(' ')
              f.each do |s|
                @filters.append(s)
              end
            end
            @excludes = Service.joins(:tags).where({"tags.tag": @filters, "service_tags.excluded": 1}).distinct
            @services = Service.joins(:tags).where.not({"id": @excludes.ids}).distinct.limit(5)
            reset_session
            session[:services] = @services
            @template = "services/list/"
        end  
      else
        @template = "services/questions/location/"
    end

    render template: @template

  end

  def thankyou
    email1 = Mailer.with(user: params).adviser_email.deliver_now
    email2 = Mailer.with(user: params).adviser_confirmation_email.deliver_now
    render template: "services/thankyou"
  end 

  def emailresults
    services = session[:services]
    email = Mailer.with(user: params, services: services).results_email.deliver_now
    render template: "services/complete"
  end 

  def details
    if params[:id].present?
      @id = params[:id]
      @service = Service.find(@id)
      render template: "services/details/"
    else
      redirect_to :action=>'show'
    end
  end

  def age(day, month, year)
      now = Time.now.utc.to_date
      return now.year - year - ((now.month > month || (now.month == month && now.day >= day)) ? 0 : 1)
  end

end
