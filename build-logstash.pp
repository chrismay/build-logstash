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

   exec{"/usr/bin/git clone https://github.com/elasticsearch/elasticsearch.git elasticsearch-src && cd elasticsearch-src && /usr/bin/git checkout v${es_version}":
     cwd=>"/opt",
     creates=>"/opt/elasticsearch-src",
     require=>[File["/opt"],Package["git-core"]],
     alias=>clone-elasticsearch
   }
   exec{"/opt/elasticsearch-src/gradlew > /tmp/elasticsearch-gradle.out 2>&1":
       cwd=>"/opt/elasticsearch-src",
      require=>[Exec["clone-elasticsearch"],Package["openjdk-6-jdk"]],
      creates=>"/opt/elasticsearch-src/build/distributions/elasticsearch-${es_version}.tar.gz",
      alias=>"build-elasticsearch",
      timeout=>"-1"
   }
  file{["/opt/elasticsearch-src/package","/opt/elasticsearch-src/package/DEBIAN", "/opt/elasticsearch-src/package/opt"]: 
     ensure=>directory,
     require=>Exec[clone-elasticsearch]
  }
  exec {"/bin/tar zxf /opt/elasticsearch-src/build/distributions/elasticsearch-${es_version}.tar.gz && mv elasticsearch-${es_version} opt/elasticsearch":
     cwd=>"/opt/elasticsearch-src/package",
     creates=>"/opt/elasticsearch-src/package/opt/elasticsearch", 
     require=>[Exec["build-elasticsearch"],File["/opt/elasticsearch-src/package/opt"]],
     alias=>unpack-elasticsearch-tarball
  }
  exec{"/usr/bin/dpkg --build package/ elasticsearch-${es_version}_all.deb && cp elasticsearch-${es_version}_all.deb /vagrant":
     cwd=>"/opt/elasticsearch-src",
     creates=>"/opt/elasticsearch-src/elasticsearch-${es_version}_all.deb",
     require=>Exec["unpack-elasticsearch-tarball"]
  }
  
  file{"/opt/elasticsearch-src/package/DEBIAN/control": 
     source=>"/vagrant/elasticsearch/package/DEBIAN/control",
     require=>Exec[clone-elasticsearch]
  }
}
exec{"/usr/bin/aptitude update && touch /var/run/aptitude-updated":
    creates=>"/var/run/aptitude-updated",
    alias=>"apt-update"
}
Package{
   require=>[File["/etc/apt/apt.conf.d/01proxy"],Exec["apt-update"]]
}
file{"/etc/apt/apt.conf.d/01proxy":
  content=>"Acquire::http { Proxy \"http://liathach:3142\"; };"
}
include grok-build
$es_version="0.15.0"
include elasticsearch-build
