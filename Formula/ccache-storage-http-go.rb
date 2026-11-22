class CcacheStorageHttpGo < Formula
  desc "Ccache HTTP(S) storage helper (Go)"
  homepage "https://github.com/ccache/ccache-storage-http-go"
  url "https://github.com/ccache/ccache-storage-http-go/archive/refs/tags/v0.10.1.tar.gz"
  sha256 "e9f78a4df3a56178ab7003a3a82c4e8e982fde3e0b227af44f973f8ca5446741"
  license "MIT"

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
    # Launch the storage helper ourselves instead of letting ccache spawn it:
    # the test sandbox only allows Unix socket connections below testpath, but
    # ccache puts the helper socket in /tmp/ccache-tmp-<uid>, and moving it
    # below testpath via XDG_RUNTIME_DIR exceeds the 104-byte socket path limit.
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

    ENV["CCACHE_DIR"] = testpath/"ccache"
    ENV["CCACHE_REMOTE_ONLY"] = "1"
    ENV["CCACHE_REMOTE_STORAGE"] = "crsh:#{crsh_socket}"

    ENV["CRSH_IPC_ENDPOINT"] = crsh_socket
    ENV["CRSH_URL"] = "http://127.0.0.1:#{nginx_port}"

    (testpath/"test.c").write("int main(void) { return 0; }\n")

    with_test_process(nginx_bin, "-c", nginx_conf, "-p", testpath,
                      "-e", testpath/"nginx-error.log", "-g", "daemon off;") do
      nginx_ready = false
      50.times do
        TCPSocket.new("127.0.0.1", nginx_port).close
        nginx_ready = true
        break
      rescue Errno::ECONNREFUSED
        sleep 0.1
      end
      assert nginx_ready, "nginx did not start listening on port #{nginx_port}"

      with_test_process(bin/"ccache-storage-http") do
        50.times do
          break if crsh_socket.socket?

          sleep 0.1
        end
        assert_predicate crsh_socket, :socket?, "Storage helper did not create its IPC socket"

        3.times do
          system ccache_bin, ENV.cc, "-c", "test.c"
        end

        stats = JSON.parse(shell_output("#{ccache_bin} --print-stats --format json"))
        expected = {
          "remote_storage_error"   => 0,
          "remote_storage_timeout" => 0,
          "remote_storage_miss"    => 1,
          "remote_storage_hit"     => 2,
        }
        assert_equal expected, stats.slice(*expected.keys),
                     "Expected one remote miss followed by two remote hits via nginx"
      end
    end
  end
end
