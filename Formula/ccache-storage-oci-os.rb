class CcacheStorageOciOs < Formula
  desc "Ccache OCI Object Storage storage helper"
  homepage "https://github.com/ccache/ccache-storage-oci-os"
  url "https://github.com/ccache/ccache-storage-oci-os/archive/refs/tags/v0.1.1.tar.gz"
  sha256 "554db44974b489a7401ed615d77b7c860388ae74d4c02d9fdb6db6f8934b552d"
  license "MIT"

  bottle do
    root_url "https://ghcr.io/v2/ccache/tap"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "040f4d41612fd8e7d776ef041cf65948d6bde98819cc89a003b87ff3b2894851"
    sha256 cellar: :any,                 x86_64_linux: "ea578e6e3bc67ffedb775ab6df41ea12927959519949b062480f8127c9a4b1b0"
  end

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
