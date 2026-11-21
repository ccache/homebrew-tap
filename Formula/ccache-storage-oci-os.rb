class CcacheStorageOciOs < Formula
  desc "Ccache OCI Object Storage storage helper"
  homepage "https://github.com/ccache/ccache-storage-oci-os"
  url "https://github.com/ccache/ccache-storage-oci-os/archive/refs/tags/v0.1.1.tar.gz"
  sha256 "554db44974b489a7401ed615d77b7c860388ae74d4c02d9fdb6db6f8934b552d"
  license "MIT"

  revision 1

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
    # test startup of the ccache-storage-oci-os process and
    # expect a configuration error due to missing OCI credentials
    crsh_socket = testpath/"crsh.sock"
    crsh_log = testpath/"crsh.log"

    ENV["CRSH_IPC_ENDPOINT"] = crsh_socket
    ENV["CRSH_URL"] = "oci-os://my-bucket/ccache"
    ENV["CRSH_LOGFILE"] = crsh_log
    ENV["CRSH_NUM_ATTR"] = "2"
    ENV["CRSH_ATTR_KEY_0"] = "namespace"
    ENV["CRSH_ATTR_VALUE_0"] = "axaz1abcdefg"
    ENV["CRSH_ATTR_KEY_1"] = "auth-type"
    ENV["CRSH_ATTR_VALUE_1"] = "oke_workload_identity"

    with_test_process(bin/"ccache-storage-oci-os") do
      sleep 3
      assert_match "OCI_RESOURCE_PRINCIPAL_VERSION", crsh_log.read
      refute_predicate crsh_socket, :exist?
    end
  end
end
