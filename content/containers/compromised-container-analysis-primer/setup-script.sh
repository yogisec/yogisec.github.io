#!/bin/bash

RED='\033[0;31m'
NC='\033[0m' # No Color

apt update
apt install git zip -y
mkdir git

echo -e "\n${RED}Installing Linux Headers${NC}\n"
apt install linux-headers-$(uname -r) -y

echo -e "\n${RED}Installing python2${NC}\n"
apt install python2 python-dev -y
curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output get-pip.py
python2 get-pip.py
python2 -m pip install distorm3 pycrypto

echo -e "\n${RED}Installing pip3${NC}\n"
apt install python3-pip -y

echo -e "\n${RED}Installing Go${NC}\n"
cd /home/ubuntu
wget https://go.dev/dl/go1.18.1.linux-amd64.tar.gz
rm -rf /usr/local/go && tar -C /usr/local -xzf go1.18.1.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
go version
echo -e "\n${RED}Done with go you may need to export PATH=$PATH:/usr/local/go/bin${NC}\n"

echo -e  "\n${RED}Installing Rust and AVML"
cd /home/ubuntu/git
git clone https://github.com/microsoft/avml.git
cd avml
apt-get install musl-dev musl-tools musl -y
curl https://sh.rustup.rs -sSf | sh -s -- -y
source $HOME/.cargo/env
rustup target add x86_64-unknown-linux-musl
cargo build --release --target x86_64-unknown-linux-musl
cp /home/ubuntu/git/avml/target/x86_64-unknown-linux-musl/release/avml /home/ubuntu/avml
cp /home/ubuntu/git/avml/target/x86_64-unknown-linux-musl/release/avml-convert /home/ubuntu/avml-convert

echo -e "\n${RED}Installing LiME${NC}\n"
cd /home/ubuntu/git 
git clone https://github.com/504ensicsLabs/LiME.git
apt install make gcc -y
cd /home/ubuntu/git/LiME/src
make
mv lime-$(uname -r).ko /home/ubuntu/lime-$(uname -r).ko

echo -e "\n${RED}Installing Volatility${NC}\n"
cd /home/ubuntu/git
git clone https://github.com/volatilityfoundation/volatility.git

echo -e "\n${RED}Building a profile for kernel $(uname -r)${NC}\n"
apt install dwarfdump build-essential
cd volatility/tools/linux
echo 'MODULE_LICENSE("GPL");' >> module.c
make
cp /boot/System.map-`uname -r` .
zip ubuntu-$(uname -r).zip module.dwarf System.map-$(uname -r)
mv ubuntu-$(uname -r).zip /home/ubuntu/git/volatility/volatility/plugins/overlays/linux/
echo -e "\n${RED}Done making profile please copy it to the volatility/plugs/overlays/linux folder${NC}\n"

echo -e "\n${RED}Installing Volatility3${NC}\n"
cd /home/ubuntu/git
git clone https://github.com/volatilityfoundation/volatility3.git
cd volatility3
pip3 install -r requirements.txt

echo -e "\n${RED}Installing dwarf2json${NC}\n"
#https://github.com/volatilityfoundation/dwarf2json
cd /home/ubuntu/git
git clone https://github.com/volatilityfoundation/dwarf2json.git
cd dwarf2json
go mod download github.com/spf13/pflag
go build

echo -e \n${RED}"Building Debug Symbols for Volatility 3${NC}\n"
# https://wiki.ubuntu.com/Kernel/Systemtap
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C8CAB6595FDFF622 
codename=$(lsb_release -c | awk  '{print $2}')
sudo tee /etc/apt/sources.list.d/ddebs.list << EOF
deb http://ddebs.ubuntu.com/ ${codename}      main restricted universe multiverse
deb http://ddebs.ubuntu.com/ ${codename}-security main restricted universe multiverse
deb http://ddebs.ubuntu.com/ ${codename}-updates  main restricted universe multiverse
deb http://ddebs.ubuntu.com/ ${codename}-proposed main restricted universe multiverse
EOF
sudo apt-get update
sudo apt-get install linux-image-$(uname -r)-dbgsym
/home/ubuntu/git/dwarf2json/dwarf2json linux --elf /usr/lib/debug/boot/vmlinux-$(uname -r) > output2.json
cp output2.json /home/ubuntu/git/volatility3/volatility3/symbols/linux-image-$(uname -r).json

echo -e "\n${RED}Grabbing memory with avml${NC}\n"
cd /home/ubuntu
./avml test-output.lime

echo -e "\n${RED}Grabbing memory with LiME${NC}\n"
cd /home/ubuntu
insmod ./lime-$(uname -r).ko "path=ubuntu.lime format=lime"

echo "All Done"

echo "\n${RED}Getting Started Volatility2:{$NC}"
echo "- Find your volatility profile with python2 /home/ubuntu/volatility/vol.py --info |grep Linux"
echo "- Get a pslist in volatility with:"
echo "    python2 /home/ubuntu/git/volatility/vol.py --profile=<PROFILE> -f /home/ubuntu/ubuntu.lime linux_pslist"

echo "\n${RED}Getting Started Volatility3:{$NC}"
echo "- Volatility should automatically find the symbols file created."
echo "- Get a pslist in volatility3 with:"
echo "    python3 /home/ubuntu/git/volatility3/vol.py -f /home/ubuntu/ubuntu.lime linux.pstree.PsTree"