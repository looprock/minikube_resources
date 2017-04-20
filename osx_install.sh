#!/bin/bash

# run: sudo visudo
# replace: %admin  ALL=(ALL) ALL
# with: %admin ALL=(ALL) NOPASSWD: ALL

function chkerr {
  if [ $1 -ne 0 ]; then
    echo "ERROR: $2, better call Saul!"
    exit 1
  fi
}


brew --version &>/dev/null
chkerr $? "this install script requires brew"


utuns=`ifconfig |grep "^utun" |wc -l`
if [ ! "$1" ]; then
  if [ $utuns -gt 1 ]; then
    echo "ERROR: found $utuns utun interfaces, please audit ifconfig and specify which one to use: $0 [utunX]"
    exit 1
  fi
fi

# firewall stuff
if [ "$1" ]; then
  tunname=$1
else
  tunname=`ifconfig |grep "^utun" |awk -F':' {'print $1'}`
fi
if [ `grep org.tunnat.pf /etc/pf.conf |wc -l` -gt 0 ]; then
  echo "Looks like you already have the firewall rules setup, skipping..."
else
  echo "Creating nat rules for ${tunname}..."
  echo "nat on {${tunname}} proto {tcp, udp, icmp} from 192.168.64.0/24 to any -> {${tunname}}" > /tmp/org.tunnat.pf.rules
  sudo mv /tmp/org.tunnat.pf.rules /etc/pf.anchors/org.tunnat.pf.rules
  sudo chown root:wheel /etc/pf.anchors/org.tunnat.pf.rules
  echo "Backing up old configuration to: /etc/pf.conf.bak"
  sudo cp /etc/pf.conf /etc/pf.conf.bak
  sudo cp /etc/pf.conf /tmp/pf.conf.bak
  cat /tmp/pf.conf.bak |sed $'s#rdr-anchor "com.apple.*$#rdr-anchor "com.apple/*"\\\nrdr-anchor "org.tunnat.pf/*"#' > /tmp/pf.conf
  echo 'load anchor "org.tunnat.pf" from "/etc/pf.anchors/org.tunnat.pf.rules"' >> /tmp/pf.conf
  sudo cp /tmp/pf.conf /etc/pf.conf
  sudo chown root:wheel /etc/pf.conf
  echo "Flushing firewall..."
  sudo pfctl -ef /etc/pf.conf
  chkerr $? "unable to apply firewall rules"
fi

echo "Creating firewall script because this doesn't seem to work yet and it hard to diagnose:"
cat > ~/fw-disable-tuntap.sh <<EOF
#!/bin/sh
RULE="nat on {${tunname}} proto {tcp, udp, icmp} from 192.168.64.0/24 to any -> {${tunname}}"
echo "$RULE" | sudo pfctl -a com.apple/tunnat -f -
EOF
chmod +x ~/fw-disable-tuntap.sh
echo "When and if you're not able to pull images, talk to the DB, etc. run:"
echo ""
echo "~/fw-disable-tuntap.sh"
echo ""


brew list docker-machine-driver-xhyve &>/dev/null
if [ $? -ne 0 ]; then
  echo "Installing xhyve hypervisor..."
  echo "NOTE: you will need to run $0 again to complete the pers"
  brew install opam libev
  brew install docker-machine-driver-xhyve --HEAD
  chkerr $? "unable to install xhyve"
  sudo chown root:wheel $(brew --prefix)/opt/docker-machine-driver-xhyve/bin/docker-machine-driver-xhyve
  sudo chmod u+s $(brew --prefix)/opt/docker-machine-driver-xhyve/bin/docker-machine-driver-xhyve
else
  echo "docker-machine-driver-xhyve installed, skipping installation..."
fi

brew list jq &>/dev/null
if [ $? -ne 0 ]; then
  echo "Installing JQ to get latest minikube release..."
  brew install jq
  chkerr $? "unable to install jq"
else
  echo "jq installed, skipping installation..."
fi

if [ ! -f "/usr/local/bin/minikube" ]; then
  mversion=`curl -s https://api.github.com/repos/kubernetes/minikube/releases/latest | jq -r .tag_name`
  echo "Installing minikube ${mversion}..."
  curl -Lo minikube https://storage.googleapis.com/minikube/releases/${mversion}/minikube-darwin-amd64
  chmod +x minikube
  mv minikube /usr/local/bin/

  echo "Initializing minikube..."
  minikube start --vm-driver=xhyve --v=5
  # minikube stop
  cat > ~/.minikube/config/config.json <<EOF
{
 "WantReportError": true,
 "ingress": true,
 "memory": 4096,
 "vm-driver": "xhyve"
}
EOF
else
  echo "/usr/local/bin/minkube found, skipping installation..."
fi
echo ""
echo "### it worked!"
echo "From here on, you should just need to execute:"
echo ""
echo "minikube start"
# echo "Starting minikube..."
# minikube start
