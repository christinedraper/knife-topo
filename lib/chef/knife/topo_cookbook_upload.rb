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
require 'chef/knife/topo/loader'
require 'chef/knife/cookbook_upload' unless defined? Chef::Knife::CookbookUpload

module KnifeTopo
  # knife topo cookbook upload
  class TopoCookbookUpload < Chef::Knife
    deps do
      require 'chef/knife/topo/processor'
    end

    banner 'knife topo cookbook upload TOPOLOGY (options)'

    option(
      :data_bag,
      short: '-D DATA_BAG',
      long: '--data-bag DATA_BAG',
      description: 'The data bag the topologies are stored in'
    )

    # Make called command options available
    self.options = (Chef::Knife::CookbookUpload.options).merge(
      TopoCookbookUpload.options)

    include KnifeTopo::Loader

    def initialize(args)
      super
      @args  = args

      # All called commands need to accept union of options
      Chef::Knife::CookbookUpload.options = options
    end

    def run
      validate_args

      # Load the topology data
      @topo = load_local_topo_or_exit(@topo_name)

      # Run cookbook upload command on the topology cookbook
      @processor = KnifeTopo::Processor.for_topo(@topo)
      @processor.upload_artifacts('cmd' => self, 'cmd_args' => @args)
    end

    def validate_args
      unless @name_args[0]
        show_usage
        ui.fatal('You must specify the name of a topology')
        exit 1
      end
      @topo_name = @name_args[0]
    end
  end
end
