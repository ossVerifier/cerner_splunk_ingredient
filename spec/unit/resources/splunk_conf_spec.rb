# frozen_string_literal: true

require_relative '../spec_helper'
include CernerSplunk::ResourceHelpers

shared_examples 'splunk_conf' do |platform, version, package|
  let(:runner_params) { { platform: platform, version: version, user: 'root' } }
  chef_describe 'action :configure' do
    let(:config) { { a: { 'foo' => 'bar', 'one' => 1 } } }
    let(:existing_config) { { 'a' => { 'foo' => 'bar' } } }
    let(:expected_state_config) { { 'a' => { 'foo' => 'bar', 'one' => 1 } } }
    let(:expected_config) { { 'a' => { 'foo' => 'bar', 'one' => '1' } } }
    let(:action) { :configure }

    let(:install_dir) { CernerSplunk::PathHelpers.default_install_dirs[package][platform == 'windows' ? :windows : :linux] }
    let(:mock_run_state) do
      install = {
        name: package.to_s,
        path: install_dir,
        package: package,
        version: '6.3.4',
        build: 'cae2458f4aef',
        x64: true
      }
      {
        'splunk_ingredient' => {
          'installations' => {
            install_dir => install
          },
          'current_installation' => install
        }
      }
    end

    let(:chef_run_stubs) do
      expect_any_instance_of(Chef::Resource).to receive(:load_installation_state).and_return true
      expect(CernerSplunk::ConfHelpers).to receive(:read_config).with(conf_path).and_return(existing_config)
      expect(CernerSplunk::ConfHelpers).to receive(:merge_config).with(existing_config, expected_config).and_return 'merged config'
      expect(CernerSplunk::ConfHelpers).to receive(:filter_config).with('merged config').and_return 'merged config'
      allow_any_instance_of(Chef::Resource).to receive(:current_owner).and_return(platform == 'windows' ? 'administrator' : 'fauxhai')
      allow_any_instance_of(Chef::Resource).to receive(:current_group).and_return(platform == 'windows' ? 'host\NONE' : 'fauxhai')
    end

    let(:conf_path) { Pathname.new(install_dir) + 'etc/system/local/test.conf' }

    chef_context 'when all parameters provided' do
      let(:test_params) do
        {
          path: 'system/test.conf',
          package: package,
          scope: :default,
          config: config,
          user: package.to_s,
          action: action
        }
      end

      let(:conf_path) { Pathname.new(install_dir) + 'etc/system/default/test.conf' }
      let(:expected_params) do
        {
          path: conf_path,
          package: package,
          scope: :default,
          config: expected_config,
          user: package.to_s
        }
      end

      it { is_expected.to configure_splunk('system/test.conf').with expected_params }
      it { is_expected.to create_template(conf_path).with(source: 'conf.erb', variables: { config: 'merged config' }, owner: package.to_s) }
      it { is_expected.to init_splunk_service('init_before_config') }
    end

    chef_context 'when install_dir is provided' do
      let(:install_dir) { platform == 'windows' ? 'C:\\Splunk' : '/etc/splunk' }
      let(:conf_path) { Pathname.new(install_dir) + 'etc/system/default/test.conf' }

      let(:test_params) do
        {
          path: 'system/test.conf',
          package: package,
          scope: :default,
          config: config,
          install_dir: install_dir,
          user: package.to_s,
          action: action
        }
      end

      let(:expected_params) do
        {
          path: conf_path,
          package: package,
          scope: :default,
          install_dir: install_dir,
          config: expected_config,
          user: package.to_s
        }
      end

      it { is_expected.to configure_splunk('system/test.conf').with expected_params }

      chef_context 'without package' do
        let(:test_params) do
          {
            path: 'system/test.conf',
            scope: :default,
            config: config,
            install_dir: install_dir,
            user: package.to_s,
            action: action
          }
        end

        let(:expected_params) do
          {
            path: conf_path,
            package: package,
            scope: :default,
            install_dir: install_dir,
            config: expected_config,
            user: package.to_s
          }
        end

        it { is_expected.to configure_splunk('system/test.conf').with expected_params }
      end
    end

    chef_context 'when scope is not provided' do
      let(:test_params) do
        {
          path: 'system/local/test.conf',
          package: package,
          config: config,
          user: package.to_s,
          action: action
        }
      end

      it { is_expected.to configure_splunk('system/local/test.conf') }

      chef_context 'when the path does not include scope' do
        let(:test_params) do
          {
            path: 'system/test.conf',
            package: package,
            config: config,
            user: package.to_s,
            action: action
          }
        end

        it { is_expected.to configure_splunk('system/test.conf').with scope: :local }
      end
    end

    chef_context 'when package is not provided' do
      let(:test_params) do
        {
          path: 'system/test.conf',
          scope: :local,
          config: config,
          user: package.to_s,
          action: action
        }
      end

      it { is_expected.to configure_splunk('system/test.conf') }

      chef_context 'when prior install is in a non-default location' do
        let(:install_dir) { platform == 'windows' ? 'C:\Splunk' : '/etc/splunk' }
        let(:conf_path) { Pathname.new(install_dir) + 'etc/system/local/test.conf' }
        let(:expected_params) do
          {
            path: conf_path,
            package: package,
            install_dir: install_dir,
            scope: :local,
            config: expected_config,
            user: package.to_s
          }
        end

        it { is_expected.to configure_splunk('system/test.conf').with expected_params }
        it { is_expected.to create_template(conf_path).with(source: 'conf.erb', variables: { config: 'merged config' }, owner: package.to_s) }
        it { is_expected.to init_splunk_service('init_before_config') }
      end

      chef_context 'without a prior install' do
        let(:chef_run_stubs) {}
        let(:mock_run_state) do
          install = {
            name: package.to_s,
            path: install_dir,
            package: package,
            version: '6.3.4',
            build: 'cae2458f4aef',
            x64: true
          }
          {
            'splunk_ingredient' => {
              'installations' => {
                install_dir => install
              }
            }
          }
        end

        it 'should fail the chef run' do
          expect { subject }.to raise_error Chef::Exceptions::ValidationFailed, /package is required$/
        end
      end
    end

    chef_context 'when config is not provided' do
      let(:test_params) do
        {
          path: 'system/test.conf',
          scope: :local,
          user: package.to_s,
          action: action
        }
      end
      let(:chef_run_stubs) {}

      it 'should fail the chef run' do
        expect { subject }.to raise_error Chef::Exceptions::ValidationFailed, /config is required$/
      end

      chef_context 'when reset is specified' do
        let(:test_params) do
          {
            path: 'system/test.conf',
            scope: :local,
            user: package.to_s,
            action: action,
            reset: true
          }
        end

        it 'should fail the chef run' do
          expect { subject }.to raise_error Chef::Exceptions::ValidationFailed, /config is required$/
        end
      end
    end

    chef_context 'when user is not specified' do
      let(:test_params) do
        {
          path: 'system/test.conf',
          package: package,
          scope: :local,
          config: config,
          action: action
        }
      end

      it { is_expected.to configure_splunk('system/test.conf') }
      it { is_expected.to create_template(conf_path).with(source: 'conf.erb', variables: { config: 'merged config' }, owner: platform == 'windows' ? 'administrator' : 'fauxhai') }
    end

    chef_context 'when reset is specified' do
      let(:test_params) do
        {
          path: 'system/test.conf',
          package: package,
          user: package.to_s,
          scope: :local,
          config: config,
          reset: true,
          action: action
        }
      end
      let(:chef_run_stubs) do
        expect_any_instance_of(Chef::Resource).to receive(:load_installation_state).and_return true
        expect(CernerSplunk::ConfHelpers).to receive(:read_config).with(conf_path).and_return(existing_config)
        expect(CernerSplunk::ConfHelpers).to receive(:merge_config).with({}, expected_config).and_return 'just my config'
        expect(CernerSplunk::ConfHelpers).to receive(:filter_config).with('just my config').and_return 'just my config'
        allow_any_instance_of(Chef::Resource).to receive(:current_group).and_return(platform == 'windows' ? 'host\NONE' : 'fauxhai')
      end

      it { is_expected.to configure_splunk('system/test.conf') }
      it { is_expected.to create_template(conf_path).with(source: 'conf.erb', variables: { config: 'just my config' }, owner: package.to_s) }
    end

    chef_context 'when conf_override is set in the run state' do
      let(:test_params) do
        {
          path: 'system/test.conf',
          package: package,
          user: package.to_s,
          scope: :local,
          config: config,
          action: action
        }
      end

      let(:mock_run_state) do
        install = {
          name: package.to_s,
          path: install_dir,
          package: package,
          version: '6.3.4',
          build: 'cae2458f4aef',
          x64: true
        }
        {
          'splunk_ingredient' => {
            'installations' => {
              install_dir => install
            },
            'current_installation' => install,
            'conf_override' => {
              conf_path: 'apps/test_app/local',
              scope: :none,
              user: 'otherbody'
            }
          }
        }
      end

      let(:conf_path) { Pathname.new(install_dir) + 'etc/apps/test_app/local/test.conf' }

      it { is_expected.to configure_splunk('system/test.conf') }
      it { is_expected.to create_template(conf_path).with(source: 'conf.erb', variables: { config: 'merged config' }, owner: 'otherbody') }
    end
  end

  chef_describe 'action :delete' do
    let(:config) { { a: { 'foo' => 'bar', 'one' => 1 } } }
    let(:existing_config) { { 'a' => { 'foo' => 'bar' } } }
    let(:expected_state_config) { { 'a' => { 'foo' => 'bar', 'one' => 1 } } }
    let(:expected_config) { { 'a' => { 'foo' => 'bar', 'one' => '1' } } }
    let(:action) { :delete }

    let(:install_dir) { CernerSplunk::PathHelpers.default_install_dirs[package][platform == 'windows' ? :windows : :linux] }
    let(:mock_run_state) do
      install = {
        name: package.to_s,
        path: install_dir,
        package: package,
        version: '6.3.4',
        build: 'cae2458f4aef',
        x64: true
      }
      {
        'splunk_ingredient' => {
          'installations' => {
            install_dir => install
          },
          'current_installation' => install
        }
      }
    end

    let(:chef_run_stubs) do
      expect_any_instance_of(Chef::Resource).to receive(:load_installation_state).and_return true
    end

    let(:conf_path) { Pathname.new(install_dir) + 'etc/system/local/test.conf' }

    chef_context 'when all parameters provided' do
      let(:test_params) do
        {
          path: 'system/test.conf',
          package: package,
          scope: :default,
          config: config,
          user: package.to_s,
          action: action
        }
      end

      let(:conf_path) { Pathname.new(install_dir) + 'etc/system/default/test.conf' }

      it { is_expected.to delete_splunk_conf('system/test.conf').with path: conf_path }
      it { is_expected.to delete_template(conf_path) }
    end

    chef_context 'when install_dir is provided' do
      let(:install_dir) { platform == 'windows' ? 'C:\\Splunk' : '/etc/splunk' }
      let(:conf_path) { Pathname.new(install_dir) + 'etc/system/default/test.conf' }

      let(:test_params) do
        {
          path: 'system/test.conf',
          package: package,
          scope: :default,
          config: config,
          install_dir: install_dir,
          user: package.to_s,
          action: action
        }
      end

      it { is_expected.to delete_splunk_conf('system/test.conf').with path: conf_path }

      chef_context 'without package' do
        let(:test_params) do
          {
            path: 'system/test.conf',
            scope: :default,
            config: config,
            install_dir: install_dir,
            user: package.to_s,
            action: action
          }
        end

        it { is_expected.to delete_splunk_conf('system/test.conf').with path: conf_path }
      end
    end

    chef_context 'when scope is not provided' do
      let(:test_params) do
        {
          path: 'system/local/test.conf',
          package: package,
          config: config,
          user: package.to_s,
          action: action
        }
      end

      it { is_expected.to delete_splunk_conf('system/local/test.conf') }

      chef_context 'when the path does not include scope' do
        let(:test_params) do
          {
            path: 'system/test.conf',
            package: package,
            config: config,
            user: package.to_s,
            action: action
          }
        end

        it { is_expected.to delete_splunk_conf('system/test.conf').with scope: :local }
      end
    end

    chef_context 'when package is not provided' do
      let(:test_params) do
        {
          path: 'system/test.conf',
          scope: :local,
          config: config,
          user: package.to_s,
          action: action
        }
      end

      it { is_expected.to delete_splunk_conf('system/test.conf') }

      chef_context 'when prior install is in a non-default location' do
        let(:install_dir) { platform == 'windows' ? 'C:\Splunk' : '/etc/splunk' }
        let(:conf_path) { Pathname.new(install_dir) + 'etc/system/local/test.conf' }

        it { is_expected.to delete_splunk_conf('system/test.conf').with path: conf_path }
        it { is_expected.to delete_template(conf_path) }
      end

      chef_context 'without a prior install' do
        let(:chef_run_stubs) {}
        let(:mock_run_state) do
          install = {
            name: package.to_s,
            path: install_dir,
            package: package,
            version: '6.3.4',
            build: 'cae2458f4aef',
            x64: true
          }
          {
            'splunk_ingredient' => {
              'installations' => {
                install_dir => install
              }
            }
          }
        end

        it 'should fail the chef run' do
          expect { subject }.to raise_error Chef::Exceptions::ValidationFailed, /package is required$/
        end
      end
    end

    chef_context 'when config is not provided' do
      let(:test_params) do
        {
          path: 'system/test.conf',
          scope: :local,
          user: package.to_s,
          action: action
        }
      end
      let(:chef_run_stubs) {}

      it { is_expected.to delete_splunk_conf('system/test.conf') }
      it { is_expected.to delete_template(conf_path) }
    end

    chef_context 'when user is not specified' do
      let(:test_params) do
        {
          path: 'system/test.conf',
          package: package,
          scope: :local,
          config: config,
          action: action
        }
      end

      it { is_expected.to delete_splunk_conf('system/test.conf') }
      it { is_expected.to delete_template(conf_path) }
    end

    chef_context 'when reset is specified' do
      let(:test_params) do
        {
          path: 'system/test.conf',
          package: package,
          user: package.to_s,
          scope: :local,
          config: config,
          reset: true,
          action: action
        }
      end

      it { is_expected.to delete_splunk_conf('system/test.conf') }
      it { is_expected.to delete_template(conf_path) }
    end
  end
end

describe 'splunk_conf' do
  let(:test_resource) { 'splunk_conf' }
  let(:test_recipe) { 'config_unit_test' }

  environment_combinations.each do |platform, version, package, _|
    context "on #{platform} #{version}" do
      context "with package #{package}" do
        include_examples 'splunk_conf', platform, version, package
      end
    end
  end
end
