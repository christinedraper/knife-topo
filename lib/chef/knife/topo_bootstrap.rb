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

require_relative 'topology_helper'
require_relative 'topology_update_helper'
require_relative 'topology_loader'
require 'chef/knife/bootstrap'

module KnifeTopo
  # knife topo bootstrap
  class TopoBootstrap < Chef::Knife
    deps do
      Chef::Knife::Bootstrap.load_deps
    end

    banner 'knife topo bootstrap TOPOLOGY (options)'

    option(
      :data_bag,
      short: '-D DATA_BAG',
      long: '--data-bag DATA_BAG',
      description: 'The data bag the topologies are stored in'
    )

    option(
      :overwrite,
      long: '--overwrite',
      description: 'Whether to overwrite existing nodes',
      boolean: true
    )

    # Make the base bootstrap options available on topo bootstrap
    self.options = (Chef::Knife::Bootstrap.options).merge(TopoBootstrap.options)

    include Chef::Knife::TopologyHelper
    include Chef::Knife::TopologyUpdateHelper
    include Chef::Knife::TopologyLoader

    attr_accessor :msgs, :results

    def bootstrap_msgs
      {
        bootstrapped: 'Bootstrapped %{num} nodes [ %{list} ]',
        skipped: 'Skipped %{num} nodes [ %{list} ] ' \
          'because they had no ssh_host information',
        existed: "Skipped %{num} nodes [ %{list} ] because they already exist.\n"\
          "Specify --overwrite to re-bootstrap existing nodes. \n",
        failed: '%{num} nodes [ %{list} ] failed to bootstrap due to errors'
      }
    end

    def initialize(args)
      super
      @bootstrap_args = initialize_cmd_args(args, ['bootstrap', ''])
      @results = { bootstrapped: [], skipped: [], existed: [], failed: [] }
      @msgs = bootstrap_msgs
      @bootstrap = true

      # All called commands need to accept union of options
      Chef::Knife::Bootstrap.options = options
    end

    def run
      validate_args

      # load and bootstrap each node that has a ssh_host
      @topo = load_topo_from_server_or_exit(@topo_name)
      nodes = merge_topo_properties(@topo['nodes'], @topo)
      nodes.each do |node_data|
        node_bootstrap(node_data)
      end

      report
    end

    def validate_args
      unless @name_args[0]
        show_usage
        ui.fatal('You must specify the name of a topology')
        exit 1
      end
      @topo_name = @name_args[0]
    end

    def node_bootstrap(node_data)
      node_name = node_data['name']
      exists = resource_exists?("nodes/#{node_name}")
      if node_data['ssh_host'] && (config[:overwrite] || !exists)
        success = run_bootstrap(node_data, @bootstrap_args, exists)
        state = success ? :bootstrapped : :failed
      else
        state = exists ? :existed : :skipped
      end
      @results[state] << node_name
      success
    end

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

    def setup_bootstrap_args(args, data)
      # We need to remove the --bootstrap option, if it exists
      args -= ['--bootstrap']
      args[1] = data['ssh_host']

      # And set up the node-specific data
      args += ['-N', data['name']] if data['name']
      args += ['-E', data['chef_environment']] if data['chef_environment']
      args += ['--ssh-port', data['ssh_port']] if data['ssh_port']
      args += ['--run-list', data['run_list'].join(',')] if data['run_list']
      args += ['--json-attributes', data['normal'].to_json] if data['normal']
      args
    end

    def delete_client_node(node_name)
      ui.info("Node #{node_name} exists and will be overwritten")
      # delete node first so vault refresh does not pick up existing node
      begin
        rest.delete("nodes/#{node_name}")
        rest.delete("clients/#{node_name}")
      rescue Net::HTTPServerException => e
        raise unless e.response.code == '404'
      end
    end

    # Report is used by create, update and bootstrap commands
    def report
      if @topo['nodes'].length > 0
        report_msg(:bootstrapped, :info, false) if @bootstrap
        report_msg(:skipped, :info, true)
        report_msg(:existed, :info, true)
        report_msg(:failed, :warn, true) if @bootstrap
      else
        ui.info 'No nodes found'
      end
      ui.info("In topology: #{@topo.display_info}")
    end

    def report_msg(state, level, onlyIfNonZero = true)
      nodes = @results[state]
      return if onlyIfNonZero && nodes.length == 0
      ui.send(level, @msgs[state] %
        { num: nodes.length, list: nodes.join(', ') })
    end
  end
end
