# This file is a place holder for opsview methods

def opsview_device(action)
  # action put/get
  require 'rest-client'
  raise 'OpsView Rest API token missing' if @new_resource.api_token.nil?
  raise 'Did not specify a node to look up.' if @new_resource.name.nil?

  # Get
  url = URI.escape([api_url, "config/host?json_filter={\"name\": {\"-like\": \"#{@new_resource.name}\"}}"].join('/'))
  # Puts=
  url = [api_url, 'config/host'].join('/')

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

  if @error_occured
    Chef::Log.warn('put: Problem talking to Opsview server; ignoring Opsview config')
    return
  end

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



def new_registration
  node_json = {}
  node['opsview']['default_node'].each_pair do |key, value|
    node_json[key] = value
  end

  update_host_details(node_json)
end

def update_host_details(original_json)
  node_json = Marshal.load(Marshal.dump(original_json))
  node_json['name'] = @new_resource.device_title
  node_json['ip'] = @new_resource.ip

  unless @new_resource.hostalias.to_s.empty?
    node_json['alias'] = @new_resource.hostalias
  end

  if node_json['hostgroup']['name'] != @new_resource.hostgroup
    node_json['hostgroup'] = { 'name' => @new_resource.hostgroup }
  end

  node_json['hosttemplates'] = [] if node_json['hosttemplates'].nil?
  node_json['hosttemplates'].synchronise_array_by_key(@new_resource.hosttemplates, 'name')

  unless @new_resource.monitored_by.to_s.empty?
    if node_json['monitored_by']['name'] != @new_resource.monitored_by
      node_json['monitored_by'] = { 'name' => @new_resource.monitored_by }
    end
  end

  node_json['keywords'] = [] if node_json['keywords'].nil?
  node_json['keywords'].synchronise_array_by_key(@new_resource.keywords, 'name')

  node_json['hostattributes'] = [] if node_json['hostattributes'].nil?
  node_json['hostattributes'].synchronise_hash_by_key(get_host_attributes, 'name')

  node_json
end

def host_attributes
  host_attributes = []
  node['filesystem'].each_pair do |_fs, opts|
    next unless opts.attribute?('fs_type') && !node['opsview']['exclude_fs_type'].include?(opts['fs_type'])
    unless opts['mount'].to_s.empty?
      host_attributes << { 'name' => 'DISK', 'value' => opts['mount'].delete(':') }
    end
  end

  if node['opsview']['optional_attributes'].include?('MAC')
    host_attributes << { 'name' => 'MAC', 'value' => node['macaddress'].tr(':', '-') }
  end

  if node['opsview']['optional_attributes'].include?('CHEFSERVER')
    host_attributes << { 'name' => 'CHEFSERVER', 'value' => node.environment, 'arg1' => Chef::Config[:chef_server_url] }
  end

  host_attributes
end
