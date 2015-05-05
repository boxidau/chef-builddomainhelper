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

class Chef
  # BuildDomainHelper is able to perform scope limited searched in a build domain
  # it will also return the best ip for a node automatically
  module BuildDomainHelper
    def self.calc_ip(node, other_node)
      local_subnets = subnets(node)
      remote_subnets = subnets(other_node)

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

    def self.subnets(node)
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

    def self.build_domain_search(node, tag, attribute, single = true)
      Chef::Log.info("Build domain search for #{tag}")

      # check attribute first to see if result is statically defined
      unless attribute.nil?
        return attribute
      end
      Chef::Log.info('Attribute is nil, searching instead')

      results = {}

      # Attribute is nil
      # Search the build domain
      unless node['build_domain'].nil?
        node_search = Chef::Search::Query.new.search(
          'node',
          ["tags:#{tag}",
           "build_domain:#{node.build_domain}",
           "chef_environment:#{node.chef_environment}"
          ].join(' AND ')
        )
        results = node_search[0]
      end

      # see if any results were found in the build domain
      if results.count < 1
        Chef::Log.info("Build domain search for tag: #{tag} returned no results, searching entire environment")
        # if nothing was found in the build domain then check the entire environment
        node_search = Chef::Search::Query.new.search(
          'node',
          "tags:#{tag} AND chef_environment:#{node.chef_environment}"
        )
        results = node_search[0]
      end

      fail "No search results were found for #{tag}" if results.count < 1

      if single
        calc_ip(node, results.first)
      else
        addresses = []
        results.each do |result_node|
          addresses.push(calc_ip(node, result_node))
        end
        addresses
      end
    end
  end
end

Chef::Recipe.send(:include, Chef::BuildDomainHelper)