# Vagrant Windows Sysprep Provisioner

This is a Vagrant plugin to sysprep Windows.

**NB** This was only tested with Vagrant 1.9.2 and Windows Server 2016.

# Installation

```bash
vagrant plugin install vagrant-windows-sysprep
```

# Usage

Add `config.vm.provision "windows-sysprep"` to your `Vagrantfile` to sysprep your
Windows VM during provisioning or manually run the provisioner with:

```bash
vagrant provision --provision-with windows-sysprep
```

To troubleshoot, set the `VAGRANT_LOG` environment variable to `debug`.

## Example

In this repo there's an example [Vagrantfile](Vagrantfile). Use it to launch
an example.

First install the [Base Windows Box](https://github.com/rgl/windows-2016-vagrant).

Then launch the example:

```bash
vagrant up
```

# Development

To hack on this plugin you need to install [Bundler](http://bundler.io/)
and other dependencies. On Ubuntu:

```bash
sudo apt install bundler libxml2-dev zlib1g-dev
```

Then use it to install the dependencies:

```bash
bundle
```

Build this plugin gem:

```bash
rake
```

Then install it into your local vagrant installation:

```bash
vagrant plugin install pkg/vagrant-windows-sysprep-*.gem
```

You can later run everything in one go:

```bash
rake && vagrant plugin uninstall vagrant-windows-sysprep && vagrant plugin install pkg/vagrant-windows-sysprep-*.gem
```
