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
require_relative 'topo_cookbook_create'

class Chef
  class Knife
    class TopoImport < Chef::Knife

      deps do
        Chef::Knife::TopoCookbookCreate.load_deps
      end

      banner "knife topo import [ TOPOLOGY_FILE [ TOPOLOGY ... ]] (options)"
      
      option :data_bag,
      :short => '-D DATA_BAG',
      :long => "--data-bag DATA_BAG",
      :description => "The data bag to store the topologies in"

      # Make called command options available
      self.options = Chef::Knife::TopoCookbookCreate.options.merge(self.options)
      
      def initialize (args)
        super
        @topo_cookbook_args = initialize_cmd_args(args, [ 'topo', 'cookbook', '', '' ])

        # All called commands need to accept union of options
        Chef::Knife::TopoCookbookCreate.options = options
      end

      def run
        
        # load data from the topologies file
        topo_file = @name_args[0] || 'topology.json'
        topologies = load_topologies(topo_file)
        bag_name = topo_bag_name(config[:data_bag])
        topo_names = @name_args[1..-1] if @name_args[1]
        
        # make sure the topology bag directory exists
        path = File.join(topologies_path, bag_name)
        FileUtils.mkdir_p(path)

        topologies.each do |topo_data|
        
          topo_name = topo_data['name'] || topo_data['id']
          topo_data['id'] ||= topo_name
          topo_data['name'] ||= topo_name
            
          if (!topo_name)
            ui.error "Could not find a topology name - #{topo_file} does not appear to be a valid topology JSON file"
            exit(1)
          end
          
          # check against specific topology list
          if topo_names
            if topo_names.include?(topo_name)
              topo_names.delete(topo_name)
            else
              next
            end
          end
          
          # write the databag for this topology
          path = File.join(topologies_path, bag_name, topo_name  + '.json')
          File.open(path,"w") do |f|
            f.write(Chef::JSONCompat.to_json_pretty(topo_data))
            f.close()
            ui.info "Created topology data bag in  #{path}"
          end
          
          # run topo cookbook to generate the cookbooks for this topology
          @topo_cookbook_args[2] = topo_name
          @topo_cookbook_args[3] = topo_file
          run_cmd(Chef::Knife::TopoCookbookCreate, @topo_cookbook_args)
          ui.info "Imported topology #{display_name(topo_data)}"
          ui.info("Build information: " + topo_data['buildstamp']) if topo_data['buildstamp']
       
        end
            
        ui.info "Did not find topologies #{topo_names.join(', ')} in the topology json file"  if topo_names && topo_names.length > 0
        ui.info "Import finished"
        
      end
      
      include Chef::Knife::TopologyHelper

    end
  end
end
