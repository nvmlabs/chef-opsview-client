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

# This recipe is used to manage the client registration in the console
resource_name :opsview_rest_client

property :device_title, String, name_attribute: true
property :api_host, String, required: true
property :api_user, String, required: true
property :api_password, String, required: true
property :api_port, Fixnum, default: 80
property :api_protocol, String, equal_to: %w(http https), default: lazy { 'http' }
property :ip, String, regex: [/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/], required: true
property :agent_server_port, String, default: '5666'

property :core_enabled, [TrueClass, FalseClass], default: true
property :core_gpgcheck, [TrueClass, FalseClass], default: false
property :core_gpgkey, [String, NilClass], default: nil
property :core_repository_id, String, default: 'opsview-core'
property :core_description, String, default: 'Opsview Core $basearch'
property :core_baseurl, String, default: lazy {
  "http://downloads.opsview.com/opsview-core/latest/yum/#{node['platform']}/$releasever/$basearch"
}

property :monitored_by, String, default: lazy { 'Master Monitoring Server' }

property :hostgroup, String, required: true
property :hostalias, String, default: ''
property :hosttemplates, [Array, Hash], default: ['Network - Base']

property :keywords, [Array, Hash], default: []
property :reload_opsview, [TrueClass, FalseClass], default: true
property :json_data, Hash
property :api_token, String


# Check the OpsView Server to see the current state of the
# Device
def load_current_value
  @current_resource = Chef::Resource::OpsviewClient.new(@new_resource.name)

  Opsview::Resource::opsview_token

  @current_resource.json_data(opsview_device)
  if @current_resource.json_data.nil?
    Chef::Log.info("#{@new_resource.name} is not currently registered with OpsView")
  else
    Chef::Log.debug("Retrieved current details for #{@new_resource.name} from OpsView")
  end
end

action :add_or_update do
  require 'opsview-rest'
  require 'json'
  require 'hashdiff'

  if @current_resource.json_data.nil?
    if resource_action == :update
      Chef::Log.info("#{@new_resource.name} is not registered - skipping.")
      return false
    else
      Chef::Log.info("#{@new_resource.name} is not registered - creating new registration.")
      @new_resource.json_data(new_registration)
      do_update = true
    end
  elsif resource_action == :add
    Chef::Log.info("#{@new_resource.name} is already registered - skipping.")
    return false
  else
    Chef::Log.debug("current_resource Before update_host_details: #{@current_resource.json_data.inspect}")
    @new_resource.json_data(update_host_details(@current_resource.json_data))
    Chef::Log.debug("new_resource After update_host_details: #{@new_resource.json_data.inspect}")
    json_diff = HashDiff.diff(@current_resource.json_data, @new_resource.json_data)
    do_update = !json_diff.empty? ? true : false
    Chef::Log.info("#{@new_resource.name} updated: #{do_update} diff: #{json_diff.inspect}")
  end

  if do_update
    put_opsview_device

    if @new_resource.reload_opsview
      Chef::Log.info('Configured to reload opsview')
      do_reload_opsview
    else
      Chef::Log.info('Configured NOT to reload opsview')
    end
  end

  # do_update
  # Call update action here

end
