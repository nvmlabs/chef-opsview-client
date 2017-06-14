opsview_client Cookbook
=======================
This cookbook:
- Installs the Opsview client
- Sets-up repositories (Linux)
- Installs Opsview agent
- Ensure Opsview agent service is enabled and started
- Optionally registers the client with the server (TODO)

Note: you can setup your own repoistory settings using the provider settings, see `resources/client.rb`.

# Requirements
- Chef 12.5+

# Usage
This cookbook provides custom resources using `opsview_client` & `opsview_rest_client`, include these in your own recipe as you would do with a template or directory resource

## `opsview_client` Windows
```ruby
opsview_client 'bob' do
  allowed_hosts '192.168.0.200'
  nsca_host '192.168.0.1'
  nsca_port '5667'
end
```

## `opsview_client` Linux
```ruby
opsview_client 'bob' do
  allowed_hosts '192.1680.200'
  repository_key 'super-long-key-from-opsview'
end
```

## NRPE Configuration (Linux)
```
log_facility, String, default: 'daemon'
pid_file, String, default: '/var/tmp/nrpe.pid'
server_port, String, default: '5666'
server_address, String, default: '0.0.0.0'
nrpe_user, String, default: 'nagios'
nrpe_group, String, default: 'nagios'
allowed_hosts, String # Comma seperated list of hosts
dont_blame_nrpe, String 0 or 1
agent_debug, String, 0/1, default: '0'
command_timeout, String, default: '60'
connection_timeout, String, default: '300'
allow_weak_random_seed, String, equal_to: %w(1 0), default: '1'
include_dirs, Array, default: linux_config_dir/nrpe_local"
include_files, Array, default: []
default_commands, Boolean, default: true
```
If you wish to add extra config for NRPE, add your file to: `/usr/local/nagios/etc/nrpe_local`


## NSC Configuration (Windows)
There is currently minimal Configuration. To tune anything extra, please place your configuration file in:
`C:\Program Files\Opsview Agent\opsview.ini`

# Testing
When testing Linux, set the environment variable `OPSVIEW_REPO_KEY` to your licence key obtained from opsview

# Contributing
1. Fork the repository on Github
2. Create a named feature branch (like `add_component_x`)
3. Write your change
4. Write tests for your change (if applicable)
5. Run the tests, ensuring they all pass
6. Submit a Pull Request using Github

## License and Authors
Authors:
  * Rob Coward (rob@coward-family.net)
  * Tenyo Grozev (tenyo.grozev@yale.edu)

Copyright 2015 New Voice Media

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

