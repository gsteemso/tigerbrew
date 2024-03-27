class Curl < Formula
  desc "Get a file from an HTTP, HTTPS or FTP server"
  homepage "https://curl.haxx.se/"
  url "https://curl.se/download/curl-8.5.0.tar.xz"
  sha256 "42ab8db9e20d8290a3b633e7fbb3cec15db34df65fd1015ef8ac1e4723750eeb"

  bottle do
    cellar :any
    sha256 "d1e0871cdf4c8824a602986fc041d3dd54a9eafdedff327b06f0f2ce7d218b7a" => :tiger_altivec
  end

  keg_only :provided_by_osx

  option "with-c-ares",   "Build with C-ARES asynchronous DNS support"
  option "with-gsasl",    "Build with SASL authentication support"
  option "with-libressl", "Build with LibreSSL instead of Secure Transport or OpenSSL"
  option "with-libssh2",  "Build with scp and sFTP support"
  option "with-rtmpdump", "Build with RTMP support"
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
    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --disable-silent-rules
      --disable-debug
      --with-gssapi
      --with-zlib=#{Formula["zlib"].opt_prefix}
    ]

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
