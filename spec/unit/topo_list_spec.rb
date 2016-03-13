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

#
# These tests are in need of cleaning up - big time!
#

require 'rspec'
require 'rspec/mocks'
require File.expand_path('../../spec_helper', __FILE__)
require 'chef/knife/topo_list'

describe KnifeTopo::TopoList do
  before :each do
    Chef::Config[:node_name] = 'christine_test'
  end
  describe '#run' do
    let(:cmd) { KnifeTopo::TopoList.new(['--data-bag=topologies']) }
    it 'lists topologies' do
      allow(Chef::DataBag).to receive(:load).and_return(['something'])
      expect(cmd).to receive(:format_list_for_display)

      cmd.run
    end
  end
end
