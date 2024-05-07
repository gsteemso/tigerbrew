class TigerOnly < Requirement
  def message; <<-EOS.undent
    gcc-4.2 is only provided for Tiger, as it is officially available
    from an Xcode shipped with Leopard.
    EOS
  end
  def satisfied?; MacOS.version == :tiger; end
  def fatal?; true; end
end

class AppleGcc42 < Formula
  desc 'the Apple version of the GNU Compiler Collection for OS X Tiger'
  homepage 'http://r.research.att.com/tools/'
  url 'https://ia902307.us.archive.org/31/items/tigerbrew/gcc-42-5553-darwin8-all.tar.gz'
  mirror 'http://r.research.att.com/gcc-42-5553-darwin8-all.tar.gz'
  version '4.2.1-5553'
  sha256 '85f4a4be48ead22b016142504f955adc2da7aa1eb1e44590263ca52f8c8a598a'

  depends_on TigerOnly

  def install
    cd 'usr' do
      prefix.install Dir['*']
    end
  end

  def caveats
    <<-EOS.undent
      This formula contains compilers built from Apple's GCC sources, build
      5553, available from:

        http://opensource.apple.com/tarballs/gcc

      All compilers have a `-4.2` suffix. A GFortran compiler is also included.
    EOS
  end
end
