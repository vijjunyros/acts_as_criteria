module ActsAsCriteria 
  module FormHelper
    def acts_as_criteria_form(method, model, options={})
      case method
        when :simple
          simple(model, options) 
        when :filter
          filter(model, options)
        else
          raise "Unexpected method type: #{method}, use :simple or :filter"          
      end
    end
    
    def simple(model, options)
      multi = model.is_a?(Array) ? true : false
      options[:class]  ||= :search
      options[:method] ||= :get
      if multi == true
        options[:actions] = []
        model.each do |m|          
          options[:actions] << [  m.to_s.pluralize, self.send("search_#{m.to_s.downcase.pluralize}_path") ]
        end
      else
        options[:action] ||= self.send("search_#{model.to_s.downcase.pluralize}_path")
      end      
      options[:label] ||= "Search"
      render :partial => "acts_as_criteria/simple", :locals => { :options => options, :multi => multi, :model => model }
    end
    
    def filter(model, options)      
      filters = model.criteria_options[:filter]      
      
      raise "Unsupported method filter for model #{model.to_s}" if filters.blank?
      
      options[:class]  ||= :search
      options[:method] ||= :get
      options[:action] ||= self.send("search_#{model.to_s.downcase.pluralize}_path")
      options[:label] ||= "Filter"
      
      render :partial => "acts_as_criteria/filter", :locals => { :options => options, :model => model, :columns => filters[:columns].map { |col, val| [ val[:text]||col, col ] }.insert(0, "") }      
    end
    
    def acts_as_criteria_input_operator(col_subtype, col, current_query, col_options)      
      current_match = (current_query.blank? || current_query[col].blank? || current_query[col][:match].blank?) ? "" : current_query[col][:match]
      
      case col_subtype
        when :text then 
          if col_options[:source].blank?  
            opts = [["contains","contains"], ["doesn't contains", "not_contains"], ["begins with","begin"], ["ends with","end"], ["is","is"], ["is not","is_not"]]
          else
            opts = [["contains","contains"], ["doesn't contains", "not_contains"]]
          end            
        when :num, :period then 
          if col_options[:source].blank?
            opts = [["=","eq"], ["<>","ne"], [">","gt"], [">=","ge"], ["<","lt"], ["<=","le"]]
          else
            opts = [["=","eq"], ["<>","ne"]]
          end
        when :bool
          then return ""
        else
          raise "Column subtype not supported: #{col_subtype}"
      end
      select_tag :"query[#{col}][match]", options_for_select(opts, current_match)
    end
    
    def acts_as_criteria_input_field(col_subtype, col, current_query, filter_val)
      size = 32
      unless filter_val.blank?
        current_value = filter_val
      else
        current_value = (current_query.blank? || current_query[col].blank? || current_query[col][:value].blank?) ? "" : current_query[col][:value].first
      end      
      input_name = :"query[#{col}][value][]"
      case col_subtype
        when :text, :num
          then text_field_tag(input_name, current_value, :id => nil, :size => size)
        when :period
          then 
            if self.respond_to? "calendar_date_select_tag"
              calendar_date_select_tag(input_name, current_value, :id => nil, :size => size - 5)
            else
              text_field_tag(input_name, current_value, :id => nil, :size => size)
            end
        when :bool
          then select_tag input_name, options_for_select([["False","0"], ["True","1"]], current_value)
        else
          raise "Column subtype not supported: #{col_subtype}"    
      end
    end
    
    def acts_as_criteria_input_source(col_subtype, col, source, current_query, filter_val)
      unless filter_val.blank?
        current_value = filter_val
      else
        current_value = (current_query.blank? || current_query[col].blank? || current_query[col][:value].blank?) ? "" : current_query[col][:value].first
      end       
      
      options = source.call(options)
      select_tag :"query[#{col}][value][]", options_for_select(options, current_value.to_i)
    end
    
    def acts_as_criteria_set_visibility(type, current_query, options = nil)
      case type
        when :simple then
          # Disabling the simple search input if query active and is not a string (is a filter)
          if current_query.instance_of?(String)
            return false
          else
            return true
          end
        when :filter then
          # Hide the filters form if hidden option is set and active query is not a filter
          if options[:hidden] && !current_query.instance_of?(HashWithIndifferentAccess)
            return "style='display:none;'"
          else
            return ""
          end
        else
          raise "Type not supported: #{type}, use :simple or :filter"
      end
    end
    
    def acts_as_criteria_get_action_link(action, type)
      if type[:text]
        link = type[:text]
      else
        link = image_tag(type[:image])
      end
      link_to_remote link, :url => { :action => :criteria, :id => action }
    end
    
    def acts_as_criteria_is_filter_active(current_query)
      current_query.instance_of?(HashWithIndifferentAccess)
    end

    def acts_as_criteria_select_user_filters(current_user, text = "select existing")
      filters = Filter.find(:all, :conditions => { :user_id => current_user, :asset => controller_name })
      options = filters.map{ |filter| [filter.name, filter.criteria] }.insert(0, text)
      select_tag "criteria_select_filter", options_for_select(options, 0), :onchange => "document.location = '#{send("search_#{controller_name}_path")}?' + this.value"
    end

    def acts_as_criteria_save_user_filter_form(current_user)
      form = []

      form << form_remote_tag(:url => { :action => :criteria, :id => "save_filters" })
      form << hidden_field_tag("user_id", current_user)
      form << text_field_tag("filter_name", nil, :size => 15)
      form << submit_tag("save")

      form.join("\n")
    end
  end
 
end
