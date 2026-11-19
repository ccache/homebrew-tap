class CcacheStorageRedis < Formula
  desc "Ccache Redis storage helper"
  homepage "https://github.com/ccache/ccache-storage-redis"
  url "https://github.com/ccache/ccache-storage-redis/archive/refs/tags/v0.2.1.tar.gz"
  sha256 "56cd23972860ba2caa17efffcff31dc9a327cfd717217ab680cac8e94871c006"
  license "MIT"

  bottle do
    root_url "https://ghcr.io/v2/ccache/tap"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "0fab91d0cc99a61d72924d1a5b48a8f5028b569c3931e481a100beacf2c87b91"
    sha256 cellar: :any,                 x86_64_linux: "be4ce85c5e4428798e9b9896b332065770dbd8898ff3a8b0c7fd237e082e8a31"
  end

  depends_on "go" => :build

  deny_network_access!

  def fetch
    system "go", "mod", "download"
  end

  def install
    system "go", "build", *std_go_args
    bin.install_symlink "ccache-storage-redis" => "ccache-storage-rediss"
    bin.install_symlink "ccache-storage-redis" => "ccache-storage-redis+unix"
  end

  test do
    system "true"
    # system bin/"ccache-storage-redis", "--version"
  end
end
