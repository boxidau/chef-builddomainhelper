require_relative 'spec_helper'

describe BuildDomainHelper do
  describe '#build_domain_search' do
    let(:query) { double(Chef::Search::Query) }

    before do
      allow(Chef::Search::Query).to receive(:new).and_return(query)
      node_fixtures = File.join(File.dirname(__FILE__), '..', 'fixtures', 'nodes')

      node2 = stub_node('node2', path: File.join(node_fixtures, 'node2.json'))
      allow(query).to receive(:search).with('node', 'tags:node2 AND chef_environment:_default').and_return([[node2], 1, 1])
      allow(query).to receive(:search).with('node', 'tags:node2 AND build_domain:3957397513131 AND chef_environment:_default').and_return([[], 0, 0])

      node3 = stub_node('node3', path: File.join(node_fixtures, 'node3.json'))
      allow(query).to receive(:search).with('node', 'tags:node3 AND build_domain:3957397513131 AND chef_environment:_default').and_return([[node3], 1, 1])

      node4 = stub_node('node3', path: File.join(node_fixtures, 'node4.json'))
      allow(query).to receive(:search).with('node', 'tags:node4 AND build_domain:3957397513131 AND chef_environment:_default').and_return([[node4], 1, 1])
    end

    it 'returns attribute if not nil' do
      attrib = 'something'
      node = stub_node(platform: 'ubuntu', version: '12.04')
      expect(described_class.build_domain_search(node, 'some_tag', attrib)).to eq('something')
    end

    it 'returns ip address of node2 from environment search' do
      attrib = nil
      node1_file = File.join(File.dirname(__FILE__), '..', 'fixtures', 'nodes', 'node1.json')
      node1 = stub_node('self', path: node1_file)
      expect(described_class.build_domain_search(node1, 'node2', attrib)).to eq('192.168.0.2')
    end

    it 'returns eth2 ip address of node2 from environment failover search' do
      attrib = nil
      node1_file = File.join(File.dirname(__FILE__), '..', 'fixtures', 'nodes', 'node1.json')
      node1 = stub_node('self', path: node1_file)
      node1.set['build_domain'] = '3957397513131'
      expect(described_class.build_domain_search(node1, 'node2', attrib)).to eq('192.168.0.2')
    end

    it 'returns eth2 ip address of node3 from build domain search' do
      attrib = nil
      node1_file = File.join(File.dirname(__FILE__), '..', 'fixtures', 'nodes', 'node1.json')
      node1 = stub_node('self', path: node1_file)
      node1.set['build_domain'] = '3957397513131'
      expect(described_class.build_domain_search(node1, 'node3', attrib)).to eq('192.168.0.3')
    end

    it 'returns eth1 ip address of node4 from build domain search' do
      attrib = nil
      node1_file = File.join(File.dirname(__FILE__), '..', 'fixtures', 'nodes', 'node1.json')
      node1 = stub_node('self', path: node1_file)
      node1.set['build_domain'] = '3957397513131'
      expect(described_class.build_domain_search(node1, 'node4', attrib)).to eq('10.208.0.37')
    end
  end
end
