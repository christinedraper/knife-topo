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

require 'chef/rest'
require 'chef/knife/topo/command_helper'

module KnifeTopo
  # Node update helper for knife topo
  module BootstrapHelper
    include KnifeTopo::CommandHelper

    # Setup the bootstrap args and run the bootstrap command
    def run_bootstrap(data, bootstrap_args, overwrite = false)
      node_name = data['name']
      args = setup_bootstrap_args(bootstrap_args, data)
      delete_client_node(node_name) if overwrite

      ui.info "Bootstrapping node #{node_name}"
      run_cmd(Chef::Knife::Bootstrap, args)
    rescue StandardError => e
      raise if Chef::Config[:verbosity] == 2
      ui.warn "bootstrap of node #{node_name} exited with error"
      humanize_exception(e)
      false
    end

    # rubocop:disable Metrics/AbcSize
    def setup_bootstrap_args(args, data)
      # We need to remove the --bootstrap option, if it exists
      args -= ['--bootstrap']
      args[1] = data['ssh_host']

      # And set up the node-specific data but ONLY if defined
      args += ['-N', data['name']] if data['name']
      args += ['-E', data['chef_environment']] if data['chef_environment']
      args += ['--ssh-port', data['ssh_port']] if data['ssh_port']
      args += ['--run-list', data['run_list'].join(',')] if data['run_list']
      attrs = attributes_for_bootstrap(data)
      args += ['--json-attributes', attrs.to_json] unless attrs.empty?
      args
    end
    # rubocop:enable Metrics/AbcSize

    # for bootstrap, attributes have to include tags
    def attributes_for_bootstrap(data)
      attrs = data['normal'] || {}
      attrs['tags'] = data['tags'] if data['tags']
      attrs
    end

    def delete_client_node(node_name)
      ui.info("Node #{node_name} exists and will be overwritten")
      # delete node first so vault refresh does not pick up existing node
      rest.delete("nodes/#{node_name}")
      rest.delete("clients/#{node_name}")
    rescue Net::HTTPServerException => e
      raise unless e.response.code == '404'
    end
  end
end
