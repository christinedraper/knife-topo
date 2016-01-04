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

require 'chef/knife/topo/bootstrap_helper'
require 'chef/knife/topo/loader'
require 'chef/knife/bootstrap'

module KnifeTopo
  # knife topo bootstrap
  class TopoBootstrap < Chef::Knife
    deps do
      require 'chef/knife/topo/processor'
    end

    include KnifeTopo::BootstrapHelper
    include KnifeTopo::Loader

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

    attr_accessor :msgs, :results

    def bootstrap_msgs
      {
        bootstrapped: 'Bootstrapped %{num} nodes [ %{list} ]',
        skipped: 'Unexpected error',
        skipped_ssh: 'Did not bootstrap %{num} nodes [ %{list} ] ' \
          'because they do not have an ssh_host',
        existed: 'Did not bootstrap %{num} nodes [ %{list} ] because '\
          "they already exist.\n"\
          "Specify --overwrite to re-bootstrap existing nodes. \n",
        failed: '%{num} nodes [ %{list} ] failed to bootstrap due to errors'
      }
    end

    def initialize(args)
      super
      @bootstrap_args = initialize_cmd_args(args, name_args, ['bootstrap', ''])
      @results = {
        bootstrapped: [], skipped: [], skipped_ssh: [], existed: [], failed: []
      }
      @msgs = bootstrap_msgs
      @bootstrap = true

      # All called commands need to accept union of options
      Chef::Knife::Bootstrap.options = options
    end

    def run
      validate_args

      # load and bootstrap each node that has a ssh_host
      @topo = load_topo_from_server_or_exit(@topo_name)
      @processor = KnifeTopo::Processor.for_topo(@topo)
      nodes = @processor.generate_nodes
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

    # rubocop:disable Metrics/MethodLength
    def node_bootstrap(node_data)
      node_name = node_data['name']
      state = :skipped_ssh
      if node_data['ssh_host']
        exists = resource_exists?("nodes/#{node_name}")
        if config[:overwrite] || !exists
          success = run_bootstrap(node_data, @bootstrap_args, exists)
          state = success ? :bootstrapped : :failed
        else
          state = :existed
        end
      end
      @results[state] << node_name
      success
    end
    # rubocop:enable Metrics/MethodLength

    # Report is used by create, update and bootstrap commands
    def report
      if @topo['nodes'].length > 0
        report_msg(:bootstrapped, :info, false) if @bootstrap
        report_msg(:skipped, :info, true)
        report_msg(:skipped_ssh, :info, true)
        report_msg(:existed, :info, true)
        report_msg(:failed, :warn, true) if @bootstrap
      else
        ui.info 'No nodes found'
      end
      ui.info("Topology: #{@topo.display_info}")
    end

    def report_msg(state, level, only_non_zero = true)
      nodes = @results[state]
      return if only_non_zero && nodes.length == 0
      ui.send(level, @msgs[state] %
        { num: nodes.length, list: nodes.join(', ') })
    end
  end
end
