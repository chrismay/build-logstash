class build-common{
   package{"git-core":ensure=>present}
}
class grok-build{
   include build-common
   package{["build-essential","dh-make","devscripts","debhelper","cdbs"]: ensure=>present}

   package{["bison","exuberant-ctags","flex","gperf","libevent-dev","libpcre3-dev","libtokyocabinet-dev"]: ensure=>present}

   exec{"/usr/bin/git clone https://github.com/jordansissel/grok.git":
       user=>vagrant,
       creates=>"/home/vagrant/grok",
       cwd=>"/home/vagrant",
       alias=>"git-clone",
       require=>Package["git-core"]
   }
   File{ require=>Exec["git-clone"]}
   file {["/home/vagrant/grok/package","/home/vagrant/grok/package/DEBIAN"]: ensure=>directory}
   file{"/home/vagrant/grok/package/DEBIAN/control": source=>"/vagrant/grok/package/DEBIAN/control"} 
   
   file{"/home/vagrant/grok/build-package.sh":
     content=>"#!/bin/bash 
make
sudo DESTDIR=./package make install
dpkg --build package/ grok-1.1_all.deb
cp grok-1.1_all.deb /vagrant",
    mode=>755
  }
}

class elasticsearch-build{
   include build-common
   package{["openjdk-6-jdk"]: ensure=>present}
   file{"/opt": ensure=>directory}

   exec{"/usr/bin/git clone https://github.com/elasticsearch/elasticsearch.git elasticsearch-src":
     cwd=>"/opt",
     creates=>"/opt/elasticsearch-src",
     require=>[File["/opt"],Package["git-core"]],
     alias=>clone-elasticsearch
   }
   exec{"/opt/elasticsearch-src/gradlew":
      require=>Exec["clone-elasticsearch"]
      ,creates=>"/opt/elasticsearch-src/build/distributions"
   }
  file{["/opt/elasticsearch-src/package","/opt/elasticsearch-src/package/DEBIAN"]: ensure=>directory}
  file{"/opt/elasticsearch-src/package/DEBIAN/control": source=>"/vagrant/elasticsearch/package/DEBIAN/control"}
}
Package{
   require=>File["/etc/apt/apt.conf.d/01proxy"]
}
file{"/etc/apt/apt.conf.d/01proxy":
  content=>"Acquire::http { Proxy \"http://liathach:3142\"; };"
}
include grok-build
include elasticsearch-build
