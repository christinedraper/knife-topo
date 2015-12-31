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

require 'chef/data_bag'
require 'chef/node'
require 'chef/environment'
require 'chef/rest'

class Chef
  class Knife
    # Base topology helpers
    module TopologyHelper
      # initialize args for another knife command
      def initialize_cmd_args(args, new_name_args)
        args = args.dup
        args.shift(2 + @name_args.length)
        new_name_args + args
      end

      # run another knife command
      def run_cmd(command_class, args)
        command = command_class.new(args)
        command.config[:config_file] = config[:config_file]
        command.configure_chef
        command.run

        command
      end

      # check if resource exists
      def resource_exists?(relative_path)
        rest.get_rest(relative_path)
        true
      rescue Net::HTTPServerException => e
        raise unless e.response.code == '404'
        false
      end
    end
  end
end
