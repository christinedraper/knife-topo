#
# Author:: Christine Draper (<christine_draper@thirdwaveinsights.com>)
# Copyright:: Copyright (c) 2014 ThirdWave Insights LLC
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/knife'
require_relative 'topo_cookbook_upload'

class Chef
  class Knife
    class TopoUpdate < Chef::Knife

      deps do
        Chef::Knife::TopoCookbookUpload.load_deps
      end

      banner "knife topo update [ TOPOLOGY ] (options)"

      option :data_bag,
      :short => '-D DATA_BAG',
      :long => "--data-bag DATA_BAG",
      :description => "The data bag the topologies are stored in"

      option :disable_upload,
      :long => "--disable-upload",
      :description => "Do not upload topo cookbooks",
      :boolean => true
 
      # Make called command options available
      self.options = Chef::Knife::TopoCookbookUpload.options.merge(self.options)

      def initialize (args)
        super
        @topo_upload_args  = initialize_cmd_args(args, [ 'topo', 'cookbook', 'upload', '' ])

        # All called commands need to accept union of options
        Chef::Knife::TopoCookbookUpload.options = options
      end

      def run

        bag_name = topo_bag_name(config[:data_bag])

        if !@name_args[0]
             ui.confirm("Do you want to update all topologies in the #{bag_name} data bag", true, true)
        end

        topo_name = @name_args[0]
        
        if topo_name
          # update a specific topo
          
          unless current_topo = load_from_server(bag_name, topo_name)
            ui.fatal "Topology #{bag_name}/#{topo_name} does not exist on server - use 'knife topo create' first"
            exit(1)
          end
          
          unless topo = load_from_file(bag_name, topo_name)
            ui.info "No topology found in #{topologies_path}/#{bag_name}/#{topo_name}.json - exiting  without action"
            exit(0)
          end
          
          msg = "Updating topology #{display_name(current_topo)}"
          msg = msg + " to version " + topo['version'] if topo['version']
          ui.info msg

          update_topo(topo)

        else
          # find all topologies from server then update them from file, skipping any that have no file
          ui.info "Updating all topologies in data bag: #{bag_name}"

          unless dbag = load_from_server(bag_name)
            ui.fatal "Data bag #{bag_name} does not exist on server - use 'knife topo create' first"
            exit(1)
          end

          dbag.keys.each do |topo_name|

            topo = load_from_file(bag_name, topo_name)
            if !topo
              # do not update topologies that are not in the local workspace
              ui.info("No topology file found in #{topologies_path}/#{bag_name}/#{topo_name}.json - skipping")
            else
              ui.info("Updating topology #{display_name(topo)}")
              update_topo(topo)
            end
          end
        end
        ui.info "Updates done"
 
      end

      def update_topo(topo)
        topo.save
        @topo_upload_args[3] = topo['name']
        upload_cookbooks(@topo_upload_args) if (!config[:disable_upload]) 

        topo_hash = topo.raw_data
        nodes = merge_topo_properties(topo_hash['nodes'], topo_hash)
        config[:disable_editing] = true
        
        if nodes && nodes.length > 0
          nodes.each do |updates|
            node_name = updates['name']
            node = update_node(updates)
            ui.info "Node #{node_name} does not exist - skipping update" if (!node)
          end
        else
          ui.info "No nodes found for topology #{topo_hash['name']}"
        end
      end

      include Chef::Knife::TopologyHelper
      
    end
  end
end
