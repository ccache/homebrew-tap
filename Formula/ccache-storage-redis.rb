class CcacheStorageRedis < Formula
  desc "Ccache Redis storage helper"
  homepage "https://github.com/ccache/ccache-storage-redis"
  url "https://github.com/ccache/ccache-storage-redis/archive/refs/tags/v0.2.1.tar.gz"
  sha256 "56cd23972860ba2caa17efffcff31dc9a327cfd717217ab680cac8e94871c006"
  license "MIT"

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
