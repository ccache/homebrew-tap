class CcacheStorageOciOs < Formula
  desc "Ccache OCI Object Storage storage helper"
  homepage "https://github.com/ccache/ccache-storage-oci-os"
  url "https://github.com/ccache/ccache-storage-oci-os/archive/refs/tags/v0.1.1.tar.gz"
  sha256 "554db44974b489a7401ed615d77b7c860388ae74d4c02d9fdb6db6f8934b552d"
  license "MIT"

  depends_on "go" => :build

  deny_network_access!

  def fetch
    system "go", "mod", "download"
  end

  def install
    system "go", "build", *std_go_args
  end

  test do
    system "true"
    # system bin/"ccache-storage-oci-os", "--version"
  end
end
