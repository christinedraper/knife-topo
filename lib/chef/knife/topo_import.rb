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
require 'chef/knife/cookbook_create'
require 'chef/knife/topo/command_helper'
require 'chef/knife/topo/loader'

module KnifeTopo
  # knife topo import
  class TopoImport < Chef::Knife
    deps do
      require 'chef/knife/topo/processor'
    end

    banner 'knife topo import [ TOPOLOGY_FILE ] (options)'

    option(
      :data_bag,
      short: '-D DATA_BAG',
      long: '--data-bag DATA_BAG',
      description: 'The data bag to store the topologies in'
    )
    option(
      :input_format,
      long: '--input-format FORMAT',
      description: 'The format to convert from (e.g. topo_v1)'
    )

    # Make called command options available
    orig_opts = KnifeTopo::TopoImport.options
    self.options = Chef::Knife::CookbookCreate.options.merge(orig_opts)

    include KnifeTopo::CommandHelper
    include KnifeTopo::Loader

    def initialize(args)
      super
      @args = args
      @topo_file = @name_args[0] || 'topology.json'
    end

    def run
      @topo = load_topo_from_file_or_exit(@topo_file, config[:input_format])
      @processor = KnifeTopo::Processor.for_topo(@topo)
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
      do_create_artifacts

      ui.info "Imported topology: #{@topo.display_info}"
    end

    def write_topo_to_file
      path = File.join(topologies_path, topo_bag_name, @topo['name'] + '.json')
      File.open(path, 'w') do |f|
        f.write(Chef::JSONCompat.to_json_pretty(@topo.raw_data))
        f.close
        ui.info "Created topology data bag: #{path}"
      end
    end

    def do_create_artifacts
      @processor.generate_artifacts(
        'cmd_args' => @args,
        'cmd' => self
      )
    end
  end
end
