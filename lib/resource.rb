class Resource

  def self.resource_path(request_path)
    # get the resource parameters if it is rails
    if defined?(Rails)
      resource = Rails.application.routes.recognize_path(request_path)
      #Firetail.logger.debug "res: #{resource}"
      # sample hash of the above resource:
      # example url: /posts/1/comments/2/options/3
      # hash = {:controller=>"options", :action=>"show", :comment_id => 3, :post_id=>"1", :id=>"1"}
      # take the resource hash above, get keys, conver to string, split "_" to get name at first index, together
      # with the key, to string and camelcase route id name and keys that only include "id", compact (remove nil) and add "s" to the key
      rmap = resource.map {|k,v| [k.to_s.split("_")[0], "{#{k.to_s.camelize(:lower)}}"] if k.to_s.include? "id" }
      .compact.map {|k,v| [k.to_s + "s", v] if k != "id" }

      if resource.key? :id
          # It will appear like: [["comments", "commentId"], ["posts", "postId"], ["id", "id"]], 
          # but we want post to be first in order, so we reverse sort, and drop "id", which will be first in array
          # after being sorted
          reverse_resource = rmap.reverse.drop(1)
          resource_path = "/" + reverse_resource * "/" + "/" + resource[:controller] + "/" + "{id}"
          # rebuild the resource path
          # reverse_resource * "/" will loop the array and add "/"
          #resource_path = "/" + reverse_resource * "/" + "/" + resource[:controller] + "/" + "{id}"
          # end result is /posts/{postId}/comments/{commentId}/options/{id}
      else
        if rmap.empty?
          # if resoruce is empty, means we are at the first level of the url path, so no need extra paths
          resource_path = "/" + rmap * "/" + resource[:controller]
        else
          # resource path from rmap above without the [:id] key (which is the last parameter in URL)
          # only used for index, create which does not have id
          resource_path = "/" + rmap * "/" + "/" + resource[:controller]
        end
      end
    else
      resource_path = nil
    end
  end
end
