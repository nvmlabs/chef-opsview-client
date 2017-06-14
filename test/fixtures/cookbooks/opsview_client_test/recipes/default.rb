opsview_client '22-06-15-2110' do
  server_address '127.0.0.1'
  repository_key node['opsview']['client']['repo_key']
end
