#
# Copyright 2015, Simon Mirco <simon.mirco@rackspace.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
require 'ipaddr'

# BuildDomainHelper is able to perform scope limited searched in a build domain
# it will also return the best ip for a node automatically
module BuildDomainHelper
  include Chef::Mixin::ShellOut
  def bd_get(node)
    return node[:build_domain] unless node[:build_domain].nil?
    so = shell_out('xenstore-ls vm-data/user-metadata')
    if so.exitstatus == 0
      so.stdout.split("\n").each do |line|
        node.set[:build_domain][:id] = line.split[2].delete('\"') if line =~ /^build_domain_id/
        node.set[:build_domain][:code_ref] = line.split[2].delete('\"') if line =~ /^code_ref/
        node.set[:build_domain][:code_ref_type] = line.split[2].delete('\"') if line =~ /^code_ref_type/
      end
      return node[:build_domain]
    end
  rescue Errno::ENOENT
    Chef::Log.debug('Unable to find xenstore-ls, cannot capture build domain info')
    return false
  end

  def bd_calc_ip(node, other_node, favour = nil)
    local_subnets = bd_subnets(node)
    remote_subnets = bd_subnets(other_node)

    unless favour.nil?
      favour_subnet = IPAddr.new favour
      remote_subnets.each do |r_addr, r_subnet|
        return r_addr if favour_subnet.include?(favour_subnet)
      end
    end

    remote_ip = nil
    local_subnets.each do |l_addr, l_subnet|
      # see if the local subnet includes the remote subnets
      remote_subnets.each do |r_addr, r_subnet|
        next unless l_subnet.include?(IPAddr.new r_addr)
        Chef::Log.debug('Subnet match detected for search')
        remote_ip = r_addr
        break
      end
      break unless remote_ip.nil?
    end

    if remote_ip.nil? && !other_node.ipaddress.nil?
      remote_ip = other_node.ipaddress
    end

    remote_ip
  end

  def bd_subnets(node)
    subnets = {}
    node[:network][:interfaces].reverse_each do |interface, configuration|
      next if interface == 'lo'
      ipv4_addrs = configuration[:addresses].select { |_addr, info| info['family'] == 'inet' }
      ipv4_addrs.each do |addr, info|
        subnets[addr] = IPAddr.new "#{addr}/#{info['netmask']}"
      end
    end
    subnets
  end

  def bd_search(node, tag)
    Chef::Log.info("Build domain search for #{tag}")

    bd_get(node)

    # Attribute is nil
    # Search the environment
    node_search = Chef::Search::Query.new.search(
      'node', "tags:#{tag} AND chef_environment:#{node.chef_environment}"
    )
    results = node_search[0]

    # see if any results were found in the build domain
    return results unless node.key?('build_domain') && node[:build_domain].key?('id')

    # filter resulting nodes searching for the build domain
    build_domain_nodes = results.select do |result_node|
      next unless result_node.key?('build_domain')
      next unless result_node[:build_domain].fetch('id', nil) == node[:build_domain][:id]
      result_node
    end

    if build_domain_nodes.count > 0
      build_domain_nodes
    else
      results
    end
  end
end

Chef::Recipe.send(:include, BuildDomainHelper)
