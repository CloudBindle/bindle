# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

PIPELINE_VM_COUNT = 1

DATABASE_VM_COUNT = 1

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  (1..PIPELINE_VM_COUNT).each do |i|

    config.vm.define "pipeline-#{i}" do |pipeline|
      pipeline.vm.box = "precise64"
      pipeline.vm.provision "shell", inline: "echo hello from pipeline #{i}"

      pipeline.vm.provider :virtualbox do |vb|
        vb.gui = false
        vb.customize ["modifyvm", :id, "--memory", "1024"]
      end
    end

  end

  (1..DATABASE_VM_COUNT).each do |i|

    config.vm.define "database-#{i}" do |database|
      database.vm.box = "precise64"
      database.vm.provision "shell", inline: "echo hello from database #{i}"

      database.vm.provider :virtualbox do |vb|
        vb.gui = false
        vb.customize ["modifyvm", :id, "--memory", "1024"]
      end
    end

  end

end
