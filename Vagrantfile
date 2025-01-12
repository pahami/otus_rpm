# -*- mode: ruby -*-
# vim: set ft=ruby :

Vagrant.configure(2) do |config|
    config.vm.box = "almalinux/9"

    config.vm.provider "virtualbox" do |v|
      v.memory = 1024
      v.cpus = 1
    end
  
    config.vm.define "rpm" do |rpm|
      rpm.vm.network "private_network", ip: "192.168.50.110", virtualbox__intnet: "net1"
      rpm.vm.hostname = "rpm"
      rpm.vm.provision "shell", path: "rpm.sh"
    end
end
