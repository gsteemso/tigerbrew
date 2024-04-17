class Libpsl < Formula
  desc 'C library for the Public Suffix List'
  homepage 'rockdaboot.github.io/libpsl'
  url 'https://github.com/rockdaboot/libpsl/releases/download/0.21.5/libpsl-0.21.5.tar.lz'
  sha256 '9a9f6a8c6edba650cf9ea55475cd172dd28487316804e9c73202d97572cd3a2d'

  depends_on 'libidn2'
  depends_on 'libunistring'
  depends_on :python => :build

  def install
    args = %W[
      --disable-dependency-tracking
      --prefix=#{prefix}
      --disable-gtk-doc
      --enable-man
      --enable-ubsan
      --enable-asan
      --enable-builtin
    ]
    args << (ARGV.verbose? ? '--disable-silent-rules' : '--enable-silent-rules')

    system './configure', *args
    system 'make'
    system 'make', 'check'
    system 'make', 'install'
  end

  test do
    # `test do` will create, run in and delete a temporary directory.
    #
    # This test will fail and we won't accept that! It's enough to just replace
    # "false" with the main program this formula installs, but it'd be nice if you
    # were more thorough. Run the test with `brew test libpsl`. Options passed
    # to `brew install` such as `--HEAD` also need to be provided to `brew test`.
    #
    # The installed folder is not in the path, so use the entire path to any
    # executables being tested: `system "#{bin}/program", "do", "something"`.
    system "false"
  end
end
