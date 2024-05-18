class Ronn < Formula
  desc 'The opposite of roff'
  homepage 'https://rtomayko.github.io/ronn/'
  url 'https://github.com/rtomayko/ronn/archive/refs/tags/0.7.3.zip'
  version '0.7.3'
  sha256 'c4064e63af46d2e9a3072712407ff46dfd7af8e56b5f28c5c04ef0f7bb68d730'

  def install
    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --disable-debug
    ]
    args << (ARGV.verbose? ? '--disable-silent-rules' : '--enable-silent-rules')
    system './configure', *args
    system 'make', 'install'
  end

  test do
    system 'false'
  end
end
