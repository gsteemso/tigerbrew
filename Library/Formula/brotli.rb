class Brotli < Formula
  desc 'Lossless streaming compression (see RFC 7932)'
  homepage 'https://brotli.org/'
  url 'https://github.com/google/brotli/archive/refs/tags/v1.0.9.tar.gz'
  sha256 'f9e8d81d0405ba66d181529af42a3354f838c939095ff99930da6aa9cdf6fe46'

  option :universal

  depends_on "cmake" => :build

  def install
    ENV.universal_binary if build.universal?
    mkdir 'build-dir'
    raise
    cd 'build-dir'
    system 'cmake', '-Wno-dev', '-DCMAKE_BUILD_TYPE=Release', "-DCMAKE_INSTALL_PREFIX=#{prefix}", '..'
    system 'cmake', '--build', '.', '--config', 'Release', '--target', 'install'
  end

  def caveats
    <<-_.undent
      if Python 3 is installed, brotli bindings for it are available via Pip:
        pip3 install brotli
    _
  end

  test do
    system bin/'brotli', '-k', '-o', './brotliest.br', bin/'brotli'
    system bin/'brotli', '-t', 'brotliest.br'
    system bin/'brotli', '-d', 'brotliest.br'
    system 'diff', '-s', 'brotliest', bin/'brotli'
  end
end
