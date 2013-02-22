require 'rho/rhocontroller'
require 'helpers/browser_helper'
require 'helpers/application_helper'
require 'helpers/propertycross_helper'

class PropertyCrossController < Rho::RhoController
  include BrowserHelper
  include ApplicationHelper
  include PropertycrossHelper
  def search_listings
    if has_network?
      place_name = @params['place_name']
      search_property_url =  Rho::RhoConfig.BASE_URL + "?country=uk&pretty=1&action=search_listings&place_name=#{place_name}&page=1&encoding=json&listing_type=buy"
      result = Rho::AsyncHttp.get(:url => search_property_url)
      application_response_code = result["body"]["response"]["application_response_code"]
      if success?(result['status'])
        decide_redirection(application_response_code, result, place_name)
      end
    else
      WebView.execute_js("showError('An error occurred while searching. Please check your network connection and try again.');")
    end
  end

  def search_results_view
    @listings = PropertyCross.find(:all)
  end

  def property_view
    @property_detail = PropertyCross.find(:all, :conditions => {"object"=>  @params['object']}).first
    @property_detail = PropertyCross.find(:all, :conditions => {"guid"=>  @params['object']}).first if @property_detail.nil?
    @favourite = Favourite.find_all_by_guid(@property_detail.guid)
  end

  def add_to_favourite
    property =  PropertyCross.find(:all, :conditions => {"object"=>  @params['object']})
    property.each do |property|
      favourite = Favourite.find_all_by_guid(property.guid)
      create_favourite_property(favourite.size, property)
    end
  end

  def favourities_list
    @favourities_list = Favourite.find(:all)
  end

  def favourite_property_view
    @favourite = Favourite.find_all_by_guid(@params["guid"])
    @property_detail = @favourite.first
  end

  def remove_from_favourite
    Favourite.delete_all(:conditions => {"guid"=> @params['guid']})
  end

  def recent_search_list
    recent_search_result = RecentSearch.find(:all)
    if recent_search_result.size > 0
      recent_search_html = get_recent_search_html(recent_search_result.reverse)
      WebView.execute_js("fillRecentSearch('#{recent_search_html}')")
    end
  end

  def get_my_location
    GeoLocation.set_notification("/app/PropertyCross/get_my_location_callback", "")
  end

  def get_my_location_callback
    if success?(@params['status'])
      GeoLocation.turnoff
      WebView.execute_js("showMyLocation('#{@params['latitude']},#{ @params['longitude']}')")
    end
  end

  def my_location_result
    if has_network?
      search_by_place_url =  Rho::RhoConfig.BASE_URL + "?country=uk&pretty=1&action=search_listings&encoding=json&listing_type=buy&page=1&centre_point=#{@params['place_name']}"
      result = Rho::AsyncHttp.get(:url => search_by_place_url)
      application_response_code = result["body"]["response"]["application_response_code"]
      if success?(result['status'])
        decide_redirection(application_response_code, result, @params['place_name'])
      end
    else
      WebView.execute_js("showError('An error occurred while searching. Please check your network connection and try again.');")
    end
  end

  def more_search_result
    if has_network?
      place_name = @params['place_name']
      base_url  = Rho::RhoConfig.BASE_URL + "?country=uk&pretty=1&action=search_listings&encoding=json&listing_type=buy&page=#{@params['page']}"
      if  place_name.start_with?("coord")
        search_url = base_url + "&centre_point=#{Rho::RhoSupport.url_encode(place_name[6..-1])}"
      else
        search_url =  base_url + "&place_name=#{place_name}"
      end
      result = Rho::AsyncHttp.get(:url => search_url)
      application_response_code = result["body"]["response"]["application_response_code"]
      if success?(result['status'])  &&  valid_search_response?(application_response_code)
        property_list = result["body"]["response"]["listings"]
        create_property_cross(property_list)
        search_result = more_search_result_design(result["body"]["response"]["listings"])
        WebView.execute_js("showMoreSearchResult('#{search_result}');")
      end
    end
  end

  private

  def decide_redirection(application_response_code, result, place_name)
    if valid_search_response?(application_response_code)
      listings = result["body"]["response"]["listings"]
      handle_correct_search_result(listings, result, place_name)
    elsif unknown_internal_error?(application_response_code)
      WebView.execute_js("showError('The location given was not recognised.');")
    elsif ambiguous_misspelled_location?(application_response_code)
      missplet_location_info = misspelled_location(result["body"]["response"] ["locations"])
      WebView.execute_js("misspelledLocation('#{missplet_location_info}')")
    end
  end

  def handle_correct_search_result(listings, result, place_name)
    listings_size = listings.size
    if listings_size > 0
      location = result["body"]["response"] ["locations"][0]['place_name']
      total_number_of_property = result["body"]["response"]["total_results"]
      PropertyCross.delete_all
      create_property_cross(listings)
      handle_recent_search(place_name, total_number_of_property)
      WebView.navigate(url_for(:action => :search_results_view, :controller => :PropertyCross, :query => {:location => location, :total_results => total_number_of_property}))
    else
      WebView.execute_js("showError('There were no properties found for the given location.');")
    end
  end

  def create_property_cross(property_list)
    property_list.each { |property|    PropertyCross.create(property) }
  end

  def handle_recent_search(place_name, count)
    destroy_recent_search_list
    recent_search = RecentSearch.find(:all, :conditions => {"place_name"=> place_name})
    if recent_search.size == 0 && count != 0
      recent_search_hash = {"place_name"=> place_name, "count"=> count}
      RecentSearch.create(recent_search_hash)
    end
  end

  def destroy_recent_search_list
    recent_searchs = RecentSearch.find(:all)
    recent_searchs.first.destroy if recent_searchs.size > 4
  end

  def create_favourite_property(favourite_size, property)
    Favourite.create(property.vars.reject! {|k, v|  [:source_id, :object].include? k }) if favourite_size == 0
  end

end
