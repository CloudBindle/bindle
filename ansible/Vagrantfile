# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

WORKER_VM_COUNT = 1

DATABASE_VM_COUNT = 1

ENABLE_MASTER = true
ENABLE_WEBSERVER = false
ENABLE_DATABASE = false
ENABLE_WORKERS = true

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  ansible_groups = {
    "grid-master" => ["master"],
    "webapp" => ["webserver"],
    "grid-worker" => (1..WORKER_VM_COUNT).collect{ |i| "worker-#{i}" },
    "database" => (1..DATABASE_VM_COUNT).collect{ |i| "database-#{i}" },
    "all_groups:children" => ["grid-master", "grid-worker", "database", "webapp"]
  }

  @ansible_ip_addresses = {}
  @address_low = 4

  def get_next_address() 
    address = "192.168.50.#{@address_low}"
    @address_low = @address_low + 1
    return address
  end

  @ansible_ip_addresses["master"] = get_next_address()
  @ansible_ip_addresses["webserver"] = get_next_address()

  (1..WORKER_VM_COUNT).each do |i|
    @ansible_ip_addresses["worker-#{i}"] = get_next_address()
  end

  (1..DATABASE_VM_COUNT).each do |i|
    @ansible_ip_addresses["database-#{i}"] = get_next_address()
  end

  def configure_virtualbox(machine_name, machine) 
    address = @ansible_ip_addresses[machine_name]

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

  if ENABLE_MASTER
    config.vm.define "master" do |master|
      configure_virtualbox("master", master)

      master.vm.provision "ansible" do |ansible|
        ansible.playbook = "dummy-playbook.yml"
        ansible.groups = ansible_groups
        ansible.extra_vars = { original_hostname: "master" }
        # ansible.verbose = "vvvv"
      end
    end
  end

  if ENABLE_WEBSERVER
    config.vm.define "webserver" do |webserver|
      configure_virtualbox("webserver", webserver)
      webserver.vm.network "forwarded_port", guest: 443, host: 8443

      webserver.vm.provision "ansible" do |ansible|
        ansible.playbook = "dummy-playbook.yml"
        ansible.groups = ansible_groups
        ansible.extra_vars = { original_hostname: "webserver" }
        # ansible.verbose = "vvvv"
      end
    end
  end

  if ENABLE_WORKERS
    (1..WORKER_VM_COUNT).each do |i|
      vm_name = "worker-#{i}"

      config.vm.define vm_name do |pipeline|
        configure_virtualbox(vm_name, pipeline)

        pipeline.vm.provision "ansible" do |ansible|
          ansible.playbook = "dummy-playbook.yml"
          ansible.groups = ansible_groups
          ansible.extra_vars = { original_hostname: vm_name }
          # ansible.verbose = "vvvv"
        end
      end
    end
  end

  if ENABLE_DATABASE
    (1..DATABASE_VM_COUNT).each do |i|
      vm_name = "database-#{i}"

      config.vm.define vm_name do |database|
        configure_virtualbox(vm_name, database)

        database.vm.provision "ansible" do |ansible|
          ansible.playbook = "dummy-playbook.yml"
          ansible.groups = ansible_groups
          ansible.extra_vars = { original_hostname: vm_name }
          # ansible.verbose = "vvvv"
        end
      end
    end
  end

end
