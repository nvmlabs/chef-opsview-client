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

property :name, String, name_property: true
property :version, String, default: '22-06-15-2110'
property :version_linux, String, default: 'latest'
property :repo_key, String, required: true

# Template configuration
property :log_facility, String, default: 'daemon'
property :pid_file, String, default: '/var/tmp/nrpe.pid'
property :server_port, String, default: '5666'
property :server_address, String, default: '0.0.0.0'
property :nrpe_user, String, default: 'nagios'
property :nrpe_group, String, default: 'nagios'
property :allowed_hosts, String, default: '127.0.0.1'
property :dont_blame_nrpe, String, equal_to: %w(0 1), default: '0'
property :agent_debug, String, equal_to: %w(0 1), default: '0'
property :command_timeout, String, default: '60'
property :connection_timeout, String, default: '300'
property :allow_weak_random_seed, String, equal_to: %w(1 0), default: '1'
property :include_dirs, Array, default: lazy { ["#{linux_config_dir}/nrpe_local"] }
property :include_files, Array, default: []
property :default_commands, [TrueClass, FalseClass], default: true

property :manage_config, [TrueClass, FalseClass], default: true

# Windows
property :windows_config_dir, String, default: 'C:\Program Files\Opsview Agent'
# default to x64
# Agent versions for 32bit platforms (4.6.3) do not match the latest release of
# Opsview Monitor (5.2) but still maintain full compatibility.
property :windows_download_url, String, default: lazy {
  "https://opsview-agents.s3.amazonaws.com/Windows/Opsview_Windows_Agent_x64_#{version}.msi"
}

# Linux
property :linux_config_dir, String, default: '/usr/local/nagios/etc'
# set to 'local' if you want to handle the package repo yourself
property :installation_method, String, equal_to: %w(repo local), default: 'repo'
property :yum_allow_downgrade, [TrueClass, FalseClass], default: false
property :yum_enabled, [TrueClass, FalseClass], default: true
property :yum_gpgcheck, [TrueClass, FalseClass], default: false
property :yum_opsview_gpgkey, [String, NilClass], default: nil
property :yum_description, String, default: 'Opsview Core $basearch'
property :repository_key, String
property :yum_baseurl, String, default: lazy {
  "https://downloads.opsview.com/k/#{repository_key}/opsview-commercial/#{version_linux}/yum/#{node['platform']}/$releasever/$basearch"
}
property :apt_baseUrl, String, default: lazy {
  "https://downloads.opsview.com/k/#{repository_key}/opsview-commercial/#{version_linux}/apt/"
}

default_action  :install

action :install do
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
      cookbook 'opsview_client'
      only_if { manage_config }
    end

    service 'NSClientpp' do
      action [:enable, :start]
    end

  when 'rhel'
    if installation_method == 'repo'
      yum_repository 'epel' do
        mirrorlist 'http://mirrors.fedoraproject.org/mirrorlist?repo=epel-5&arch=$basearch'
        description 'Extra Packages for Enterprise Linux 5 - $basearch'
        enabled true
        gpgcheck true
        gpgkey 'http://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL'
      end

      yum_repository 'opsview' do
        description yum_description
        gpgcheck yum_gpgcheck
        gpgkey yum_opsview_gpgkey unless yum_opsview_gpgkey.nil?
        baseurl yum_baseurl
        enabled yum_enabled
      end
    end

    %w(libmcrypt opsview-agent).each do | pkg |
      package pkg do
        allow_downgrade yum_allow_downgrade
        action :install
        options '--nogpgcheck'
        flush_cache before: true if respond_to?(:flush_cache)
      end
    end

    template "#{linux_config_dir}/nrpe.cfg" do
      source 'nrpe.cfg.erb'
      mode '0444'
      user nrpe_user
      group nrpe_group
      cookbook 'opsview_client'
      variables(
        log_facility: log_facility,
        pid_file: pid_file,
        server_port: server_port,
        server_address: server_address,
        nrpe_user: nrpe_user,
        nrpe_group: nrpe_group,
        allowed_hosts: allowed_hosts,
        dont_blame_nrpe: dont_blame_nrpe,
        agent_debug: agent_debug,
        command_timeout: command_timeout,
        connection_timeout: connection_timeout,
        allow_weak_random_seed: allow_weak_random_seed,
        include_dirs: include_dirs,
        include_files: include_files,
        default_commands: default_commands
      )
      notifies :restart, 'service[opsview-agent]'
      only_if { manage_config }
    end

    service 'opsview-agent' do
      action [:enable, :start]
    end
  when 'debian'
    apt_repository 'opsview' do
      uri        apt_baseUrl
      components ['main']
    end

    apt_update 'now' do
      action :update
    end

    package 'opsview-agent'

    template "#{linux_config_dir}/nrpe.cfg" do
      source 'nrpe.cfg.erb'
      mode '0444'
      user nrpe_user
      group nrpe_group
      cookbook 'opsview_client'
      variables(
        log_facility: log_facility,
        pid_file: pid_file,
        server_port: server_port,
        server_address: server_address,
        nrpe_user: nrpe_user,
        nrpe_group: nrpe_group,
        allowed_hosts: allowed_hosts,
        dont_blame_nrpe: dont_blame_nrpe,
        agent_debug: agent_debug,
        command_timeout: command_timeout,
        connection_timeout: connection_timeout,
        allow_weak_random_seed: allow_weak_random_seed,
        include_dirs: include_dirs,
        include_files: include_files,
        default_commands: default_commands
      )
      notifies :restart, 'service[opsview-agent]'
      only_if { manage_config }
    end

    service 'opsview-agent' do
      action [:enable, :start]
    end
  end
end
