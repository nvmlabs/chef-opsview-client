describe service('opsview-agent') do
  it { should be_installed }
  it { should be_enabled }
  it { should be_running }
end

describe file('/usr/local/nagios/etc/nrpe.cfg') do
  it { should exist }
end
