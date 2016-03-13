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
require 'chef/knife/topo_bootstrap'
require 'chef/knife/cookbook_upload' unless defined? Chef::Knife::CookbookUpload
require 'chef/knife/topo/loader'
require 'chef/knife/topo/command_helper'
require 'chef/knife/topo/node_update_helper'

module KnifeTopo
  # knife topo create
  class TopoCreate < KnifeTopo::TopoBootstrap
    deps do
      require 'chef/knife/topo/processor'
      KnifeTopo::TopoBootstrap.load_deps
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
    upload_opts = Chef::Knife::CookbookUpload.options
    merged_opts = KnifeTopo::TopoBootstrap.options.merge(upload_opts)
    self.options = merged_opts.merge(orig_opts)

    include KnifeTopo::CommandHelper
    include KnifeTopo::NodeUpdateHelper
    include KnifeTopo::Loader

    def initialize(args)
      super
      @args = args
    end

    def bootstrap_msgs
      msgs = super.dup
      msgs[:existed] = 'Updated but did not bootstrap %{num} existing nodes '\
      "[ %{list} ].\n Specify --overwrite to re-bootstrap existing nodes. \n"
      msgs
    end

    def non_bootstrap_msgs
      {
        existed: 'Applied updates (if any) to %{num} nodes [ %{list} ]',
        skipped_ssh: 'Unexpected error skipped_ssh',
        skipped: 'Skipped %{num} nodes [ %{list} ] because they do not exist',
        bootstrapped: 'Unexpected error bootstrapped',
        failed: 'Unexpected error failed'
      }
    end

    def run
      validate_args
      create_or_update_topo

      # make sure env and cookbooks are in place
      check_chef_env(@topo['chef_environment'])
      upload_artifacts unless config[:disable_upload]
      update_nodes

      report
    end

    def processor
      @processor ||= KnifeTopo::Processor.for_topo(@topo)
    end

    def validate_args
      super
      @bootstrap = config[:bootstrap]
      @msgs = @bootstrap ? bootstrap_msgs : non_bootstrap_msgs
      config[:disable_editing] = true
    end

    def create_or_update_topo
      # Load the topology data & create the topology bag
      @topo = load_local_topo_or_exit(@topo_name)
      create_topo_bag

      # Add topology item to the data bag on the server
      @topo.create
    rescue Net::HTTPServerException => e
      raise unless e.to_s =~ /^409/
      confirm_and_update_topo
    end

    def update_nodes
      nodes = processor.generate_nodes
      merge = @topo.merge_attrs
      nodes.each do |node_data|
        bootstrap_or_update_node(node_data, merge)
      end
    end

    def confirm_and_update_topo
      version = @topo.topo_version
      to_version_str = " to version #{version}"
      msg = "Topology #{@topo_name} already exists - do you want to " \
        "update it#{to_version_str  if version}"
      ui.confirm(msg, true, false)
      @topo.save
    end

    def bootstrap_or_update_node(node_data, merge)
      node_name = node_data['name']
      if @bootstrap
        update_node(node_data, merge) unless node_bootstrap(node_data)
      elsif update_node(node_data, merge)
        @results[:existed] << node_name
      else
        @results[:skipped] << node_name
      end
    end

    def upload_artifacts
      processor.upload_artifacts('cmd' => self, 'cmd_args' => @args)
    end
  end
end
