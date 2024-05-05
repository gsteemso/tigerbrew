class Brotli < Formula
  desc 'Lossless streaming compression (see RFC 7932)'
  homepage 'https://brotli.org/'
  url 'https://github.com/google/brotli/archive/refs/tags/v1.1.0.tar.gz'
  version '1.1.0'
  sha256 'e720a6ca29428b803f4ad165371771f5398faba397edf6778837a18599ea13ff'

  depends_on "cmake" => :build

  def install
    mkdir 'build-dir'
    system 'cd', 'build-dir'
    system 'cmake', '-DCMAKE_BUILD_TYPE=Release', "-DCMAKE_INSTALL_PREFIX=#{prefix}", '..'
    system 'cmake', '--build', '.', '--config', 'Release', '--target', 'install'
  end

  def caveats <<-_.undent
    if Python 3 is installed, language bindings for it are available via Pip:
      pip3 install brotli
  _

  test do
    # `test do` will create, run in and delete a temporary directory.
    #
    # The installed folder is not in the path, so use the entire path to any
    # executables being tested: `system "#{bin}/program", "do", "something"`.
    system 'false'
  end
end
