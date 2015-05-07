require_relative 'spec_helper'

describe BuildDomainHelper do
  describe '#search' do
    xenstore_ls = File.read(File.join(File.dirname(__FILE__), '..', 'fixtures', 'xenstore.out'))
    xenstore_ls_nobuild = File.read(File.join(File.dirname(__FILE__), '..', 'fixtures', 'xenstore-nobuild.out'))

    let(:query) { double(Chef::Search::Query) }
    let(:dummy_class) { Class.new { include BuildDomainHelper } }
    let(:node_fixtures) { File.join(File.dirname(__FILE__), '..', 'fixtures', 'nodes') }

    def fixture_node(node)
      node_file = File.join(File.dirname(__FILE__), '..', 'fixtures', 'nodes', "#{node}.json")
      stub_node(node, path: node_file)
    end

    # No BD
    let(:node1) { fixture_node('node1') }
    let(:node2) { fixture_node('node2') }
    # Same BD
    let(:node3) { fixture_node('node3') }
    let(:node4) { fixture_node('node4') }
    # Different BD
    let(:node5) { fixture_node('node5') }

    before do
      allow(Chef::Search::Query).to receive(:new).and_return(query)
      allow(Mixlib::ShellOut).to receive(:new).and_return(shellout)
      allow(Mixlib::ShellOut).to receive(:new).with('xenstore-ls vm-data/user-metadata', returns: [0, 2])
      allow(shellout).to receive(:live_stream=).and_return(nil)
      allow(shellout).to receive(:live_stream).and_return(nil)
      allow(shellout).to receive(:exitstatus).and_return(0)
    end

    context 'without metadata' do
      let(:shellout) do
        double(run_command: nil, error!: nil, stdout: xenstore_ls_nobuild, stderr: double(empty?: true))
      end

      it 'from a node without a build domain all other nodes should return' do
        allow(query).to receive(:search).with(
          'node',
          'tags:all AND chef_environment:_default'
        ).and_return([[node1, node2, node3, node4, node5], 1, 5])
        expect(dummy_class.new.bd_search(node1, 'all')).to eq([node1, node2, node3, node4, node5])
      end

      it 'fails to fetch xen-store metadata' do
        expect(dummy_class.new.bd_get(node1)).to eq(nil)
      end

      it 'fetches build domain from existing node attributes, even though xenstore-ls is not available' do
        expect(dummy_class.new.bd_get(node3)).to eq(
          'code_ref' => '0.2.3',
          'code_ref_type' => 'tag',
          'id' => '3957397513131'
        )
      end
    end

    context 'with build domain via metadata' do
      let(:shellout) { double(run_command: nil, error!: nil, stdout: xenstore_ls, stderr: double(empty?: true)) }

      it 'fetches xen-store metadata since the node itself has no info' do
        expect(dummy_class.new.bd_get(node1)).to eq(
          'code_ref' => '0.2.3',
          'code_ref_type' => 'tag',
          'id' => '3957397513131'
        )
      end

      it 'returns nodes from environment failover search since nothing is returned with the same build domain' do
        allow(query).to receive(:search).with(
          'node',
          'tags:database AND chef_environment:_default'
        ).and_return([[node1, node2], 1, 1])

        expect(dummy_class.new.bd_search(node3, 'database')).to eq([node1, node2])
      end

      it 'returns only the nodes in the same BD with mixed search results' do
        allow(query).to receive(:search).with(
          'node',
          'tags:app AND chef_environment:_default'
        ).and_return([[node3, node4, node5], 1, 1])

        expect(dummy_class.new.bd_search(node3, 'app')).to eq([node3, node4])
      end

      it 'return only self since the search results are all from different build domains' do
        allow(query).to receive(:search).with(
          'node',
          'tags:app AND chef_environment:_default'
        ).and_return([[node3, node4, node5], 1, 1])

        expect(dummy_class.new.bd_search(node5, 'app')).to eq([node5])
      end
    end
  end
end
