require_relative 'spec_helper'

describe BuildDomainHelper do
  describe '#search' do
    xenstore_ls = File.read(File.join(File.dirname(__FILE__), '..', 'fixtures', 'xenstore.out'))
    xenstore_ls_nobuild = File.read(File.join(File.dirname(__FILE__), '..', 'fixtures', 'xenstore-nobuild.out'))

    let(:shellout) do
      double(run_command: nil, error!: nil, stdout: xenstore_ls_nobuild, stderr: double(empty?: true))
    end

    let(:query) { double(Chef::Search::Query) }
    let(:dummy_class) { Class.new { include BuildDomainHelper } }
    let(:node_fixtures) { File.join(File.dirname(__FILE__), '..', 'fixtures', 'nodes') }

    before do
      allow(Chef::Search::Query).to receive(:new).and_return(query)
      allow(Mixlib::ShellOut).to receive(:new).and_return(shellout)
      allow(Mixlib::ShellOut).to receive(:new).with('xenstore-ls vm-data/user-metadata', returns: [0, 2])
      allow(shellout).to receive(:live_stream=).and_return(nil)
      allow(shellout).to receive(:live_stream).and_return(nil)
      allow(shellout).to receive(:exitstatus).and_return(0)
    end

    it 'returns attribute if not nil' do
      attrib = 'something'
      node = stub_node(platform: 'ubuntu', version: '12.04')
      expect(dummy_class.new.search(node, 'some_tag', attrib)).to eq('something')
    end
    context 'with build domain' do
      let(:shellout) { double(run_command: nil, error!: nil, stdout: xenstore_ls, stderr: double(empty?: true)) }

      it 'returns ip address of node2 from environment search' do
        attrib = nil
        node1_file = File.join(File.dirname(__FILE__), '..', 'fixtures', 'nodes', 'node1.json')
        node1 = stub_node('self', path: node1_file)
        node2 = stub_node('node2', path: File.join(node_fixtures, 'node2.json'))

        allow(query).to receive(:search).with(
          'node',
          'tags:node2 AND chef_environment:_default'
        ).and_return([[node2], 1, 1])

        allow(query).to receive(:search).with(
          'node',
          'tags:node2 AND build_domain:3957397513131 AND chef_environment:_default'
        ).and_return([[], 0, 0])

        expect(dummy_class.new.search(node1, 'node2', attrib)).to eq('192.168.0.2')
      end

      it 'fetches xen-store metadata' do
        node = stub_node('node1', path: File.join(node_fixtures, 'node1.json'))
        expect(dummy_class.new.get_build_domain(node)).to eq(
          'code_ref' => '0.2.3',
          'code_ref_type' => 'tag',
          'id' => '3957397513131'
        )
      end

      it 'returns eth2 ip address of node2 from environment failover search' do
        attrib = nil
        node1_file = File.join(File.dirname(__FILE__), '..', 'fixtures', 'nodes', 'node1.json')
        node1 = stub_node('self', path: node1_file)
        # set build domain shell out

        node2 = stub_node('node2', path: File.join(node_fixtures, 'node2.json'))
        allow(query).to receive(:search).with(
          'node',
          'tags:node2 AND chef_environment:_default'
        ).and_return([[node2], 1, 1])
        allow(query).to receive(:search).with(
          'node',
          'tags:node2 AND build_domain:3957397513131 AND chef_environment:_default'
        ).and_return([[], 0, 0])

        expect(dummy_class.new.search(node1, 'node2', attrib)).to eq('192.168.0.2')
      end

      it 'returns eth2 ip address of node3 from build domain search' do
        attrib = nil
        node1_file = File.join(File.dirname(__FILE__), '..', 'fixtures', 'nodes', 'node1.json')
        node1 = stub_node('self', path: node1_file)
        # node1.set['build_domain'] = '3957397513131'
        # set build domain shell out

        node3 = stub_node('node3', path: File.join(node_fixtures, 'node3.json'))
        allow(query).to receive(:search).with(
          'node',
          'tags:node3 AND build_domain:3957397513131 AND chef_environment:_default'
        ).and_return([[node3], 1, 1])

        expect(dummy_class.new.search(node1, 'node3', attrib)).to eq('192.168.0.3')
      end

      it 'returns eth1 ip address of node4 from build domain search' do
        attrib = nil
        node1_file = File.join(File.dirname(__FILE__), '..', 'fixtures', 'nodes', 'node1.json')
        node1 = stub_node('self', path: node1_file)
        # set build domain shell out
        # node1.set['build_domain'] = '3957397513131'
        node4 = stub_node('node4', path: File.join(node_fixtures, 'node4.json'))
        allow(query).to receive(:search).with(
          'node',
          'tags:node4 AND build_domain:3957397513131 AND chef_environment:_default'
        ).and_return([[node4], 1, 1])

        expect(dummy_class.new.search(node1, 'node4', attrib)).to eq('10.208.0.37')
      end
    end
  end
end
