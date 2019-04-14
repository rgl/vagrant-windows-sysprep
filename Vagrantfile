Vagrant.configure(2) do |config|
  config.vm.box = "windows-2019-amd64"
  config.vm.hostname = "test-sysprep"
  config.vm.provider "libvirt" do |lv, config|
    lv.memory = 2048
    lv.cpus = 2
    lv.keymap = 'pt'
    config.vm.synced_folder '.', '/vagrant', type: 'smb', smb_username: ENV['USER'], smb_password: ENV['VAGRANT_SMB_PASSWORD']
  end
  config.vm.provider "virtualbox" do |vb|
    vb.linked_clone = true
    vb.memory = 2048
    vb.cpus = 2
  end
  config.vm.provision "shell", inline: <<-EOS
$windowsCurrentVersion = Get-ItemProperty 'HKLM:/SOFTWARE/Microsoft/Windows NT/CurrentVersion'
Write-Output "Windows name: $($windowsCurrentVersion.ProductName) $($windowsCurrentVersion.ReleaseId)"
Write-Output "Windows version: $($windowsCurrentVersion.CurrentMajorVersionNumber).$($windowsCurrentVersion.CurrentMinorVersionNumber).$($windowsCurrentVersion.CurrentBuildNumber).$($windowsCurrentVersion.UBR)"
Write-Output "Windows BuildLabEx version: $($windowsCurrentVersion.BuildLabEx)"
EOS
  config.vm.provision "shell", inline: "Write-Output \"%COMPUTERNAME% before sysprep: $env:COMPUTERNAME\""
  config.vm.provision "windows-sysprep"
  config.vm.provision "shell", inline: "Write-Output \"%COMPUTERNAME% after sysprep: $env:COMPUTERNAME\""
end
