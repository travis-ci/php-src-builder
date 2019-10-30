
install(){
  #rm -rf /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock
  sudo apt-get update
  sudo apt-get -y -q=2 --no-install-recommends --no-install-suggests  install libtidy-dev libxml2-dev libcurl4-openssl-dev libjpeg-dev libpng-dev libxpm-dev libmysqlclient-dev libpq-dev libicu-dev libfreetype6-dev libldap2-dev libxslt-dev libssl-dev libldb-dev libc-client-dev libkrb5-dev libsasl2-dev libmcrypt-dev  expect


  install_phpenv

  if [[ ! -d $HOME/.php-build ]]; then git clone https://github.com/php-build/php-build.git $HOME/.php-build; fi

}

install_phpenv(){
  if ! command -v phpenv; then
    export PHPENV_ROOT="$HOME/.phpenv"
    curl -L https://raw.githubusercontent.com/phpenv/phpenv-installer/master/bin/phpenv-installer | bash

    if [ -d "${PHPENV_ROOT}" ]; then
      export PATH="${PHPENV_ROOT}/bin:${PATH}"
      eval "$(phpenv init -)"
    else
      echo "Error installing phpenv"
      exit 1
    fi
  fi
}


lib_fix(){
  if [[ $HOSTTYPE == "powerpc64le" ]]; then
      sudo ln /usr/include/powerpc64le-linux-gnu/gmp.h /usr/include/gmp.h
      sudo ln -s /usr/lib/powerpc64le-linux-gnu/libldap_r-2.4.so.2 /usr/lib/libldap_r.so
      sudo ln -s /usr/lib/powerpc64le-linux-gnu/liblber-2.4.so.2 /usr/lib/liblber.so
  elif [ $HOSTTYPE == "aarch64" ]; then
      sudo ln /usr/include/aarch64-linux-gnu/gmp.h /usr/include/gmp.h
      sudo ln -s /usr/lib/aarch64-linux-gnu/libldap_r-2.4.so.2 /usr/lib/libldap_r.so
      sudo ln -s /usr/lib/aarch64-linux-gnu/liblber-2.4.so.2 /usr/lib/liblber.so
  else
      sudo ln /usr/include/x86_64-linux-gnu/gmp.h /usr/include/gmp.h
      sudo ln -s /usr/lib/x86_64-linux-gnu/libldap_r.so /usr/lib/libldap_r.so
      sudo ln -s /usr/lib/x86_64-linux-gnu/libldap.so /usr/lib/libldap.so
      sudo ln -s /usr/lib/x86_64-linux-gnu/libldap.a /usr/lib/libldap.a
      sudo ln -s /usr/lib/x86_64-linux-gnu/liblber.so /usr/lib/liblber.so
  fi
}

build(){
  cd /home/travis/build/travis-ci/php-src-builder
  ./bin/install-icu
  export PKG_CONFIG_PATH=$ICU_INSTALL_DIR/lib/pkgconfig:$PKG_CONFIG_PATH
  touch custom_configure_options
  ./bin/install-libzip
  ./bin/install-libsodium
  ./bin/install-password-argon2
  . ./bin/install-onig # sourced to export ONIG_LIBS


  if [[ -f default_configure_options.$RELEASE-$MINOR_VERSION ]]; then
    cp default_configure_options.$RELEASE-$MINOR_VERSION $HOME/.php-build/share/php-build/default_configure_options
  else
    cp default_configure_options.$RELEASE $HOME/.php-build/share/php-build/default_configure_options
  fi
  cat custom_configure_options >> $HOME/.php-build/share/php-build/default_configure_options
  # disable xdebug on master
  if [[ $VERSION = master && $RELEASE != xenial ]]; then
    sed -i -e '/install_xdebug_master/d' $HOME/.php-build/share/php-build/definitions/$VERSION
  fi


  export LSB_RELEASE=${LSB_RELEASE:-$(lsb_release -rs || echo ${$(sw_vers -productVersion)%*.*})}
  export OS_NAME=${OS_NAME:-$(lsb_release -is | tr "A-Z" "a-z" || echo "osx")}
  export ARCH=${ARCH:-$(uname -m)}
  export INSTALL_DEST=${INSTALL_DEST:-$HOME/.phpenv/versions}

  echo "LSB_RELEASE: $LSB_RELEASE"
  echo "ARCH: $ARCH"
  echo "INSTALL_DEST: $INSTALL_DEST"

  cat $HOME/.php-build/share/php-build/default_configure_options
  ./bin/compile
  # disable 3rd-party extension builds on master
  if [[ ! $VERSION =~ ^master$ ]]; then
    (yes '' | ./bin/compile-extension-redis) &&
    (./bin/compile-extension-mongo;
    ./bin/compile-extension-mongodb) &&
    ./bin/compile-extension-amqp &&
    ./bin/compile-extension-apcu &&
    ./bin/compile-extension-zmq &&
    (./bin/compile-extension-memcache;
    ./bin/compile-extension-memcached) &&
    ./bin/compile-extension-ssh2 &&
    sed -i '/^extension=/d' $INSTALL_DEST/$VERSION/etc/php.ini
  fi
}


__dots() { while true ; do echo -en . ; sleep 30 ; done } ; __dots &

# VERSION="5.6.40"
# RELEASE="xenial"
# ICU_INSTALL_DIR=$HOME/.phpenv/versions/$VERSION

HOSTTYPE=`uname -m`

MINOR_VERSION=`echo $VERSION | sed -E 's/^([0-9]+\.[0-9]+).*$/\1/'` # Rewrites 7.2, 7.2snapshot, 7.2.13 => '7.2'. Leaves 'master' as-is
echo "MINOR_VERSION: $MINOR_VERSION"
echo "RELEASE: $RELEASE"  # example: xenial
echo "VERSION: $VERSION" # example: 5.6.40
echo "HOSTTYPE: $HOSTTYPE"
echo "ICU_INSTALL_DIR: $ICU_INSTALL_DIR" # example: $HOME/.phpenv/versions/$VERSION

install
lib_fix
build

