opsview_client Cookbook
=======================
This cookbook:
- Opsview client
- Optionally registers the client with the server (TODO)


Usage
-----
This cookbook provides custom resources using `opsview_client` & `opsview_rest_client`, include these in your own recipe as you would do with a template or directory resource

#### `opsview_client`

## Windows Example
```ruby
opsview_client 'bob' do
  allowed_hosts '192.168.0.200'
  nsca_host '192.168.0.1'
  nsca_port '5667'
end
```

## Linux Example
```ruby
opsview_client 'bob' do
  allowed_hosts '192.1680.200'
  include_epel true
  repository_key 'super-long-key-from-opsview'
end
```

If you wish to add extra config for NRPE, add your file to the following places: 
- Linux: `/usr/local/nagios/etc/nrpe_local`
- Windows: `C:\Program Files\Opsview Agent\custom.ini`

Contributing
------------
1. Fork the repository on Github
2. Create a named feature branch (like `add_component_x`)
3. Write your change
4. Write tests for your change (if applicable)
5. Run the tests, ensuring they all pass
6. Submit a Pull Request using Github

License and Authors
-------------------
Authors:
  * Rob Coward (rob@coward-family.net)
  * Tenyo Grozev (tenyo.grozev@yale.edu)

Copyright 2015 New Voice Media

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
