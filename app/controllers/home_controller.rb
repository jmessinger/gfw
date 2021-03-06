class HomeController < ApplicationController
  skip_before_filter :check_terms, :only => [:accept_and_redirect]

  before_filter :load_circles, :validate_url, :only => [:index]

  def index
    @visible = Api::Story.visible.first(3)
    @circles = load_circles
  end

  def accept_and_redirect
    cookies.permanent[ENV['TERMS_COOKIE'].to_sym] = { :value => true, :domain => ENV['GFW_HOST'] }

    redirect_to session[:return_to].nil? ? root_path : session[:return_to]
  end

  private

    def validate_url
      if (params[:basemap].present? && params[:baselayer].present?)
        baselayers = ['loss', 'forma', 'imazon', 'modis', 'fires', 'none']
        basemaps = ['grayscale', 'terrain', 'satellite', 'roads', 'treeheight']

        for i in 1999..2012
          basemaps.push('landsat'+i.to_s)
        end

        redirect_to map_path unless basemaps.include?(params[:basemap]) && baselayers.include?(params[:baselayer])
      end
    end

    def load_circles
      begin
        Rails.cache.fetch "circles", expires_in: 1.day do
          response = Typhoeus.get("https://wri-01.cartodb.com/api/v2/sql?q=WITH%20loss%20as%20(SELECT%20sum(loss_gt_0)%20as%20sum_loss%2C%20(SELECT%20sum(loss_gt_0)%20FROM%20umd%20WHERE%20year%20%3D%202012)%20as%20loss_2012%20FROM%20umd)%2C%20gain%20as%20(SELECT%20sum(umd.gain)%20last_gain%20FROM%20(SELECT%20DISTINCT%20iso%2C%20gain%20FROM%20umd)%20umd)%2C%20forma%20as%20(SELECT%20count(cartodb_id)%20as%20gain%20FROM%20forma_api%20WHERE%20date%20%3E%3D%20(SELECT%20max(date)%20FROM%20forma_api))%2C%20circles%20as%20(SELECT%20unnest(array%5B%27sum_loss%27%2C%20%27loss_2012%27%2C%20%27last_gain%27%2C%20%27gain%27%5D)%20AS%20slug%2C%20unnest(array%5Bsum_loss%2C%20loss_2012%2C%20last_gain%2C%20gain%5D)%20AS%20num%20FROM%20loss%2C%20gain%2C%20forma)%0A%0ASELECT%20*%20FROM%20carrousel%20LEFT%20OUTER%20JOIN%20circles%20ON%20(circles.slug%20%3D%20carrousel.slug)%20WHERE%20published%20IS%20true%20ORDER%20BY%20pos%20ASC", headers: {"Accept" => "application/json"})
          response.success? ? JSON.parse(response.body)['rows'] : nil
        end
      rescue Exception => e
        Rails.logger.error "Error retrieving circles in the Home: #{e}"
      end
    end

end
