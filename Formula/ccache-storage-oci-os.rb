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
      found = false
      50.times do
        found = crsh_log.exist? && crsh_log.read.include?("OCI_RESOURCE_PRINCIPAL_VERSION")
        break if found

        sleep 0.1
      end
      assert found, "Expected OCI_RESOURCE_PRINCIPAL_VERSION error in #{crsh_log}"
      refute_path_exists crsh_socket, "IPC socket must not exist when OCI authentication fails"
    end
  end
end
