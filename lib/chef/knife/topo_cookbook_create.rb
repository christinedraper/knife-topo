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

require 'chef/knife/topo/loader'
require 'chef/knife/cookbook_create'

module KnifeTopo
  # knife topo cookbook create
  class TopoCookbookCreate < Chef::Knife
    deps do
      require 'chef/knife/topo/processor'
    end

    banner 'knife topo cookbook create TOPOLOGY_FILE (options)'

    option(
      :data_bag,
      short: '-D DATA_BAG',
      long: '--data-bag DATA_BAG',
      description: 'The data bag the topologies are stored in'
    )

    # Make the base cookbook create options available on topo cookbook
    self.options = Chef::Knife::CookbookCreate.options.merge(
      TopoCookbookCreate.options)

    include KnifeTopo::Loader

    def initialize(args)
      super
      @args  = args
    end

    def run
      validate_args

      @topo = load_topo_from_file_or_exit(@topo_file)
      @processor = KnifeTopo::Processor.for_topo(@topo)
      do_create_artifacts
    end

    def validate_args
      unless @name_args[0]
        show_usage
        ui.fatal('You must specify a topology JSON file')
        exit 1
      end
      @topo_file = @name_args[0]
    end

    def do_create_artifacts
      @processor.generate_artifacts(
        'cmd_args' => @args,
        'cmd' => self
      )
    end
  end
end
