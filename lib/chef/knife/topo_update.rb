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
require 'chef/knife/topo_create'

module KnifeTopo
  # knife topo update
  class TopoUpdate < KnifeTopo::TopoCreate
    deps do
      KnifeTopo::TopoCreate.load_deps
    end
    banner 'knife topo update TOPOLOGY (options)'

    # Make called command options available
    orig_opts = KnifeTopo::TopoCreate.options
    bootstrap_opts = KnifeTopo::TopoBootstrap.options
    self.options = bootstrap_opts.merge(orig_opts)

    def run
      validate_args
      load_topo_from_server_or_exit(@topo_name)
      update_topo

      check_chef_env(@topo['chef_environment'])
      upload_artifacts unless config[:disable_upload]
      update_nodes

      report
    end

    def update_topo
      # Load the topology data & update the topology bag
      @topo = load_local_topo_or_exit(@topo_name)
      @topo.save
    end
  end
end
