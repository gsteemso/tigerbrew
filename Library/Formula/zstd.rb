class Zstd < Formula
  desc 'Zstandard - fast real-time compression algorithm'
  homepage 'https://www.zstd.net/'
  url 'https://github.com/facebook/zstd/releases/download/v1.5.5/zstd-1.5.5.tar.gz'
  version '1.5.5'
  sha256 '9c4396cc829cfae319a6e2615202e82aad41372073482fce286fac78646d3ee4'

  depends_on 'cctools' => :build  # Needs a relatively recent "as".
  depends_on 'gcc'     => :build  # GCC 4.x doesn't know some of the compiler flags.
  if MacOS.version < :leopard  # Need to test this under Leopard
    depends_on 'ld64'  => :build  # Tiger's system `ld` can't build the library.
    depends_on 'make'  => :build  # Tiger's system `make` can't handle the makefile.
  end

  def install
    ENV.deparallelize

    args = %W[
      prefix=#{prefix}
      CC=#{Formula["gcc"].bin}/gcc-#{Formula["gcc"].version_suffix}
    ]
    # the “install” target covers the static and the dynamic libraries, the
    # program binaries, and the manpages.  It does not install any of the other
    # things available within the distribution (some of which Tigerbrew can’t
    # build anyway).
    make *args, 'install'
  end

  test do
    # `test do` will create, run in and delete a temporary directory.
    # The installed folder is not in the path, so use the entire path to any
    # executables being tested: `system "#{bin}/program", "do", "something"`.
    system 'false'
  end
end
