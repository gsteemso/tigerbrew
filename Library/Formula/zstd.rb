class Zstd < Formula
  desc 'Zstandard - fast real-time compression algorithm'
  homepage 'https://www.zstd.net/'
  url 'https://github.com/facebook/zstd/releases/download/v1.5.5/zstd-1.5.5.tar.gz'
  sha256 '9c4396cc829cfae319a6e2615202e82aad41372073482fce286fac78646d3ee4'

  option :universal

  if MacOS.version < :leopard
    depends_on 'apple-gcc42' => :build  # Apple GCC 4.2.1 build 5553 (Tigerbrew’s) can’t build this.
                                        # Build 5577 (Leopard’s) can.
    depends_on 'cctools'     => :build  # Needs a more recent "as".
    depends_on 'ld64'        => :build  # Tiger's system `ld` can't build the library.
    depends_on 'make'        => :build  # Tiger's system `make` can't handle the makefile.
  end

  def install
    ENV.universal_binary if build.universal?
    ENV.deparallelize

    # the “install” target covers the static and the dynamic libraries, the
    # program binaries, and the manpages.  It does not install any of the other
    # things available within the distribution (some of which Tigerbrew can’t
    # build anyway).
    make "prefix=#{prefix}", 'install'
  end

  test do
    system bin/'zstd', '-z', '-o', './zstdliest.zst', bin/'zstd'
    system bin/'zstd', '-t', 'zstdliest.zst'
    system bin/'zstd', '-d', 'zstdliest.zst'
    system 'diff', '-s', 'zstdliest', bin/'zstd'
  end
end
