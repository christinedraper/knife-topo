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
require_relative 'topology_loader'
require_relative 'topology_helper'

# only require if not already defined (to prevent warning
# about already initialized constants)
require 'chef/knife/cookbook_upload' unless defined? Chef::Knife::CookbookUpload

module KnifeTopo
  # knife topo cookbook upload
  class TopoCookbookUpload < Chef::Knife
    deps do
      Chef::Knife::CookbookUpload.load_deps
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

    include Chef::Knife::TopologyHelper
    include Chef::Knife::TopologyLoader

    def initialize(args)
      super
      @cookbook_upload_args  = initialize_cmd_args(args, %w(cookbook upload))

      # All called commands need to accept union of options
      Chef::Knife::CookbookUpload.options = options
    end

    def run
      validate_args

      # Load the topology data
      data = load_local_topo_or_exit(@topo_name).raw_data

      # Run cookbook upload command on the topology cookbooks
      cookbooks = data['cookbook_attributes'] || []
      upload_cookbooks(cookbooks)
    end

    def validate_args
      unless @name_args[0]
        show_usage
        ui.fatal('You must specify the name of a topology')
        exit 1
      end
      @topo_name = @name_args[0]
    end

    def upload_cookbooks(cookbook_specs)
      n = []
      pos = 2
      cookbook_specs.each do |entry|
        cb_name = entry['cookbook']
        @cookbook_upload_args[pos] = cb_name unless n.include?(cb_name)
        n << cb_name
        pos += 1
      end
      run_cmd(Chef::Knife::CookbookUpload, @cookbook_upload_args)
      ui.info("Uploaded #{n.length} topology cookbooks [#{n.join(', ')}]")
    end
  end
end
