describe service('NSClientpp') do
  it { should be_installed }
  it { should be_enabled }
  it { should be_running }
end

describe file('C:\Program Files\Opsview Agent\NSC.ini') do
  it { should exist }
end
