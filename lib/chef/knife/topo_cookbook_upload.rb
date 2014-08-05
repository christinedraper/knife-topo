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
require_relative 'topology_helper'

## only require if not already defined (to prevent warning about already initialized constants)
require 'chef/knife/cookbook_upload' if !defined? Chef::Knife::CookbookUpload

class Chef
  class Knife
    class TopoCookbookUpload < Chef::Knife
      
      deps do
        Chef::Knife::CookbookUpload.load_deps
      end

      banner "knife topo cookbook upload [ TOPOLOGY ] (options)"

      option :data_bag,
      :short => '-D DATA_BAG',
      :long => "--data-bag DATA_BAG",
      :description => "The data bag the topologies are stored in"

      # Make called command options available
      self.options = (Chef::Knife::CookbookUpload.options).merge(self.options)

      def initialize (args)
        super
        @topo_upload_args  = initialize_cmd_args(args, [ 'cookbook', 'upload' ])

        # All called commands need to accept union of options
        Chef::Knife::CookbookUpload.options = options
      end
      
      def run
        if !@name_args[0]
          show_usage
          ui.fatal("You must specify the name of a topology")
          exit 1
        end

        bag_name = topo_bag_name(config[:data_bag])
        topo_name = @name_args[0]

        # Load the topology data 
        unless topo = load_from_file(bag_name, topo_name )
          ui.fatal("Topology file #{topologies_path}/#{bag_name}/#{topo_name}.json not found - use 'knife topo import' first")
          exit(1)
        end
        
        # Run cookbook upload command on the topology cookbooks
        cookbook_names = []
        if topo['cookbook_attributes'] && topo['cookbook_attributes'].length > 0
          argPos = 2
          topo['cookbook_attributes'].each do |entry|
            cookbook_name = entry['cookbook']
            @topo_upload_args[argPos] = cookbook_name unless cookbook_names.include?(cookbook_name)
            cookbook_names << cookbook_name  
            argPos += 1
          end
          run_cmd(Chef::Knife::CookbookUpload, @topo_upload_args)
        else
          ui.info("No cookbooks found for topology #{topo_name}")
        end                      
      end

      include Chef::Knife::TopologyHelper

    end
  end
end
