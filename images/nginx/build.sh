#!/bin/bash

# Copyright 2015 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


set -o errexit
set -o nounset
set -o pipefail

export NGINX_VERSION=1.15.6
export NDK_VERSION=0.3.1rc1
export SETMISC_VERSION=0.31
export STICKY_SESSIONS_VERSION=08a395c66e42
export MORE_HEADERS_VERSION=0.33
export NGINX_DIGEST_AUTH=274490cec649e7300fea97fed13d84e596bbc0ce
export NGINX_SUBSTITUTIONS=bc58cb11844bc42735bbaef7085ea86ace46d05b
export NGINX_OPENTRACING_VERSION=0.5.0
export OPENTRACING_CPP_VERSION=1.4.0
export ZIPKIN_CPP_VERSION=0.3.1
export JAEGER_VERSION=0.4.1
export MODSECURITY_VERSION=1.0.0
export LUA_NGX_VERSION=0.10.13
export LUA_UPSTREAM_VERSION=0.07
export COOKIE_FLAG_VERSION=1.1.0
export NGINX_INFLUXDB_VERSION=f20cfb2458c338f162132f5a21eb021e2cbe6383
export GEOIP2_VERSION=2.0

export BUILD_PATH=/tmp/build

ARCH=$(uname -m)

get_src()
{
  hash="$1"
  url="$2"
  f=$(basename "$url")

  curl -sSL "$url" -o "$f"
  echo "$hash  $f" | sha256sum -c - || exit 10
  tar xzf "$f"
  rm -rf "$f"
}

if [[ ${ARCH} == "ppc64le" ]]; then
  clean-install software-properties-common
fi

apt-get update && apt-get dist-upgrade -y

# install required packages to build
clean-install \
  bash \
  build-essential \
  curl ca-certificates \
  libgeoip1 \
  libgeoip-dev \
  patch \
  libpcre3 \
  libpcre3-dev \
  libssl-dev \
  zlib1g \
  zlib1g-dev \
  libaio1 \
  libaio-dev \
  openssl \
  libperl-dev \
  cmake \
  util-linux \
  lua5.1 liblua5.1-0 liblua5.1-dev \
  lmdb-utils \
  libjemalloc1 libjemalloc-dev \
  wget \
  libcurl4-openssl-dev \
  procps \
  git g++ pkgconf flex bison doxygen libyajl-dev liblmdb-dev libtool dh-autoreconf libxml2 libpcre++-dev libxml2-dev \
  lua-cjson \
  python \
  luarocks \
  libmaxminddb-dev \
  libcap2-bin \
  || exit 1

if [[ ${ARCH} == "x86_64" ]]; then
  ln -s /usr/lib/x86_64-linux-gnu/liblua5.1.so /usr/lib/liblua.so
  ln -s /usr/lib/x86_64-linux-gnu /usr/lib/lua-platform-path
fi

if [[ ${ARCH} == "armv7l" ]]; then
  ln -s /usr/lib/arm-linux-gnueabihf/liblua5.1.so /usr/lib/liblua.so
  ln -s /usr/lib/arm-linux-gnueabihf /usr/lib/lua-platform-path
fi

if [[ ${ARCH} == "aarch64" ]]; then
  ln -s /usr/lib/aarch64-linux-gnu/liblua5.1.so /usr/lib/liblua.so
  ln -s /usr/lib/aarch64-linux-gnu /usr/lib/lua-platform-path
fi

if [[ ${ARCH} == "ppc64le" ]]; then
  ln -s /usr/lib/powerpc64le-linux-gnu/liblua5.1.so /usr/lib/liblua.so
  ln -s /usr/lib/powerpc64le-linux-gnu /usr/lib/lua-platform-path
fi

if [[ ${ARCH} == "s390x" ]]; then
  ln -s /usr/lib/s390x-linux-gnu/liblua5.1.so /usr/lib/liblua.so
  ln -s /usr/lib/s390x-linux-gnu /usr/lib/lua-platform-path
  # avoid error:
  # git: ../nptl/pthread_mutex_lock.c:81: __pthread_mutex_lock: Assertion `mutex->__data.__owner == 0' failed.
  git config --global pack.threads "1"
fi

mkdir -p /etc/nginx

# Get the GeoIP data
GEOIP_FOLDER=/etc/nginx/geoip
mkdir -p $GEOIP_FOLDER
function geoip_get {
  wget -O $GEOIP_FOLDER/$1 $2 || { echo "Could not download $1, exiting." ; exit 1; }
  gunzip $GEOIP_FOLDER/$1
}
geoip_get "GeoIP.dat.gz" "https://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz"
geoip_get "GeoLiteCity.dat.gz" "https://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz"
geoip_get "GeoIPASNum.dat.gz" "http://download.maxmind.com/download/geoip/database/asnum/GeoIPASNum.dat.gz"
geoip_get "GeoLite2-City.mmdb.gz" "http://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz"
geoip_get "GeoLite2-ASN.mmdb.gz" "http://geolite.maxmind.com/download/geoip/database/GeoLite2-ASN.tar.gz"

mkdir --verbose -p "$BUILD_PATH"
cd "$BUILD_PATH"

# download, verify and extract the source files
get_src fb92f5602cdb8d3ab1ad47dbeca151b185d62eedb67d347bbe9d79c1438c85de \
        "http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz"

get_src 49f50d4cd62b166bc1aaf712febec5e028d9f187cedbc27a610dfd01bdde2d36 \
        "https://github.com/simpl/ngx_devel_kit/archive/v$NDK_VERSION.tar.gz"

get_src 97946a68937b50ab8637e1a90a13198fe376d801dc3e7447052e43c28e9ee7de \
        "https://github.com/openresty/set-misc-nginx-module/archive/v$SETMISC_VERSION.tar.gz"

get_src a3dcbab117a9c103bc1ea5200fc00a7b7d2af97ff7fd525f16f8ac2632e30fbf \
        "https://github.com/openresty/headers-more-nginx-module/archive/v$MORE_HEADERS_VERSION.tar.gz"

get_src 53e440737ed1aff1f09fae150219a45f16add0c8d6e84546cb7d80f73ebffd90 \
        "https://bitbucket.org/nginx-goodies/nginx-sticky-module-ng/get/$STICKY_SESSIONS_VERSION.tar.gz"

get_src ede0ad490cb9dd69da348bdea2a60a4c45284c9777b2f13fa48394b6b8e7671c \
        "https://github.com/atomx/nginx-http-auth-digest/archive/$NGINX_DIGEST_AUTH.tar.gz"

get_src 618551948ab14cac51d6e4ad00452312c7b09938f59ebff4f93875013be31f2d \
        "https://github.com/yaoweibin/ngx_http_substitutions_filter_module/archive/$NGINX_SUBSTITUTIONS.tar.gz"

get_src ad6c813cb8baa4a178417bfa316ab3535d950fe02c67dc3a4af96ef6a1f655d6 \
        "https://github.com/opentracing-contrib/nginx-opentracing/archive/v$NGINX_OPENTRACING_VERSION.tar.gz"

get_src 2eb0a4a7dc62bc8cbf12872080197b41d53b4c04966c860774a6b11fd59fad55 \
        "https://github.com/opentracing/opentracing-cpp/archive/v$OPENTRACING_CPP_VERSION.tar.gz"

get_src f16a6f1eed494ca3c2607d7ad671cb134bd7eb320c5969c8281c10922a146589 \
        "https://github.com/rnburn/zipkin-cpp-opentracing/archive/v$ZIPKIN_CPP_VERSION.tar.gz"

get_src 8deee6d6f7128f58bd6ba2893bd69c1fdbc8a3ad2797ba45ef94b977255d181c \
        "https://github.com/SpiderLabs/ModSecurity-nginx/archive/v$MODSECURITY_VERSION.tar.gz"

get_src 35b5a96ceb0aec68abdf25cdb9fe43cce09b2ab7bf52fb32d77038f21fef75ac \
        "https://github.com/jaegertracing/jaeger-client-cpp/archive/v$JAEGER_VERSION.tar.gz"

get_src 9915ad1cf0734cc5b357b0d9ea92fec94764b4bf22f4dce185cbd65feda30ec1 \
        "https://github.com/AirisX/nginx_cookie_flag_module/archive/v$COOKIE_FLAG_VERSION.tar.gz"

get_src ecea8c3d7f69dd48c6132498ddefb5d83ba9f387fa3d4da14e2abeacdfc8a3ee \
        "https://github.com/openresty/lua-nginx-module/archive/v$LUA_NGX_VERSION.tar.gz"

get_src 2a69815e4ae01aa8b170941a8e1a10b6f6a9aab699dee485d58f021dd933829a \
        "https://github.com/openresty/lua-upstream-nginx-module/archive/v$LUA_UPSTREAM_VERSION.tar.gz"

get_src 2349dd0b7ee37680306ee76bc4b6bf5c7509a4a4be16d246d9bbff44f564e4a0 \
        "https://github.com/openresty/lua-resty-lrucache/archive/v0.08.tar.gz"

get_src 2bba995e715a93134b86939c83baa33a1189f2461c41762619f3760e75311a18 \
        "https://github.com/openresty/lua-resty-core/archive/v0.1.15.tar.gz"

get_src eaf84f58b43289c1c3e0442ada9ed40406357f203adc96e2091638080cb8d361 \
        "https://github.com/openresty/lua-resty-lock/archive/v0.07.tar.gz"

get_src 3917d506e2d692088f7b4035c589cc32634de4ea66e40fc51259fbae43c9258d \
        "https://github.com/hamishforbes/lua-resty-iputils/archive/v0.3.0.tar.gz"

get_src 5d16e623d17d4f42cc64ea9cfb69ca960d313e12f5d828f785dd227cc483fcbd \
        "https://github.com/openresty/lua-resty-upload/archive/v0.10.tar.gz"

get_src 4aca34f324d543754968359672dcf5f856234574ee4da360ce02c778d244572a \
        "https://github.com/openresty/lua-resty-dns/archive/v0.21.tar.gz"

get_src 095615fe94e64615c4a27f4f4475b91c047cf8d10bc2dbde8d5ba6aa625fc5ab \
        "https://github.com/openresty/lua-resty-string/archive/v0.11.tar.gz"

get_src a77bf0d7cf6a9ba017d0dc973b1a58f13e48242dd3849c5e99c07d250667c44c \
        "https://github.com/openresty/lua-resty-balancer/archive/v0.02rc4.tar.gz"

get_src d81b33129c6fb5203b571fa4d8394823bf473d8872c0357a1d0f14420b1483bd \
        "https://github.com/cloudflare/lua-resty-cookie/archive/v0.1.0.tar.gz"

get_src 76d8638a350a0484b3d6658e329ba38bb831d407eaa6dce2a084a27a22063133 \
        "https://github.com/openresty/luajit2/archive/v2.1-20180420.tar.gz"

get_src 1897d7677d99c1cedeb95b2eb00652a4a7e8e604304c3053a93bd3ba7dd82884 \
        "https://github.com/influxdata/nginx-influxdb-module/archive/$NGINX_INFLUXDB_VERSION.tar.gz"

get_src ebb4652c4f9a2e1ee31fddefc4c93ff78e651a4b2727d3453d026bccbd708d99 \
        "https://github.com/leev/ngx_http_geoip2_module/archive/${GEOIP2_VERSION}.tar.gz"


# improve compilation times
CORES=$(($(grep -c ^processor /proc/cpuinfo) - 0))

export MAKEFLAGS=-j${CORES}
export CTEST_BUILD_FLAGS=${MAKEFLAGS}
export HUNTER_JOBS_NUMBER=${CORES}

# Installing luarocks packages
if [[ ${ARCH} == "x86_64" ]]; then
  luarocks install lrexlib-pcre 2.7.2-1
fi

# luajit is not available on ppc64le and s390x
if [[ (${ARCH} != "ppc64le") && (${ARCH} != "s390x") ]]; then
  cd "$BUILD_PATH/luajit2-2.1-20180420"
  make
  make install

  export LUAJIT_LIB=/usr/local/lib
  export LUAJIT_INC=/usr/local/include/luajit-2.1
  export LUA_LIB_DIR="$LUAJIT_LIB/lua"

  cd "$BUILD_PATH/lua-resty-core-0.1.15"
  make install

  cd "$BUILD_PATH/lua-resty-lrucache-0.08"
  make install

  cd "$BUILD_PATH/lua-resty-lock-0.07"
  make install

  cd "$BUILD_PATH/lua-resty-iputils-0.3.0"
  make install

  cd "$BUILD_PATH/lua-resty-upload-0.10"
  make install

  cd "$BUILD_PATH/lua-resty-dns-0.21"
  make install

  cd "$BUILD_PATH/lua-resty-string-0.11"
  make install

  cd "$BUILD_PATH/lua-resty-balancer-0.02rc4"
  make all
  make install

  cd "$BUILD_PATH/lua-resty-cookie-0.1.0"
  make install

  # build and install lua-resty-waf with dependencies
  /install_lua_resty_waf.sh
fi

# build opentracing lib
cd "$BUILD_PATH/opentracing-cpp-$OPENTRACING_CPP_VERSION"
mkdir .build
cd .build
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF ..
make
make install

# build zipkin lib
cd "$BUILD_PATH/jaeger-client-cpp-$JAEGER_VERSION"
sed -i 's/-Werror//' CMakeLists.txt
mkdir .build
cd .build
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=1 -DBUILD_TESTING=OFF -DJAEGERTRACING_WITH_YAML_CPP=OFF -DJAEGERTRACING_BUILD_EXAMPLES=OFF ..
make
make install

export HUNTER_INSTALL_DIR=$(cat _3rdParty/Hunter/install-root-dir)
echo "HUNTER_INSTALL_DIR: ${HUNTER_INSTALL_DIR}"
cp $HUNTER_INSTALL_DIR/lib/libthrift* /usr/local/lib
rm /usr/local/lib/libthrift*.a

# build zipkin lib
cd "$BUILD_PATH/zipkin-cpp-opentracing-$ZIPKIN_CPP_VERSION"
mkdir .build
cd .build
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=1 -DBUILD_TESTING=OFF ..
make
make install

# Get Brotli source and deps
cd "$BUILD_PATH"
git clone --depth=1 https://github.com/google/ngx_brotli.git
cd ngx_brotli
git submodule init
git submodule update

# build modsecurity library
cd "$BUILD_PATH"
git clone -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity
cd ModSecurity/
# checkout v3.0.2
git checkout 8d0f51beda5c031e38741c27f29b67f0266352bb
git submodule init
git submodule update
sh build.sh
./configure --disable-doxygen-doc --disable-examples --disable-dependency-tracking
make
make install

# Download owasp modsecurity crs
cd /etc/nginx/
git clone -b v3.0/master --single-branch https://github.com/SpiderLabs/owasp-modsecurity-crs
cd owasp-modsecurity-crs
git checkout e4e0497be4d598cce0e0a8fef20d1f1e5578c8d0

mv crs-setup.conf.example crs-setup.conf
mv rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
mv rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf.example rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf
cd ..

# Download modsecurity.conf
mkdir modsecurity
cd modsecurity
curl -sSL -o modsecurity.conf https://raw.githubusercontent.com/SpiderLabs/ModSecurity/v3/master/modsecurity.conf-recommended

# OWASP CRS v3 rules
echo "
Include /etc/nginx/owasp-modsecurity-crs/crs-setup.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-901-INITIALIZATION.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-903.9001-DRUPAL-EXCLUSION-RULES.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-903.9002-WORDPRESS-EXCLUSION-RULES.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-905-COMMON-EXCEPTIONS.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-910-IP-REPUTATION.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-911-METHOD-ENFORCEMENT.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-912-DOS-PROTECTION.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-913-SCANNER-DETECTION.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-920-PROTOCOL-ENFORCEMENT.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-921-PROTOCOL-ATTACK.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-930-APPLICATION-ATTACK-LFI.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-931-APPLICATION-ATTACK-RFI.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-932-APPLICATION-ATTACK-RCE.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-933-APPLICATION-ATTACK-PHP.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-941-APPLICATION-ATTACK-XSS.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-942-APPLICATION-ATTACK-SQLI.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-943-APPLICATION-ATTACK-SESSION-FIXATION.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-949-BLOCKING-EVALUATION.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/RESPONSE-950-DATA-LEAKAGES.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/RESPONSE-951-DATA-LEAKAGES-SQL.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/RESPONSE-952-DATA-LEAKAGES-JAVA.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/RESPONSE-953-DATA-LEAKAGES-PHP.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/RESPONSE-954-DATA-LEAKAGES-IIS.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/RESPONSE-959-BLOCKING-EVALUATION.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/RESPONSE-980-CORRELATION.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf
" > /etc/nginx/owasp-modsecurity-crs/nginx-modsecurity.conf

# build nginx
cd "$BUILD_PATH/nginx-$NGINX_VERSION"

WITH_FLAGS="--with-debug \
  --with-compat \
  --with-pcre-jit \
  --with-http_ssl_module \
  --with-http_stub_status_module \
  --with-http_realip_module \
  --with-http_auth_request_module \
  --with-http_addition_module \
  --with-http_dav_module \
  --with-http_geoip_module \
  --with-http_gzip_static_module \
  --with-http_sub_module \
  --with-http_v2_module \
  --with-stream \
  --with-stream_ssl_module \
  --with-stream_ssl_preread_module \
  --with-threads \
  --with-http_secure_link_module"

if [[ ${ARCH} != "armv7l" || ${ARCH} != "aarch64" ]]; then
  WITH_FLAGS+=" --with-file-aio"
fi

# "Combining -flto with -g is currently experimental and expected to produce unexpected results."
# https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html
CC_OPT="-g -Og -fPIE -fstack-protector-strong -Wformat -Werror=format-security -Wdate-time -D_FORTIFY_SOURCE=2 -Wno-deprecated-declarations --param=ssp-buffer-size=4 -DTCP_FASTOPEN=23 -Wno-error=strict-aliasing -fPIC -I$HUNTER_INSTALL_DIR/include"
LD_OPT="-ljemalloc -fPIE -fPIC -pie -Wl,-z,relro -Wl,-z,now -L$HUNTER_INSTALL_DIR/lib"

if [[ ${ARCH} == "x86_64" ]]; then
  CC_OPT+=' -m64 -mtune=native'
fi

WITH_MODULES="--add-module=$BUILD_PATH/ngx_devel_kit-$NDK_VERSION \
  --add-module=$BUILD_PATH/set-misc-nginx-module-$SETMISC_VERSION \
  --add-module=$BUILD_PATH/headers-more-nginx-module-$MORE_HEADERS_VERSION \
  --add-module=$BUILD_PATH/nginx-goodies-nginx-sticky-module-ng-$STICKY_SESSIONS_VERSION \
  --add-module=$BUILD_PATH/nginx-http-auth-digest-$NGINX_DIGEST_AUTH \
  --add-module=$BUILD_PATH/ngx_http_substitutions_filter_module-$NGINX_SUBSTITUTIONS \
  --add-module=$BUILD_PATH/lua-nginx-module-$LUA_NGX_VERSION \
  --add-module=$BUILD_PATH/lua-upstream-nginx-module-$LUA_UPSTREAM_VERSION \
  --add-module=$BUILD_PATH/nginx_cookie_flag_module-$COOKIE_FLAG_VERSION \
  --add-module=$BUILD_PATH/nginx-influxdb-module-$NGINX_INFLUXDB_VERSION \
  --add-dynamic-module=$BUILD_PATH/nginx-opentracing-$NGINX_OPENTRACING_VERSION/opentracing \
  --add-dynamic-module=$BUILD_PATH/ModSecurity-nginx-$MODSECURITY_VERSION \
  --add-dynamic-module=$BUILD_PATH/ngx_http_geoip2_module-${GEOIP2_VERSION} \
  --add-module=$BUILD_PATH/ngx_brotli"

./configure \
  --prefix=/usr/share/nginx \
  --conf-path=/etc/nginx/nginx.conf \
  --modules-path=/etc/nginx/modules \
  --http-log-path=/var/log/nginx/access.log \
  --error-log-path=/var/log/nginx/error.log \
  --lock-path=/var/lock/nginx.lock \
  --pid-path=/run/nginx.pid \
  --http-client-body-temp-path=/var/lib/nginx/body \
  --http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
  --http-proxy-temp-path=/var/lib/nginx/proxy \
  --http-scgi-temp-path=/var/lib/nginx/scgi \
  --http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
  ${WITH_FLAGS} \
  --without-mail_pop3_module \
  --without-mail_smtp_module \
  --without-mail_imap_module \
  --without-http_uwsgi_module \
  --without-http_scgi_module \
  --with-cc-opt="${CC_OPT}" \
  --with-ld-opt="${LD_OPT}" \
  ${WITH_MODULES} \
  && make || exit 1 \
  && make install || exit 1

echo "Cleaning..."

cd /

mv /usr/share/nginx/sbin/nginx /usr/sbin

# allow binding to a port less than 1024 to non-root users
setcap cap_net_bind_service=+ep /usr/sbin/nginx

apt-mark unmarkauto \
  bash \
  curl ca-certificates \
  libgeoip1 \
  libpcre3 \
  zlib1g \
  libaio1 \
  xz-utils \
  geoip-bin \
  libyajl2 liblmdb0 libxml2 libpcre++ \
  gzip \
  openssl

apt-get remove -y --purge \
  build-essential \
  gcc-6 \
  cpp-6 \
  libgeoip-dev \
  libpcre3-dev \
  libssl-dev \
  zlib1g-dev \
  libaio-dev \
  linux-libc-dev \
  cmake \
  wget \
  libcap2-bin \
  git g++ pkgconf flex bison doxygen libyajl-dev liblmdb-dev libgeoip-dev libtool dh-autoreconf libpcre++-dev libxml2-dev

apt-get autoremove -y

rm -rf "$BUILD_PATH"
rm -Rf /usr/share/man /usr/share/doc
rm -rf /tmp/* /var/tmp/*
rm -rf /var/lib/apt/lists/*
rm -rf /var/cache/apt/archives/*
rm -rf /usr/local/modsecurity/bin
rm -rf /usr/local/modsecurity/include
rm -rf /usr/local/modsecurity/lib/libmodsecurity.a

rm -rf /etc/nginx/owasp-modsecurity-crs/.git
rm -rf /etc/nginx/owasp-modsecurity-crs/util/regression-tests

rm -rf $HOME/.hunter

# update image permissions
writeDirs=( \
  /etc/nginx \
  /etc/ingress-controller/ssl \
  /etc/ingress-controller/auth \
  /var/log \
  /var/log/nginx \
  /var/lib/nginx/body \
  /usr/share/nginx/html \
  /opt/modsecurity/var/log \
  /opt/modsecurity/var/upload \
  /opt/modsecurity/var/audit \
);

for dir in "${writeDirs[@]}"; do
  mkdir -p ${dir};
  chown -R www-data.www-data ${dir};
done
