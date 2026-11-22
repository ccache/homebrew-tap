class CcacheStorageHttpGo < Formula
  desc "Ccache HTTP(S) storage helper (Go)"
  homepage "https://github.com/ccache/ccache-storage-http-go"
  url "https://github.com/ccache/ccache-storage-http-go/archive/refs/tags/v0.10.1.tar.gz"
  sha256 "e9f78a4df3a56178ab7003a3a82c4e8e982fde3e0b227af44f973f8ca5446741"
  license "MIT"

  revision 1

  bottle do
    root_url "https://ghcr.io/v2/ccache/tap"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "ce584d8e4168a712f5a9d4132fb37fe3c490fe75d9a8d64793dcfd2ceec393ea"
    sha256 cellar: :any,                 x86_64_linux: "6f1d756a67a02120b6c25a51424ea3c48b160a6b5065eec5aa13f7d99015baa7"
  end

  depends_on "go" => :build
  depends_on "ccache" => :test
  depends_on "nginx" => :test

  deny_network_access! [:build, :postinstall] # testing needs loopback network access

  def fetch
    system "go", "mod", "download"
  end

  def install
    system "go", "build", *std_go_args(output: bin/"ccache-storage-http")
    bin.install_symlink "ccache-storage-http" => "ccache-storage-https"
  end

  test do
    # We need to launch the storage helper on our own because the Unix domain
    # socket path that ccache generates for the helper is too long inside the
    # test directory.
    ccache_bin = formula_opt_bin("ccache")/"ccache"
    nginx_bin = formula_opt_bin("nginx")/"nginx"
    crsh_socket = testpath/"crsh.sock"
    nginx_root = testpath/"nginx-root"
    nginx_conf = testpath/"nginx.conf"
    nginx_port = free_port

    nginx_root.mkpath
    nginx_conf.write <<~NGINX
      pid #{testpath}/nginx.pid;
      events {}
      http {
        access_log off;
        client_body_temp_path #{testpath}/nginx-body;
        server {
          listen 127.0.0.1:#{nginx_port};
          root #{nginx_root};
          location / {
            dav_methods PUT DELETE;
            create_full_put_path on;
          }
        }
      }
    NGINX

    ENV["CCACHE_DIR"] = (testpath/"ccache").to_s
    ENV["CCACHE_REMOTE_ONLY"] = "1"
    ENV["CCACHE_REMOTE_STORAGE"] = "crsh:#{crsh_socket}"

    ENV["CRSH_IPC_ENDPOINT"] = crsh_socket.to_s
    ENV["CRSH_URL"] = "http://127.0.0.1:#{nginx_port}"

    (testpath/"test.c").write("int main(void) { return 0; }\n")

    with_test_process(nginx_bin, "-c", nginx_conf, "-p", testpath,
                      "-e", testpath/"nginx-error.log", "-g", "daemon off;") do
      50.times do
        TCPSocket.new("127.0.0.1", nginx_port).close
        break
      rescue Errno::ECONNREFUSED
        sleep 0.1
      end

      with_test_process(bin/"ccache-storage-http") do
        50.times do
          break if crsh_socket.socket?

          sleep 0.1
        end
        assert_predicate crsh_socket, :socket?, "Storage helper did not create its IPC socket"

        3.times do
          system ccache_bin, "cc", "-c", "test.c"
        end

        stats = JSON.parse(shell_output("#{ccache_bin} --print-stats --format json"))
        assert_equal 0, stats["remote_storage_error"]
        assert_equal 0, stats["remote_storage_timeout"]
        assert_equal 1, stats["remote_storage_miss"]
        assert_equal 2, stats["remote_storage_hit"]
      end
    end
  end
end
