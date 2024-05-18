class Curl < Formula
  desc "Get a file from an HTTP, HTTPS or FTP server"
  homepage "https://curl.haxx.se/"
  url "https://curl.se/download/curl-8.7.1.tar.xz"
  sha256 "6fea2aac6a4610fbd0400afb0bcddbe7258a64c63f1f68e5855ebc0c659710cd"

  bottle do
    cellar :any
    sha256 "3df51bb4d5b3e88caee67b2e2cb93458384b9f0bdda2c35e323f00cbf689c4dd" => :tiger_altivec
  end

  keg_only :provided_by_osx

  option 'with-c-ares',      'Build with C-ARES asynchronous DNS support'
  option 'with-completions', 'Build with fish and zsh command-line completions'
  option 'with-libressl',    'Build with LibreSSL instead of OpenSSL'
  option 'with-libssh2',     'Build with scp and sFTP support'

  option 'without-gsasl',    'Build without SASL SCRAM authentication support'

  deprecated_option "with-ares" => "with-c-ares"
  deprecated_option "with-ssh"  => "with-libssh2"

  depends_on "gsasl"    => :recommended

  depends_on "c-ares"   => :optional
  depends_on "libressl" => :optional
  depends_on "libssh2"  => :optional

  depends_on "libnghttp2"
  depends_on "openssl3" if build.without? 'libressl'
  depends_on "zlib"

  depends_on "pkg-config" => :build

  def install
    # defaults we don't need to specify:
    # --disable-debug
    # --enable-optimize
    # --disable-warnings, --disable-werror, --disable-curldebug
    # --enable-http, --enable-ftp, --enable-file, --enable-ldap, --enable-ldaps
    # --enable-rtsp, --enable-proxy, --enable-dict, --enable-telnet, --enable-tftp
    # --enable-pop3, --enable-imap, --enable-smb, --enable-smtp, --enable-gopher
    # --enable-docs, --enable-manual, --enable-libcurl-option, --enable-ipv6
    # --enable-threaded-resolver, --enable-verbose, --enable-aws, --enable-ntlm
    # --enable-tls-srp, --enable-unix-sockets, --enable-cookies, --enable-socketpair
    # --enable-http-auth, --enable-doh, --enable-mime, --enable-bindlocal, --enable-form-api
    # --enable-dateparse, --enable-netrc, --enable-get-easy-options, --enable-alt-svc
    # --enable-headers-api, --enable-hsts
    # --with-pic, --with-libpsl, --with-libidn2, --with-libnghttp2
    # inapplicable:
    # --enable-ntlm-wb, --with-schannel, --with-amissl
    # don't work:
    # --enable-symbol-hiding :  automatic, but no compiler support
    # --enable-ech :  OpenSSL build doesn’t have the API
    # --with-secure-transport :  no Tiger version & Leopard version is obsolete
    # --with-openssl-quic :  OpenSSL build doesn’t support the API (this would also provide HTTP/3)
    # would need packages:
    # --enable-websockets
    # --with-ngtcp2 plus --with-nghttp3
    #   OR --with-quiche
    #   OR --with msh3
    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --enable-mqtt
      --enable-progress-meter
      --with-gssapi
      --with-zlib=#{Formula["zlib"].opt_prefix}
      --with-ca-fallback
    ]
    args << (ARGV.verbose? ? '--disable-silent-rules' : '--enable-silent-rules')

    # cURL has a new firm desire to find ssl with PKG_CONFIG_PATH instead of using
    # "--with-ssl" any more. "when possible, set the PKG_CONFIG_PATH environment
    # variable instead of using this option". Multi-SSL choice breaks w/o using it.
    if build.with? "libressl"
      ENV.prepend_path "PKG_CONFIG_PATH", "#{Formula["libressl"].opt_lib}/pkgconfig"
      args << "--with-ssl=#{Formula["libressl"].opt_prefix}"
      args << "--with-ca-bundle=#{etc}/libressl/cert.pem"
    else
      ENV.prepend_path "PKG_CONFIG_PATH", "#{Formula["openssl3"].opt_lib}/pkgconfig"
      args << "--with-openssl=#{Formula["openssl3"].opt_prefix}"
      args << '--enable-openssl-auto-load-config'
      args << "--with-ca-bundle=#{etc}/openssl@3/cert.pem"
    end

    args << (build.with?("c-ares") ? "--enable-ares" : "--disable-ares")

    if build.with? 'completions'
      args << "--with-fish-functions-dir=#{fish_completion}"
      args << "--with-zsh-functions-dir=#{zsh_completion}"
    else
      args << '--without-fish-functions-dir' << '--without-zsh-functions-dir'
    end

    if build.with? "libssh2"
      ENV.prepend_path 'PKG_CONFIG_PATH', "#{Formula['libssh2'].opt_lib}/pkgconfig"
      args << "--with-libssh2"
    else
      args << "--without-libssh2"
    end

    if Formula['brotli'].installed?
      ENV.prepend_path 'PKG_CONFIG_PATH', "#{Formula['brotli'].opt_lib}/pkgconfig"
      args << '--with-brotli'
    end

    if Formula['rtmpdump'].installed?
      ENV.prepend_path 'PKG_CONFIG_PATH', "#{Formula['rtmpdump'].opt_lib}/pkgconfig"
      args << '--with-librtmp'
    end

    if Formula['zstd'].installed?
      ENV.prepend_path 'PKG_CONFIG_PATH', "#{Formula['zstd'].opt_lib}/pkgconfig"
      args << '--with-zstd'
    end

    # Tiger/Leopard ship with a horrendously outdated set of certs,
    # breaking any software that relies on curl, e.g. git
    args << "--with-ca-bundle=#{HOMEBREW_PREFIX}/share/ca-bundle.crt"

    system "./configure", *args
    system "make"
    # no `make test` because the one that compares Curl’s errors to its docs is the only failure
    system "make", "install"
    system "make", "install", "-C", "scripts"
    libexec.install "scripts/mk-ca-bundle.pl"
  end

  def caveats
    <<-_.undent
      cURL will be built to take advantage of any or all of the following packages,
      should they be installed:
          brotli    libidn2    libpsl    rtmpdump    zstd
    _
  end

  test do
    # Fetch the curl tarball and see that the checksum matches.
    # This requires a network connection, but so does Homebrew in general.
    filename = (testpath/"test.tar.gz")
    system "#{bin}/curl", "-L", stable.url, "-o", filename
    filename.verify_checksum stable.checksum

    # so mk-ca-bundle can find it
    ENV.prepend_path "PATH", Formula["curl"].opt_bin
    ENV.prepend_path "PATH", Formula["perl"].opt_bin
    system libexec/"mk-ca-bundle.pl", "test.pem"
    assert File.exist?("test.pem")
    assert File.exist?("certdata.txt")
  end

end
