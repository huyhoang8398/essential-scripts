function dns1111() {
  # detect existence of the backup file to see whether the config is in place
  if [[ -f /etc/dnsmasq.conf.bak ]]; then
    sudo mv /etc/dnsmasq.conf.bak /etc/dnsmasq.conf && echo 🚦 🚦 🚦
  else
    sudo cp /etc/dnsmasq.conf /etc/dnsmasq.conf.bak && \
    sudo echo -e "server=1.1.1.1\nserver=1.0.0.1\nserver=2606:4700:4700::1111\nserver=2606:4700:4700::1001" >> /etc/dnsmasq.conf && \
    sudo systemctl restart dnsmasq  && \
    sudo systemctl restart NetworkManager  && \
    echo 🚀 🚀 🚀
  fi
}
dns1111
