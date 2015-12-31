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
require_relative 'topo_bootstrap'
require_relative 'topo_cookbook_upload'

module KnifeTopo
  # knife topo create
  class TopoCreate < KnifeTopo::TopoBootstrap
    deps do
      KnifeTopo::TopoCookbookUpload.load_deps
      Chef::Knife::Bootstrap.load_deps
    end

    banner 'knife topo create TOPOLOGY (options)'

    option(
      :bootstrap,
      long: '--bootstrap',
      description: 'Whether to bootstrap newly created nodes',
      boolean: true
    )

    option(
      :disable_upload,
      long: '--disable-upload',
      description: 'Do not upload topo cookbooks',
      boolean: true
    )

    # Make called command options available
    orig_opts = KnifeTopo::TopoCreate.options
    upload_opts = KnifeTopo::TopoCookbookUpload.options
    merged_opts = (KnifeTopo::TopoBootstrap.options).merge(upload_opts)
    self.options = merged_opts.merge(orig_opts)

    include Chef::Knife::TopologyHelper
    include Chef::Knife::TopologyLoader

    def initialize(args)
      super
      @topo_upload_args  = initialize_cmd_args(
        args,
        ['topo', 'cookbook', 'upload', @name_args[0]]
      )

      # All called commands need to accept union of options
      KnifeTopo::TopoCookbookUpload.options = options
    end

    def bootstrap_msgs
      {
        bootstrapped: 'Bootstrapped %{num} nodes [ %{list} ]',
        skipped: 'Skipped %{num} nodes [ %{list} ] ' \
          'because they had no ssh_host information',
        existed: 'Updated %{num} nodes [ %{list} ] because they ' \
          "already exist.\n"\
          "Specify --overwrite to re-bootstrap existing nodes. \n",
        failed: '%{num} nodes [ %{list} ] failed to bootstrap due to errors'
      }
    end

    def non_bootstrap_msgs
      {
        existed: 'Updated %{num} nodes [ %{list} ]',
        skipped: 'Skipped %{num} nodes [ %{list} ] because they do not exist',
        bootstrapped: 'Unexpected error',
        failed: 'Unexpected error'
      }
    end

    def run
      validate_args
      @topo = create_or_update_topo

      # make sure env and cookbooks are in place
      check_chef_env(@topo.chef_environment) if @topo.chef_environment
      upload_cookbooks(@topo_upload_args) unless config[:disable_upload]

      # update any existing nodes
      nodes = merge_topo_properties(@topo.nodes, @topo)

      nodes.each do |node_data|
        bootstrap_or_update_node(node_data)
      end

      report
    end

    def validate_args
      super
      @bootstrap = config[:bootstrap]
      @msgs = @bootstrap ? bootstrap_msgs : non_bootstrap_msgs
      config[:disable_editing] = true
    end

    def create_or_update_topo
      # Load the topology data & create the topology bag
      topo = load_local_topo_or_exit(@topo_name)
      load_or_create_topo_bag

      # Add topology item to the data bag on the server
      topo.create
      topo
    rescue Net::HTTPServerException => e
      raise unless e.to_s =~ /^409/
      update_topo(topo)
    end

    def update_topo(topo)
      version = topo.topo_version
      to_version_str = " to version #{version}"
      msg = "Topology #{@topo_name} already exists - do you want to " \
        "update it#{to_version_str  if version}"
      ui.confirm(msg, true, false)
      topo.save
      topo
    end

    def bootstrap_or_update_node(node_data)
      node_name = node_data['name']
      if @bootstrap
        update_node(node_data) unless node_bootstrap(node_data)
      else
        if update_node(node_data)
          @results[:existed] << node_name
        else
          @results[:skipped] << node_name
        end
      end
    end
  end
end
