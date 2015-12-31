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

require 'chef/topology'
require 'chef/knife/core/object_loader'

class Chef
  class Knife
    # Topology loaders
    module TopologyLoader
      # Loader to get data bag items from file
      def loader
        @loader ||= Knife::Core::ObjectLoader.new(DataBagItem, ui)
      end

      def load_local_topo_or_exit(topo_name)
        topo_file = get_local_topo_path(topo_name)
        load_topo_from_file_or_exit(topo_file)
      end

      def load_topo_from_file_or_exit(filepath)
        unless loader.file_exists_and_is_readable?(filepath)
          msg = "Topology file #{filepath} not found - " \
            "use 'knife topo import' first"
          ui.fatal(msg)
          exit(1)
        end
        data = loader.object_from_file(filepath)
        topo = Chef::Topology.from_json(data)
        topo.data_bag(topo_bag_name)
        topo
      end

      def get_local_topo_path(topo_name)
        File.join(
          Dir.pwd,
          topologies_path,
          topo_bag_name,
          topo_name + '.json'
        )
      end

      def load_topo_from_server(topo_name)
        Chef::Topology.load(topo_bag_name, topo_name)
      rescue Net::HTTPServerException => e
        raise unless e.to_s =~ /^404/
      end

      def load_topo_from_server_or_exit(topo_name)
        topo = load_topo_from_server(topo_name)
        unless topo
          ui.fatal("Topology #{topo_bag_name}/#{@topo_name} does not exist " \
            "on the server - use 'knife topo create' first")
          exit(1)
        end
        topo
      end

      # Name of the topology bag
      def topo_bag_name
        @topo_bag_name ||= config[:data_bag]
        @topo_bag_name ||= 'topologies'
      end

      # Path for the topologies data bags.
      # For now, use the standard data_bags path for our topologies bags
      def topologies_path
        @topologies_path ||= 'data_bags'
      end

      # create the topology data bag
      def load_or_create_topo_bag
        load_topo_bag || create_topo_bag
      end

      def create_topo_bag
        data_bag = Chef::DataBag.new
        data_bag.name(topo_bag_name)
        data_bag.create
        data_bag
      rescue Net::HTTPServerException => e
        raise unless e.to_s =~ /^409/
      end

      def load_topo_bag
        data_bag = Chef::DataBag.load(topo_bag_name)
        data_bag
      rescue Net::HTTPServerException => e
        raise unless e.to_s =~ /^404/
      end
    end
  end
end
