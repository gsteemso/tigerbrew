class CurlCaBundle < Formula
  desc 'Modern certificate-authority bundle from the Curl project'
  homepage "http://curl.haxx.se/docs/caextract.html"
  url "https://curl.se/ca/cacert-2024-03-11.pem",
    :using => :nounzip
  version "2024-03-11"
  sha256 "1794c1d4f7055b7d02c2170337b61b48a2ef6c90d77e95444fd2596f4cac609f"

  bottle do
    cellar :any
  end

  def install
    share.install "cacert-#{version}.pem" => "ca-bundle.crt"
  end

  test do
    true
  end
end
