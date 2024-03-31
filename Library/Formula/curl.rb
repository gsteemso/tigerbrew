class Curl < Formula
  desc "Get a file from an HTTP, HTTPS or FTP server"
  homepage "https://curl.haxx.se/"
<<<<<<< HEAD
  url "https://curl.se/download/curl-8.7.1.tar.xz"
  sha256 "6fea2aac6a4610fbd0400afb0bcddbe7258a64c63f1f68e5855ebc0c659710cd"

  bottle do
    cellar :any
    sha256 "3df51bb4d5b3e88caee67b2e2cb93458384b9f0bdda2c35e323f00cbf689c4dd" => :tiger_altivec
=======
  url "https://curl.se/download/curl-8.5.0.tar.xz"
  sha256 "42ab8db9e20d8290a3b633e7fbb3cec15db34df65fd1015ef8ac1e4723750eeb"

  bottle do
    cellar :any
    sha256 "d1e0871cdf4c8824a602986fc041d3dd54a9eafdedff327b06f0f2ce7d218b7a" => :tiger_altivec
>>>>>>> 364b89a2ef (Ongoing efforts to unstupid superenv and to add more --universal builds)
  end

  keg_only :provided_by_osx

  option "with-c-ares",   "Build with C-ARES asynchronous DNS support"
  option "with-gsasl",    "Build with SASL authentication support"
<<<<<<< HEAD
  option "with-libressl", "Build with LibreSSL instead of OpenSSL"
  option "with-libssh2",  "Build with scp and sFTP support"
  option "with-rtmpdump", "Build with RTMP (streaming Flash) support"
=======
  option "with-libressl", "Build with LibreSSL instead of Secure Transport or OpenSSL"
  option "with-libssh2",  "Build with scp and sFTP support"
  option "with-rtmpdump", "Build with RTMP support"
>>>>>>> 364b89a2ef (Ongoing efforts to unstupid superenv and to add more --universal builds)
  option "with-zstd",     "Build with ZStandard compression support"

  deprecated_option "with-ares" => "with-c-ares"
  deprecated_option "with-rtmp" => "with-rtmpdump"
  deprecated_option "with-ssh" => "with-libssh2"

  depends_on "c-ares"   => :optional
  depends_on "gsasl"    => :optional
  depends_on "libressl" => :optional
  depends_on "libssh2"  => :optional
  depends_on "rtmpdump" => :optional
  depends_on "zstd"     => :optional

<<<<<<< HEAD
  depends_on "libidn2"     # no point in making this optional because libPSL depends on it
  depends_on "libnghttp2"
  depends_on "libpsl"
  depends_on "openssl3" if (build.without?("libressl"))
  depends_on "zlib"

  depends_on "pkg-config" => :build

  def install
    # can’t do --enable-ech yet because waiting on standards process
    # no --enable-websockets yet because needs package
    # no --with-brotli yet because needs package
    # no SSPI because is a, *spit*, Windows thing
    # TODO:
    #   HTTP/3 -- needs NGHTTP3 package and NGTCP2
    #   NGTCP2 -- needs package
=======
  if (build.without?("libressl"))
    depends_on "openssl3"
  end

  depends_on "pkg-config" => :build
  depends_on "libnghttp2"
  depends_on "zlib"

  def install
    # can’t do --enable-ech yet because waiting on standards process
    # no --enable-websockets because is experimental
    # no SSPI because is a, *spit*, Windows thing
    # TODO:  HTTP/3 -- needs one of four optional prerequisite packages
>>>>>>> 364b89a2ef (Ongoing efforts to unstupid superenv and to add more --universal builds)
    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --disable-debug
      --with-gssapi
<<<<<<< HEAD
      --with-libidn2
      --with-zlib=#{Formula["zlib"].opt_prefix}
    ]
    args << (ARGV.verbose? ? "--disable-silent-rules" : "--enable-silent-rules")
=======
      --with-zlib=#{Formula["zlib"].opt_prefix}
    ]
    args << "--disable-silent-rules" if ARGV.verbose?
>>>>>>> 364b89a2ef (Ongoing efforts to unstupid superenv and to add more --universal builds)

    # cURL has a new firm desire to find ssl with PKG_CONFIG_PATH instead of using
    # "--with-ssl" any more. "when possible, set the PKG_CONFIG_PATH environment
    # variable instead of using this option". Multi-SSL choice breaks w/o using it.
    if build.with? "libressl"
      ENV.prepend_path "PKG_CONFIG_PATH", "#{Formula["libressl"].opt_lib}/pkgconfig"
      args << "--with-ssl=#{Formula["libressl"].opt_prefix}"
      args << "--with-ca-bundle=#{etc}/libressl/cert.pem"
    else
      ENV.prepend_path "PKG_CONFIG_PATH", "#{Formula["openssl3"].opt_lib}/pkgconfig"
      args << "--with-ssl=#{Formula["openssl3"].opt_prefix}"
      args << "--with-ca-bundle=#{etc}/openssl@3/cert.pem"
    end

    args << (build.with?("c-ares") ? "--enable-ares=#{Formula["c-ares"].opt_prefix}" : "--disable-ares")
    args << (build.with?("libssh2") ? "--with-libssh2" : "--without-libssh2")
    args << (build.with?("rtmpdump") ? "--with-librtmp" : "--without-librtmp")

    # Tiger/Leopard ship with a horrendously outdated set of certs,
    # breaking any software that relies on curl, e.g. git
    args << "--with-ca-bundle=#{HOMEBREW_PREFIX}/share/ca-bundle.crt"

    system "./configure", *args
<<<<<<< HEAD
    system "make"
    # no `make test` because the one that compares Curl’s errors to its docs is the only failure
=======
>>>>>>> 364b89a2ef (Ongoing efforts to unstupid superenv and to add more --universal builds)
    system "make", "install"
    system "make", "install", "-C", "scripts"
    libexec.install "scripts/mk-ca-bundle.pl"
  end

  test do
    # Fetch the curl tarball and see that the checksum matches.
    # This requires a network connection, but so does Homebrew in general.
    filename = (testpath/"test.tar.gz")
    system "#{bin}/curl", "-L", stable.url, "-o", filename
    filename.verify_checksum stable.checksum

    # so mk-ca-bundle can find it
    ENV.prepend_path "PATH", Formula["curl"].opt_bin
    system libexec/"mk-ca-bundle.pl", "test.pem"
    assert File.exist?("test.pem")
    assert File.exist?("certdata.txt")
  end

end
