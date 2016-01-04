# data shared across topo create specs
class UnitTestData
  attr_reader :topo1, :topo1_merged
  # rubocop:disable Metrics/MethodLength
  def initialize
    @topo1 = {
      'id' => 'topo1',
      'name' => 'topo1',
      'chef_environment' => 'test',
      'tags' => ['topo_tag'],
      'default' => { 'anAttr' => 'aValue' },
      'nodes' => [
        {
          'name' => 'node1',
          'ssh_host' => '10.0.1.2'
        },
        {
          'name' => 'node2',
          'chef_environment' => 'dev',
          'override' => { 'anotherAttr' => 'anotherValue' },
          'tags' => %w(topo_tag  second_tag)
        }
      ]
    }
    @topo1_merged = {
      'id' => 'topo1',
      'name' => 'topo1',
      'chef_environment' => 'test',
      'tags' => ['topo_tag'],
      'default' => { 'anAttr' => 'aValue' },
      'nodes' => [
        {
          'name' => 'node1',
          'ssh_host' => '10.0.1.2',
          'chef_environment' => 'test',
          'tags' => ['topo_tag'],
          'default' => {
            'anAttr' => 'aValue'
          },
          'normal' => {
            'topo' => { 'name' => 'topo1' }
          }
        },
        {
          'name' => 'node2',
          'chef_environment' => 'dev',
          'tags' => %w(topo_tag  second_tag),
          'default' =>
          {
            'anAttr' => 'aValue'
          },
          'override' =>
          {
            'anotherAttr' => 'anotherValue'
          },
          'normal' =>
          {
            'topo' => { 'name' => 'topo1' }
          }
        }
      ]
    }
  end
end
