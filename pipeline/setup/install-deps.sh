#!/bin/bash
##
# Installs system dependencies
#

set -x
set -euo pipefail

echo "######### Installing dependencies"

apt install sudo

apt-get update

echo "### Installing extra dependencies"
apt-get install -y pigz htop wget unzip parallel bc git

echo "### Installing bicleaner dependencies"
apt-get install -y libhunspell-dev

echo "### Installing marian dependencies"
apt-get install -y git cmake build-essential libboost-system-dev libprotobuf17 protobuf-compiler libprotobuf-dev openssl libssl-dev libgoogle-perftools-dev

echo "### Installing Intel MKL"
wget -qO- 'https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB' | sudo apt-key add -
sh -c 'echo deb https://apt.repos.intel.com/mkl all main > /etc/apt/sources.list.d/intel-mkl.list' # I did option 2 from here https://www.linuxfordevices.com/tutorials/linux/fix-updating-from-such-a-repository-cant-be-done-securely-error
sudo echo "deb [trusted=yes] https://apt.repos.intel.com/mkl all main" > /etc/apt/sources.list.d/intel-mkl.list
sudo apt-get update
sudo apt-get install -y intel-mkl-64bit-2020.0-088

echo "### Installing fast_align dependencies "
apt-get install -y libgoogle-perftools-dev libsparsehash-dev libboost-all-dev

echo "######### Done: Installing dependencies"
