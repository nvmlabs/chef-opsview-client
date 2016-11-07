#
# Cookbook Name:: opsview_client
# Providers:: default
#
# Copyright 2014, Rob Coward
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

@error_occurred = false

def do_add_or_update(resource_action)
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

  opsview_device(put) if do_update

  if @new_resource.reload_opsview
    opsview_reload
    Chef::Log.info('Configured NOT to reload opsview')
  end
end


class Opsview
  class Resource
    def api_url
      n = @new_resource
      "#{n.api_protocol}://#{n.api_host}:#{n.api_port}/rest"
    end

    def opsview_token
      require 'rest-client'

      Chef::Log.debug('Fetching Opsview token')
      post_body = { 'username' => @new_resource.api_user,
                    'password' => @new_resource.api_password }.to_json

      url = [api_url, 'login'].join('/')

      Chef::Log.debug('Using Opsview url: ' + url)
      Chef::Log.debug('using post: username:' + @new_resource.api_user + ' password:' + @new_resource.api_password.gsub(/\w/, 'x'))

      begin
        response = RestClient.post url, post_body, content_type: :json
      rescue
        @error_occured = true
        Chef::Log.fatal('Problem getting token from Opsview server; ' + $ERROR_INFO.inspect)
        raise 'Unable to authenticate with OpsView Rest API: ' + $ERROR_INFO.inspect
      end

      case response.code
      when 200
        Chef::Log.debug('Response code: 200')
      else
        Chef::Log.fatal('Unable to log in to Opsview server; HTTP code ' + response.code)
        raise 'Error authenticating OpsView Rest API: ' + response
      end

      received_token = JSON.parse(response)['token']
      Chef::Log.debug('Got token: ' + received_token)
      @new_resource.api_token(received_token)
    end

    def opsview_device
      require 'rest-client'
      raise 'OpsView Rest API token missing' if @new_resource.api_token.nil?
      raise 'Did not specify a node to look up.' if @new_resource.name.nil?

      url = URI.escape([api_url, "config/host?json_filter={\"name\": {\"-like\": \"#{@new_resource.name}\"}}"].join('/'))

      begin
        response = RestClient.get url, x_opsview_username: @new_resource.api_user,
                                       x_opsview_token: @new_resource.api_token,
                                       content_type: :json,
                                       accept: :json
      rescue
        raise 'RestClient.get OpsView Rest API error: ' + $ERROR_INFO.inspect
      end

      begin
        response_json = JSON.parse(response)
      rescue
        raise 'Could not parse the JSON response from Opsview: ' + response
      end

      response_json['list'][0]
    end

    def put_opsview_device
      require 'rest-client'

      if @error_occured
        Chef::Log.warn('put: Problem talking to Opsview server; ignoring Opsview config')
        return
      end

      url = [api_url, 'config/host'].join('/')
      Chef::Log.debug('RestClient.put ' + url + ' : ' + @new_resource.json_data.to_json)
      begin
        response = RestClient.put url, @new_resource.json_data.to_json,
                                  x_opsview_username: @new_resource.api_user,
                                  x_opsview_token: @new_resource.api_token,
                                  content_type: :json,
                                  accept: :json
      rescue
        Chef::Log.fatal('Problem sending device data to Opsview server; ' + $ERROR_INFO.inspect + "\n====\n" + url + "\n====\n" + @new_resource.json_data.to_json)
        raise 'RestClient.put OpsView Rest API errored: ' + $ERROR_INFO.inspect
      end
      Chef::Log.debug('RestClient.put response: ' + response)
    end

    def do_reload_opsview
      require 'rest-client'

      url = [api_url, 'reload?asynchronous=1'].join('/')

      Chef::Log.info('Performing Opsview reload')

      begin
        response = RestClient.post url, '', x_opsview_username: @new_resource.api_user,
                                            x_opsview_token: @new_resource.api_token,
                                            content_type: :json,
                                            accept: :json
      rescue
        Chef::Log.warn('Unable to reload Opsview: ' + $ERROR_INFO.inspect)
        return
      end

      case response.code
      when 200
        Chef::Log.debug('Reloaded Opsview')
      when 401
        raise 'Login failed: ' + response.code
      when 409
        Chef::Log.info('Opsview reload already in progress')
      else
        raise 'Was not able to reload Opsview: HTTP code: ' + response.code
      end
    end
  end
end
