#!/bin/bash
#

function main {
   useradd -m -G sudo -s /bin/bash user_composer
   printf 'user_composer\nuser_composer\n' | passwd user_composer
   useradd -m -G sudo -s /bin/bash user_gosdk
   printf 'user_gosdk\nuser_gosdk\n' | passwd user_gosdk
   useradd -m -G sudo -s /bin/bash user_javasdk
   printf 'user_javasdk\nuser_javasdk\n' | passwd user_javasdk

   if [[ ! -z "${http_proxy}" ]]; then
     echo "export http_proxy=$http_proxy" >> /home/user_composer/.profile
     echo "export http_proxy=$http_proxy" >> /home/user_gosdk/.profile
     echo "export http_proxy=$http_proxy" >> /home/user_javasdk/.profile
   fi
   if [[ ! -z "${https_proxy}" ]]; then
     echo "export https_proxy=$https_proxy" >> /home/user_composer/.profile
     echo "export https_proxy=$https_proxy" >> /home/user_gosdk/.profile
     echo "export https_proxy=$https_proxy" >> /home/user_javasdk/.profile
   fi
   if [[ ! -z "${no_proxy}" ]]; then
      echo "export no_proxy=$no_proxy" >> /home/user_composer/.profile
      echo "export no_proxy=$no_proxy" >> /home/user_gosdk/.profile
      echo "export no_proxy=$no_proxy" >> /home/user_javasdk/.profile
   fi
   /scripts/prereqs-composer-sudo.sh

   su - user_composer -c '/scripts/prereqs-composer-user.sh'

   su - user_composer -c '/scripts/packages-composer.sh'
}

set -e

SDIR=$(dirname "$0")

main
