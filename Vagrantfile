# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

WORKER_VM_COUNT = 1

DATABASE_VM_COUNT = 1

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  ansible_groups = {
    "grid-master" => ["master"],
    "grid-worker" => (1..WORKER_VM_COUNT).collect{ |i| "worker-#{i}" },
    "database" => (1..DATABASE_VM_COUNT).collect{ |i| "database-#{i}" },
    "all_groups:children" => ["grid-master", "grid-worker", "database"]
  }

  @address_low = 4

  def configure_virtualbox(machine) 
    address = "192.168.50.#{@address_low}"
    @address_low = @address_low + 1

    machine.vm.box = "precise64"
    machine.vm.network "private_network", virtualbox__intnet: true, ip: address

    machine.vm.provider :virtualbox do |vb|
      vb.gui = false
      vb.customize ["modifyvm", :id, "--memory", "1024"]
    end

  end

  # We use a dummy playbook because (a) we want the ansible provisioner
  # to build an inventory but (b) we want to save the actual provisioning
  # until later so ansible can wire together systems effectively. See the
  # issue at: https://github.com/mitchellh/vagrant/issues/1784
  # There is no realworkaround on this yet. 

  config.vm.define "master" do |pipeline|
    configure_virtualbox(pipeline)

    pipeline.vm.provision "ansible" do |ansible|
      ansible.playbook = "dummy-playbook.yml"
      ansible.groups = ansible_groups
      ansible.extra_vars = { original_hostname: "master" }
      # ansible.verbose = "vvvv"
    end
  end


  (1..WORKER_VM_COUNT).each do |i|

    vm_name = "worker-#{i}"

    config.vm.define vm_name do |pipeline|
      configure_virtualbox(pipeline)

      pipeline.vm.provision "ansible" do |ansible|
        ansible.playbook = "dummy-playbook.yml"
        ansible.groups = ansible_groups
        ansible.extra_vars = { original_hostname: vm_name }
        # ansible.verbose = "vvvv"
      end
    end

  end

  (1..DATABASE_VM_COUNT).each do |i|

    vm_name = "database-#{i}"

    config.vm.define vm_name do |database|
      configure_virtualbox(database)

      database.vm.provision "ansible" do |ansible|
        ansible.playbook = "dummy-playbook.yml"
        ansible.groups = ansible_groups
        ansible.extra_vars = { original_hostname: vm_name }
        # ansible.verbose = "vvvv"
      end
    end

  end

end
