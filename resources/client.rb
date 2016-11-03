#
# Cookbook Name:: opsview_client
# Resource:: opsview_client
#
# Copyright 2016, Rob Coward, Dan Webb
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

resource_name :opsview_client
property :device_title, String, name_attribute: true
property :api_host, String, required: true
property :api_user, String, required: true
property :api_password, String, required: true
property :api_port, Fixnum, default: 80
property :api_protocol, String, equal_to: %w(http https), default: lazy { 'http' }
property :ip, String, regex: [/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/], required: true
property :monitored_by, String, default: lazy { 'Master Monitoring Server' }
property :hostgroup, String, required: true
property :hostalias, String, default: ''
property :hosttemplates, [Array, Hash], default: ['Network - Base']
property :keywords, [Array, Hash], default: []
property :reload_opsview, [TrueClass, FalseClass], default: true
property :json_data, Hash
property :api_token, String
property :manage_config, [TrueClass, FalseClass], default: true
property :download_url, String, default: ''

property :default_commands, [TrueClass, FalseClass], default: true
property :manage_ncslient_config, [TrueClass, FalseClass], default: true
property :include_files, Array, default: []
property :server_address, String, default: '0.0.0.0'
property :nrpe_user, String, default: 'nagios'
property :nrpe_group, String, default: 'nagios'
property :allowed_hosts, String, default: '127.0.0.1'
property :dont_blame_nrpe, String, equal_to: %w(0 1), default: '1'
property :debug, String, equal_to: %w(0 1), default: '0'
property :command_timeout, String, default: '60'
property :connection_timeout, String, default: '300'
property :allow_weak_random_seed, String, equal_to: %w(1 0), default: '1'
property :server_port, String, default: '5666'

# Linux
property :opsview_packages, Hash, default: {
  'libmcrypt' => nil,
  'opsview-agent' => nil
}
property :log_facility, String, default: 'daemon'
property :pid_file, String, default: '/var/tmp/nrpe.pid'
property :linux_config_dir, String, default: '/usr/local/nagios/etc'
property :include_dirs, Array, default: lazy { ["::File.join(#{linux_config_dir}, nrpe_local)"] }
# set to 'local' if you want to handle the package repo yourself
property :installation_method, String, equal_to: %w(repo local), default: 'repo'
property :yum_allow_downgrade, [TrueClass, FalseClass], default: false
property :core_enabled, [TrueClass, FalseClass], default: true
property :core_gpgcheck, [TrueClass, FalseClass], default: false
property :core_gpgkey, [String, NilClass], default: nil
property :core_repository_id, String, default: 'opsview-core'
property :core_description, String, default: 'Opsview Core $basearch'
property :core_baseurl, String, default: lazy {
  "http://downloads.opsview.com/opsview-core/latest/yum/#{node['platform']}/$releasever/$basearch"
}

# Windows
property :windows_config_dir, String, default: 'C:\Program Files\Opsview Agent'
# default to x64
# Agent versions for 32bit platforms (4.6.3) do not match the latest release of
# Opsview Monitor (5.2) but still maintain full compatibility.
property :windows_download_url, String, default {
  'https://opsview-agents.s3.amazonaws.com/Windows/Opsview_Windows_Agent_x64_22-06-15-2110.msi'
}

actions :add_or_update, :add, :update, :install
default_action  :install

action :install do
  chef_gem 'rest-client'
  chef_gem 'hashdiff'

  # install the appropriate Opsview agent
  case node['platform_family']
  when 'windows'

    package 'Opsview NSClient++ Windows Agent (x64)' do
      source windows_download_url
      options '/quiet /norestart'
      action :install
    end

    template ::File.join(windows_config_dir, 'NSC.ini') do
      source 'NSC.ini.erb'
      notifies :restart, 'service[NSClientpp]'
      action manage_ncslient_config ? :create : :create_if_missing
    end

    # finally ensure service is running for opsview
    service 'NSClientpp' do
      action [:enable, :start]
    end
  when 'rhel'

    node['opsview']['agent']['packages'].each do |pkg, ver|
      package pkg do
        allow_downgrade yum_allow_downgrade
        action :install
        version ver if ver
        options '--nogpgcheck'
        flush_cache before: true if respond_to?(:flush_cache)
      end
    end

    template "#{linux_config_dir}/nrpe.cfg" do
      source 'nrpe.cfg.erb'
      mode '0444'
      user nrpe_user
      group nrpe_group
      notifies :restart, 'service[opsview-agent]'
      action manage_config ? :create : :create_if_missing
    end

    service 'opsview-agent' do
      action [:enable, :start]
    end
  end
end
