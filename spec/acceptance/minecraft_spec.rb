# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'minecraft' do
  # screen is only available from EPEL on EL
  before(:all) do
    shell('dnf -y install epel-release') if fact('os.family') == 'RedHat'
  end

  # The running server rewrites server.properties and ops.txt, so the
  # manifests are not idempotent once it has started.
  context 'with defaults' do
    it 'applies twice without errors' do
      2.times { apply_manifest('include minecraft', catch_failures: true) }
    end

    describe package('screen') do
      it { is_expected.to be_installed }
    end

    describe user('minecraft') do
      it { is_expected.to exist }
      it { is_expected.to belong_to_primary_group 'minecraft' }
      it { is_expected.to have_home_directory '/opt/minecraft' }
    end

    describe file('/opt/minecraft/minecraft_server.jar') do
      it { is_expected.to be_file }
      it { is_expected.to be_owned_by 'minecraft' }
    end

    describe file('/opt/minecraft/eula.txt') do
      its(:content) { is_expected.to match %r{^eula=true} }
    end

    describe file('/opt/minecraft/server.properties') do
      its(:content) { is_expected.to match %r{^server-port=25565$} }
      its(:content) { is_expected.to match %r{^motd=A Minecraft Server$} }
    end

    describe service('minecraft') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    # the server needs some time to generate the world before it listens
    describe command("timeout 300 bash -c 'until echo > /dev/tcp/127.0.0.1/25565; do sleep 5; done'") do
      its(:exit_status) { is_expected.to eq 0 }
    end

    describe port(25_565) do
      it { is_expected.to be_listening }
    end
  end

  context 'with custom parameters' do
    let(:manifest) do
      <<-PUPPET
      class { 'minecraft':
        heap_size          => 512,
        motd               => 'Managed by Puppet',
        ops                => ['op1', 'op2'],
        white_list         => true,
        white_list_players => ['player1'],
      }
      PUPPET
    end

    it 'applies twice without errors' do
      2.times { apply_manifest(manifest, catch_failures: true) }
    end

    describe file('/etc/init.d/minecraft') do
      its(:content) { is_expected.to match %r{^MAX_HEAP="512"$} }
    end

    describe file('/opt/minecraft/server.properties') do
      its(:content) { is_expected.to match %r{^motd=Managed by Puppet$} }
      its(:content) { is_expected.to match %r{^white-list=true$} }
    end

    describe file('/opt/minecraft/ops.txt') do
      its(:content) { is_expected.to eq "op1\nop2\n" }
    end

    describe file('/opt/minecraft/white-list.txt') do
      its(:content) { is_expected.to match %r{^player1$} }
    end

    describe service('minecraft') do
      it { is_expected.to be_running }
    end
  end
end
