# vagrant-ansible
Please change the IP addresses in Vagrantfile and bootstrap.sh.
The default is `192.168.56.xxx`.

## Vagrantfile
```ruby
  config.vm.define :ansible do |ansible|
    ansible.vm.hostname = "centos7-02"
    ansible.vm.network "private_network", ip: "192.168.56.126", nic_type: "virtio"
  end

  config.vm.define :target do |target|
    target.vm.hostname = "centos7-03"
    target.vm.network "private_network", ip: "192.168.56.125", nic_type: "virtio"
  end
```

## bootstrap.sh
```sh
TARGET_FILE=hosts
grep -F '192.168.56.' ${TARGET_FILE} &>/dev/null
RET=$?
...
    cat <<- EOF >> ${TARGET_FILE}
	192.168.56.120	centos7-08	centos7-08.localdomain
	192.168.56.121	centos7-07	centos7-07.localdomain
	192.168.56.122	centos7-06	centos7-06.localdomain
	192.168.56.123	centos7-05	centos7-05.localdomain
	192.168.56.124	centos7-04	centos7-04.localdomain
	192.168.56.125	centos7-03	centos7-03.localdomain
	192.168.56.126	centos7-02	centos7-02.localdomain
	192.168.56.127	centos7-01	centos7-01.localdomain
EOF
    diff -u ${BACKUP_FILE} ${TARGET_FILE}
fi
```
