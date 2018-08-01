begin
  require "vagrant"
rescue LoadError
  raise "The Vagrant Windows Sysprep plugin must be run within Vagrant."
end

if Vagrant::VERSION < "2.1.2"
  raise "The Vagrant Windows Sysprep plugin is only compatible with Vagrant 2.1.2+"
end

module VagrantPlugins
  module WindowsSysprep
    class Plugin < Vagrant.plugin("2")
      name "Windows Sysprep"
      description "Vagrant plugin to run Windows sysprep as a provisioning step."

      provisioner "windows-sysprep" do
        class Provisioner < Vagrant.plugin("2", :provisioner)
          def initialize(machine, config)
            super
          end

          def configure(root_config)
          end

          # see https://github.com/hashicorp/vagrant/blob/master/lib/vagrant/machine.rb
          # see https://github.com/hashicorp/vagrant/blob/master/lib/vagrant/machine_state.rb
          # see https://github.com/hashicorp/vagrant/blob/master/lib/vagrant/ui.rb
          # see https://github.com/hashicorp/vagrant/blob/master/lib/vagrant/plugin/v2/provisioner.rb
          # see https://github.com/hashicorp/vagrant/blob/master/lib/vagrant/plugin/v2/communicator.rb
          # see https://github.com/hashicorp/vagrant/blob/master/plugins/provisioners/shell/provisioner.rb
          def provision
            ps = 'PowerShell -ExecutionPolicy Bypass -OutputFormat Text'

            original_machine_sid = ''
            show_sid_remote_path = "C:/Windows/Temp/vagrant-windows-sysprep-show-sid.ps1"
            @machine.communicate.upload(
              File.join(File.dirname(__FILE__), "vagrant-windows-sysprep", "show-sid.ps1"),
              show_sid_remote_path)
            show_sid_command = "#{ps} -File #{show_sid_remote_path}"
            @machine.communicate.sudo(show_sid_command, {elevated: true, interactive: false}) do |type, data|
              original_machine_sid = $1.strip if data =~ /This Machine SID is (.+)/
            end

            autounattend_remote_path = "C:/Windows/Temp/vagrant-windows-sysprep-autounattend.xml"
            @machine.communicate.upload(
              File.join(File.dirname(__FILE__), "vagrant-windows-sysprep", "autounattend.xml"),
              autounattend_remote_path)
            sysprep_command = "#{ps} -Command 'Start-Process -Wait C:/Windows/System32/Sysprep/sysprep /generalize,/oobe,/quiet,/shutdown,/unattend:#{autounattend_remote_path}'"
            begin
              @machine.communicate.sudo(sysprep_command, {elevated: true, interactive: false}) do |type, data|
                handle_comm(type, data)
              end
            rescue
              # ignored. this should be due to the shutdown that sysprep does.
            end

            # wait for the machine to be shutdown.
            # NB :poweroff is used by the VirtualBox provider.
            # NB :shutoff  is used by the libvirt provider.
            until [:poweroff, :shutoff].include? @machine.state.id
              sleep 10
            end

            options = {}
            options[:provision_ignore_sentinel] = false
            @machine.action(:up, options)

            machine_sid = ''
            @machine.communicate.sudo(show_sid_command, {elevated: true, interactive: false}) do |type, data|
              machine_sid = $1.strip if data =~ /This Machine SID is (.+)/
            end
            @machine.ui.success "The Machine SID was changed from #{original_machine_sid} to #{machine_sid}"
          end

          def cleanup
          end

          protected

          # This handles outputting the communication data back to the UI
          def handle_comm(type, data)
            if [:stderr, :stdout].include?(type)
              # Output the data with the proper color based on the stream.
              color = type == :stdout ? :green : :red

              # Clear out the newline since we add one
              data = data.chomp
              return if data.empty?

              options = {}
              options[:color] = color if !config.keep_color

              @machine.ui.info(data.chomp, options)
            end
          end
        end

        Provisioner
      end
    end
  end
end