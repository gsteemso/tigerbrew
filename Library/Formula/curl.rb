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

#  option :universal
  option "with-completions", "Add fish and zsh command-line completions"
  option 'with-gnutls',      'Add GnuTLS security, independent of OpenSSL or LibreSSL'
  option "with-libressl",    "Use LibreSSL security instead of OpenSSL"
  option "with-libssh2",     "Add scp and sFTP access"
  option 'with-more-dns',    'Add asynchronous, internationalized, public‐suffix‐aware DNS'
  option "with-rtmpdump",    "Add RTMP (streaming Flash)"
  option 'with-zstd',        'Add ZStandard compression'
  option 'without-gsasl',    'Omit SASL SCRAM authentication'
  option 'without-openssl3', 'Omit OpenSSL security (GnuTLS and/or LibreSSL recommended)'

  deprecated_option "with-ares"   => "with-more-dns"
  deprecated_option "with-c-ares" => "with-more-dns"
  deprecated_option "with-rtmp"   => "with-rtmpdump"
  deprecated_option "with-ssh"    => "with-libssh2"

  depends_on 'gnutls'   => :optional
  depends_on "libressl" => :optional
  depends_on "libssh2"  => :optional
  if build.with? 'more-dns'
    depends_on "c-ares"
    depends_on "libidn2"  # libPSL also depends on this
    depends_on "libpsl"
  end
  depends_on "rtmpdump" => :optional
  depends_on 'zstd'     => :optional

  depends_on "gsasl"    => :recommended
  depends_on "openssl3" => :recommended

  depends_on "libnghttp2"
  depends_on "zlib"

  depends_on "pkg-config" => :build

  def install
    # the defaults:
    #   --enable-alt-svc, --enable-bindlocal, --enable-cookies, --disable-curldebug,
    #   --enable-dateparse, --disable-debug --without-default-ssl-backend, --enable-dict,
    #   --enable-docs, --enable-doh, --disable-ech*, --enable-file, --enable-form-api, --enable-ftp,
    #   --enable-gopher, --enable-headers-api, --enable-hsts, --enable-http, --enable-http-auth,
    #   --enable-imap, --enable-ipv6, --enable-ldap, --enable-ldaps, --enable-libcurl-option,
    #   --with-libidn2, --with-libnghttp2, --with-libpsl, --enable-manual, --enable-mime,
    #   --enable-ntlm, --without-openssl-quic*, --enable-optimize, --enable-pop3, --enable-proxy,
    #   --enable-rtsp, --without-secure-transport*, --enable-smb, --enable-smtp,
    #   --enable-socketpair, --enable-symbol-hiding*, --enable-telnet, --enable-tftp,
    #   --enable-threaded-resolver, --enable-tls-srp*, --enable-unix-sockets, --enable-verbose,
    #   --disable-warnings, --disable-werror
    # options that don't work for Tigerbrew:
    #   --enable-ech :  none of our SSL builds have the API
    #   --with-openssl-quic :  none of our SSL builds have the API (it would also provide HTTP/3)
    #   --with-secure-transport :  no Tiger version, many from Leopard onwards are obsolete, & cURL
    #                              misses some features when using it instead of, e.g., OpenSSL
    #   --enable-symbol-hiding :  Apple GCC does not comply
    #   --enable-tls-srp :  whatever is required for this to work is not present
    # options that need packages:
    #   --with-ngtcp2 plus --with-nghttp3
    #     OR --with-msh3
    #     OR --with-quiche
    #   --enable-websockets
    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --enable-mqtt
      --with-ca-fallback
      --with-gssapi
      --with-zlib=#{Formula["zlib"].opt_prefix}
    ]
    args << '--disable-verbose' unless ARGV.verbose?

    # cURL has a new firm desire to find ssl with PKG_CONFIG_PATH instead of using
    # "--with-ssl" any more. "when possible, set the PKG_CONFIG_PATH environment
    # variable instead of using this option". Multi-SSL choice breaks w/o using it.
    if build.with? 'gnutls'
      ENV.prepend_path 'PKG_CONFIG_PATH', "#{Formula['gnutls'].opt_lib}/pkgconfig"
      args << "--with-gnutls=#{Formula['gnutls'].opt_prefix}"
      args << "--with-ca-bundle=#{etc}/gnutls/cert.pem"
    end
    if build.with? "libressl"
      ENV.prepend_path "PKG_CONFIG_PATH", "#{Formula["libressl"].opt_lib}/pkgconfig"
      args << "--with-openssl=#{Formula["libressl"].opt_prefix}"
      args << "--with-ca-bundle=#{etc}/libressl/cert.pem"
    elsif build.with? 'openssl3'
      ENV.prepend_path "PKG_CONFIG_PATH", "#{Formula["openssl3"].opt_lib}/pkgconfig"
      args << "--with-openssl=#{Formula["openssl3"].opt_prefix}"
      args << '--enable-openssl-auto-load-config'
      args << "--with-ca-bundle=#{etc}/openssl@3/cert.pem"
    elsif build.without? 'gnutls'
      args << '--without-ssl'
    end

    # take advantage of Brotli compression if it is installed:
    if Formula['brotli'].installed?
      ENV.prepend_path 'PKG_CONFIG_PATH', "#{Formula['brotli'].opt_lib}/pkgconfig"
      args << '--with-brotli'
    else
      args << '--without-brotli'
    end

    if build.with? 'completions'
      args << "--with-fish-functions-dir=#{fish_completion}"
      args << "--with-zsh-functions-dir=#{zsh_completion}"
    else
      args << '--without-fish-functions-dir' << '--without-zsh-functions-dir'
    end

    if build.with? 'libssh2'
      ENV.prepend_path 'PKG_CONFIG_PATH', "#{Formula['libssh2'].opt_lib}/pkgconfig"
      args << '--with-libssh2'
    else
      args << '--without-libssh2'
    end

    if build.with? 'more-dns'
      args << '--enable-ares'
    else
      args << '--disable-ares' << '--without-libidn2' << '--without-libpsl'
    end

    if build.with? 'rtmpdump'
      ENV.prepend_path 'PKG_CONFIG_PATH', "#{Formula['rtmpdump'].opt_lib}/pkgconfig"
      args << '--with-librtmp'
    else
      args << '--without-librtmp'
    end

    if build.with? 'zstd'
      ENV.prepend_path 'PKG_CONFIG_PATH', "#{Formula['zstd'].opt_lib}/pkgconfig"
      args << '--with-zstd'
    else
      args << '--without-zstd'
    end

    # Tiger/Leopard ship with a horrendously outdated set of certs,
    # breaking any software that relies on curl, e.g. git
    args << "--with-ca-bundle=#{HOMEBREW_PREFIX}/share/ca-bundle.crt"

    system "./configure", *args
    system "make"
    # no `make test` because the one that compares Curl’s errors to its documentation of them fails
    system "make", "install"
    system "make", "install", "-C", "scripts"
    libexec.install "scripts/mk-ca-bundle.pl"
  end

  def caveats
    <<-_.undent
      cURL will be built with the ability to use Brotli compression, if that formula
      is already installed when cURL is brewed.  (The Brotli formula cannot be
      automatically brewed as a cURL dependency because it depends on CMake, which
      depends on cURL.)
    _
  end

  test do
    # Fetch the curl tarball and see that the checksum matches.
    # This requires a network connection, but so does Homebrew in general.
    filename = (testpath/"test.tar.gz")
    system "#{bin}/curl", "-L", stable.url, "-o", filename
    filename.verify_checksum stable.checksum

    # Perl is a dependency of OpenSSL3, so it will /usually/ be present
    if Formula["perl"].installed?
      ENV.prepend_path "PATH", Formula["perl"].opt_bin
      # so mk-ca-bundle can find it
      ENV.prepend_path "PATH", Formula["curl"].opt_bin
      system libexec/"mk-ca-bundle.pl", "test.pem"
      assert File.exist?("test.pem")
      assert File.exist?("certdata.txt")
    end
  end

end
