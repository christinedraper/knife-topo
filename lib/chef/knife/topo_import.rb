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
require_relative 'topology_loader'
require_relative 'topo_cookbook_create'

module KnifeTopo
  # knife topo import
  class TopoImport < Chef::Knife
    deps do
      KnifeTopo::TopoCookbookCreate.load_deps
    end

    banner 'knife topo import [ TOPOLOGY_FILE ] (options)'

    option(
      :data_bag,
      short: '-D DATA_BAG',
      long: '--data-bag DATA_BAG',
      description: 'The data bag to store the topologies in'
    )

    # Make called command options available
    orig_opts = KnifeTopo::TopoImport.options
    self.options = KnifeTopo::TopoCookbookCreate.options.merge(orig_opts)

    include Chef::Knife::TopologyHelper
    include Chef::Knife::TopologyLoader

    def initialize(args)
      super
      base_args = ['topo', 'cookbook', 'create', '']
      @topo_cookbook_args = initialize_cmd_args(args, base_args)
      @topo_file = @name_args[0] || 'topology.json'
      @topo_cookbook_args[3] = @topo_file

      # All called commands need to accept union of options
      KnifeTopo::TopoCookbookCreate.options = options
    end

    def run
      # load topology from the topologies file
      @topo = load_topo_from_file_or_exit(@topo_file)
      create_topo_bag_dir
      import_topo
    end

    def create_topo_bag_dir
      # make sure the topology bag directory exists
      path = File.join(topologies_path, topo_bag_name)
      FileUtils.mkdir_p(path)
    end

    def import_topo
      write_topo_to_file
      run_create_cookbook

      ui.info "Imported topology: #{@topo.display_info}"
    end

    def write_topo_to_file
      path = File.join(topologies_path, topo_bag_name, @topo['name'] + '.json')
      File.open(path, 'w') do |f|
        f.write(Chef::JSONCompat.to_json_pretty(@topo.raw_data))
        f.close
        ui.info "Created topology data bag in  #{path}"
      end
    end

    def run_create_cookbook
      # run topo cookbook to generate the cookbooks for this topology
      run_cmd(KnifeTopo::TopoCookbookCreate, @topo_cookbook_args)
    end
  end
end
