#!/bin/bash
#!/bin/bash

print_banner() {
    cat << "EOF"
  ▄▄                                    ▄▄    ▄▄                                                              ▄▄            ▄▄        
  ██                     ██           ▀███  ▀███     ▀████▄     ▄███▀         ██                            ▀███            ██   ██   
                         ██             ██    ██       ████    ████           ██                              ██                 ██   
▀███ ▀████████▄  ▄██▀████████ ▄█▀██▄    ██    ██       █ ██   ▄█ ██   ▄▄█▀████████ ▄█▀██▄  ▄██▀███████████▄   ██   ▄██▀██▄▀███ ██████ 
  ██   ██    ██  ██   ▀▀ ██  ██   ██    ██    ██       █  ██  █▀ ██  ▄█▀   ██ ██  ██   ██  ██   ▀▀ ██   ▀██   ██  ██▀   ▀██ ██   ██   
  ██   ██    ██  ▀█████▄ ██   ▄█████    ██    ██       █  ██▄█▀  ██  ██▀▀▀▀▀▀ ██   ▄█████  ▀█████▄ ██    ██   ██  ██     ██ ██   ██   
  ██   ██    ██  █▄   ██ ██  ██   ██    ██    ██       █  ▀██▀   ██  ██▄    ▄ ██  ██   ██  █▄   ██ ██   ▄██   ██  ██▄   ▄██ ██   ██   
▄████▄████  ████▄██████▀ ▀████████▀██▄▄████▄▄████▄   ▄███▄ ▀▀  ▄████▄ ▀█████▀ ▀████████▀██▄██████▀ ██████▀  ▄████▄ ▀█████▀▄████▄ ▀████
                                                                                               ██                                 
                                                                                             ▄████▄                                
EOF
}

print_banner


set -e  # Exit on error
#set -x  # Debug mode 

echo -e "Updating system\n"
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm base-devel curl gpg git postgresql

echo -e "Managing permissions\n"
sudo mkdir -p /usr/share/rvm
sudo chown -R "$USER:$USER" /usr/share/rvm

echo -e "Setting up rvm and installin rubgy for metasploit\n"
gpg --keyserver keyserver.ubuntu.com --recv-keys \
    409B6B1796C275462A1703113804BB82D39DC0E3 \
    7D2BAF1CF37B13E2069D6956105BD0E739499BDB
curl -sSL https://get.rvm.io | sudo bash -s stable --path /usr/share/rvm
echo "source /usr/share/rvm/scripts/rvm" >> ~/.zshrc
source ~/.zshrc
RUBY_VERSION=$(curl -s https://raw.githubusercontent.com/rapid7/metasploit-framework/master/.ruby-version)

if [[ -z "$RUBY_VERSION" ]]; then
    echo "Error: Failed to fetch Ruby version."
    exit 1
fi
rvm install "$RUBY_VERSION"
rvm use "$RUBY_VERSION" --default

echo -e "Setting up PostgreSQL\n"
sudo chown -R postgres:postgres /var/lib/postgres
sudo -u postgres initdb --locale en_US.UTF-8 -E UTF8 -D '/var/lib/postgres/data'
sudo systemctl enable --now postgresql
sudo -u postgres psql <<EOF
CREATE USER msf WITH PASSWORD 'msf';
ALTER USER msf WITH SUPERUSER;
CREATE DATABASE msf OWNER msf;
EOF

echo -e "setting up metasploit\n"
sudo git clone https://github.com/rapid7/metasploit-framework /opt/metasploit
sudo chown -R "$(whoami):$(whoami)" /opt/metasploit
cd "/opt/metasploit"
gem install wirble sqlite3 bundler
bundle install

echo -e "Configuring Metasploit database\n"
cat <<EOF | sudo tee /opt/metasploit/config/database.yml
production:
  adapter: postgresql
  database: msf
  username: msf
  password: msf
  host: 127.0.0.1
  port: 5432
  pool: 75
  timeout: 5
EOF

echo "export MSF_DATABASE_CONFIG=/opt/metasploit/config/database.yml" | sudo tee -a /etc/profile

echo -e "Metasploit installation complete!"
