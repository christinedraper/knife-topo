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
# The processor class converts a topology into node data and artifacts,
# based on the strategy
#

module KnifeTopo
  # Base processor
  class Processor
    # rubocop:disable Style/ClassVars
    @@processor_classes = {}

    def self.register_processor(strategy, class_name)
      @@processor_classes[strategy] = class_name
    end

    # Get the right processor
    def self.processor(topo)
      strategy = topo.strategy
      processor_class = @@processor_classes[strategy]
      processor_class = load_processor(strategy) unless processor_class

      Object.const_get(processor_class).new(topo)
    end

    def self.load_processor(strategy)
      require "chef/knife/topo/processor/#{strategy}"
      @@processor_classes[strategy]
    rescue LoadError
      STDERR.puts("#{strategy} is not a known strategy")
      exit(1)
    end

    def self.for_topo(topo)
      processor(topo)
    end

    attr_accessor :input

    def initialize(topo)
      @topo = topo
    end

    # Other processors should override the following methods
    register_processor('direct_to_node', name)

    def generate_nodes
      @topo.merged_nodes
    end

    def generate_artifacts(_context = {})
      {}
    end

    def upload_artifacts(_context = {})
    end
  end
end
