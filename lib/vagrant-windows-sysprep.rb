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
            original_machine_computer_name = ''
            info_remote_path = "C:/Windows/Temp/vagrant-windows-sysprep-info.ps1"
            @machine.communicate.upload(
              File.join(File.dirname(__FILE__), "vagrant-windows-sysprep", "info.ps1"),
              info_remote_path)
            info_command = "#{ps} -File #{info_remote_path}"
            @machine.communicate.sudo(info_command, {elevated: true, interactive: false}) do |type, data|
              original_machine_sid = $1.strip if data =~ /This Machine SID is (.+)/
              original_machine_computer_name = $1.strip if data =~ /This Machine ComputerName is (.+)/
            end

            unattend_remote_path = "C:/Windows/Temp/vagrant-windows-sysprep-unattend.xml"
            @machine.communicate.upload(
              File.join(File.dirname(__FILE__), "vagrant-windows-sysprep", "unattend.xml"),
              unattend_remote_path)

            sysprep_remote_path = "C:/Windows/Temp/vagrant-windows-sysprep.ps1"
            @machine.communicate.upload(
              File.join(File.dirname(__FILE__), "vagrant-windows-sysprep", "sysprep.ps1"),
              sysprep_remote_path)
            sysprep_command = "#{ps} -File #{sysprep_remote_path} -Username \"#{@machine.config.winrm.username}\" -Password \"#{@machine.config.winrm.password}\""
            begin
              @machine.communicate.sudo(sysprep_command, {elevated: true, interactive: false}) do |type, data|
                handle_comm(type, data)
              end
            rescue
              # ignored. this should be due to the shutdown that sysprep does.
            end

            # wait for the machine to be shutdown.
            # NB :poweroff    is used by the VirtualBox provider.
            # NB :shutoff     is used by the libvirt provider.
            # NB :off         is used by the Hyper-V provider.
            # NB :not_running is used by the VMware Desktop provider.
            until [:poweroff, :shutoff, :off, :not_running].include? @machine.state.id
              sleep 10
            end

            options = {}
            options[:provision_ignore_sentinel] = false
            @machine.action(:up, options)

            machine_sid = ''
            machine_computer_name = ''
            @machine.communicate.sudo(info_command, {elevated: true, interactive: false}) do |type, data|
              machine_sid = $1.strip if data =~ /This Machine SID is (.+)/
              machine_computer_name = $1.strip if data =~ /This Machine ComputerName is (.+)/
            end

            # NB there's a bug somewhere in windows sysprep machinery that prevents it from setting the
            #    ComputerName when the name doesn't really change (like when you use config.vm.hostname),
            #    it will instead set the ComputerName to something like WIN-0F47SUATAF5.
            #    this workaround will compensate for that by renaming the computer.
            # NB sysprep works in Windows 2016 14393.2906.
            # NB sysprep fails in Windows 2019 17763.437.
            if machine_computer_name != original_machine_computer_name
              @machine.ui.info "Sysprep did not correctly set ComputerName... renaming it from #{machine_computer_name} to #{original_machine_computer_name}..."
              @machine.guest.capability(:change_host_name, original_machine_computer_name)
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
