module ScrumsHelper
  
  def scrum_pagination(paginator, count=nil, options={})
    page_param = options.delete(:page_param) || :page
    url_param = params.dup
    # don't reuse params if filters are present
    url_param.clear if url_param.has_key?(:set_filter)
    
    html = ''    
    html << link_to_remote(('&#171; ' + l(:label_previous)), 
                            {:update => 'scrum_list',
                             :url => url_param.merge(page_param => paginator.current.previous),
                             :complete => 'window.scrollTo(0,0)'},
                            {:href => url_for(:params => url_param.merge(page_param => paginator.current.previous))}) + ' ' if paginator.current.previous
                            
    html << (pagination_links_each(paginator, options) do |n|
      link_to_remote(n.to_s, 
                      {:url => {:params => url_param.merge(page_param => n)},
                       :update => 'scrum_list',
                       :complete => 'window.scrollTo(0,0)'},
                      {:href => url_for(:params => url_param.merge(page_param => n))})
    end || '')
    
    html << ' ' + link_to_remote((l(:label_next) + ' &#187;'), 
                                 {:update => 'scrum_list',
                                  :url => url_param.merge(page_param => paginator.current.next),
                                  :complete => 'window.scrollTo(0,0)'},
                                 {:href => url_for(:params => url_param.merge(page_param => paginator.current.next))}) if paginator.current.next
    
    unless count.nil?
      html << [" (#{paginator.current.first_item}-#{paginator.current.last_item}/#{count})"].compact.join(' ')
    end
    
    html  
  end #scrum_pagination
  
  def options_for_date_range_select(value)
    options_for_select([[l(:label_this_month), 'current_month'],
                        [l(:label_today), 'today'],
                        [l(:label_yesterday), 'yesterday'],                        
                        [l(:label_this_week), 'current_week'],
                        [l(:label_last_week), 'last_week'],
                        [l(:label_last_n_days, 7), '7_days'],
                        [l(:label_last_month), 'last_month'],
                        [l(:label_last_n_days, 30), '30_days'],
                        [l(:label_this_year), 'current_year']],value)
  end
  
end #ScrumHelper