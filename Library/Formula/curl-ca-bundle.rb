class CurlCaBundle < Formula
  desc 'Modern certificate-authority bundle from the Curl project'
  homepage "http://curl.haxx.se/docs/caextract.html"
  url "https://curl.se/ca/cacert-2024-03-11.pem",
    :using => :nounzip
<<<<<<< HEAD
  version "2023-08-22"
  sha256 "23c2469e2a568362a62eecf1b49ed90a15621e6fa30e29947ded3436422de9b9"
=======
  sha256 "1794c1d4f7055b7d02c2170337b61b48a2ef6c90d77e95444fd2596f4cac609f"
  version "2024-03-11"
>>>>>>> 97f106572f (curl-ca-bundle 2024-03-11)

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
