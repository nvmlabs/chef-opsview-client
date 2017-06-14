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
property :device_name, String, default: lazy { node['hostname'] }
property :api_url, String, required: true
property :api_user, String, required: true
property :api_password, String, required: true
property :api_port, Fixnum, default: 443
property :api_protocol, String, equal_to: %w(http https), default: 'https'
property :ip, String, regex: [/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/], required: true

property :monitored_by, String, default: lazy { 'Master Monitoring Server' }

property :hostgroup, String, required: true
property :hostalias, String, default: ''
property :hosttemplates, [Array, Hash], default: ['Network - Base']

property :keywords, [Array, Hash], default: []
property :reload_opsview, [TrueClass, FalseClass], default: true
property :json_data, Hash
property :api_token, String
property :device_action, [String, NilClass], equal_to: %w( add update ), default: NilClass

# Check the OpsView Server to see the current state of the
# Device
def load_current_value
  @current_resource = Chef::Resource::OpsviewClient.new(@new_resource.name)

  Opsview::Resource.opsview_token

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

  # Login
  begin
    @host = OpsviewRest.new(api_url, username: api_user, password: api_password)
  rescue
    raise 'RestClient OpsView Rest API error: ' + $ERROR_INFO.inspect
  end
  # Find host
  host_json = host.find(type: 'host', name: device_name).to_json

  # host_json will be empty if we can't find the device
  if host_json == []
    Chef::Log.debug("Didn't find the host creating: #{inspect}")
    update_device(add)
  else
    Chef::Log.debug("Found device #{device_name} updating")
    update_device(update)
  end

  def update_device(add_or_update)
    @host.create(
      name: @new_resource.device_name,
      ip: @new_resource.ip,
      hostgroup: @new_resource.hostgroup,
      hosttemplates: @new_resource.hosttemplates,
      type: 'host',
      replace: add_or_update
    )
  end
end
