#
# Author:: Christine Draper (<christine_draper@thirdwaveinsights.com>)
# Copyright:: Copyright (c) 2015 ThirdWave Insights LLC
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

#
# Converts data in a given format into V2 topo JSON format
#
require 'chef/knife/topo/processor'
require 'chef/knife/topo/processor/via_cookbook_print'
require 'chef/knife/topo/command_helper'
require 'chef/knife/cookbook_upload' unless defined? Chef::Knife::CookbookUpload
require 'chef/knife/cookbook_create'

module KnifeTopo
  # Class to provide context to execute knife topo helper methods
  class KnifeHelper < Chef::Knife
    include KnifeTopo::CommandHelper
  end

  # Process attributes via a cookbook
  class ViaCookbookProcessor < KnifeTopo::Processor
    attr_accessor :cookbook, :filename

    include KnifeTopo::ViaCookbookPrint

    def initialize(topo)
      super
      data = @topo['strategy_data'] || {}
      @cookbook = data['cookbook'] || topo.topo_name
      @filename = data['filename'] || 'topology'
      @helper = KnifeHelper.new
    end

    register_processor('via_cookbook', name)

    def generate_nodes
      super
    end

    # generate attributes to cookbook
    # context['cmd'] must be calling command
    # context['cmd_args'] must be calling command's args
    def generate_artifacts(context = {})
      @cmd = context['cmd']
      @cmd_args = context['cmd_args'] || []
      @config = Chef::Config.merge!(@cmd.config)
      return unless @cmd && cookbook_path
      run_create_cookbook
      create_attr_file(
        cookbook_path,
        cookbook_contents
      )
    end

    def run_create_cookbook
      create_args = @helper.initialize_cmd_args(
        @cmd_args, @cmd.name_args, %w(cookbook create)
      )
      create_args[2] = @cookbook
      # set options from calling command, so validation does not fail
      Chef::Knife::CookbookCreate.options = @cmd.class.options
      @helper.run_cmd(Chef::Knife::CookbookCreate, create_args)
    rescue StandardError => e
      raise if Chef::Config[:verbosity] == 2
      @helper.ui.warn "Create of cookbook #{@cookbook} exited with error"
      @helper.humanize_exception(e)
    end

    def create_attr_file(dir, contents)
      @helper.ui.info("** Creating attribute file: #{@filename}")

      name = @filename << '.rb' unless File.extname(@filename) == '.rb'
      filepath = File.join(dir, @cookbook, 'attributes', name)
      File.open(filepath, 'w') { |file| file.write(contents) }
    end

    def cookbook_path
      paths = @config['cookbook_path']
      return unless paths
      paths.first
    end

    def upload_artifacts(context = {})
      @cmd = context['cmd']
      @cmd_args = context['cmd_args'] || []
      return unless @cmd && !@cmd.config[:disable_upload]
      run_upload_cookbook
    end

    def run_upload_cookbook
      upload_args = @helper.initialize_cmd_args(
        @cmd_args, @cmd.name_args, %w(cookbook upload)
      )
      upload_args[2] = @cookbook
      # set options from calling command, so validation does not fail
      Chef::Knife::CookbookUpload.options = @cmd.class.options
      @helper.run_cmd(Chef::Knife::CookbookUpload, upload_args)
    rescue StandardError => e
      raise if Chef::Config[:verbosity] == 2
      @helper.ui.warn "Upload of cookbook #{@cookbook} exited with error"
      @helper.humanize_exception(e)
    end
  end
end
