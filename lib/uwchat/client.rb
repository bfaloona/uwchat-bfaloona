module UWChat

  class Client

    def initialize( port=36963 )
      @port = port
    end

    def start
      begin
        socket = connect()

        listen_thread =
        Thread.new do
          loop do
            scribe( socket )
          end
        end

        loop do
          deliver( socket )
        end

      rescue Errno::ECONNREFUSED => e
        puts "The connection was refused (#{e.to_s}). Goodbye."
      rescue => e
        puts "An error occured: #{e.to_s}\n #{$@}"
      ensure
        listen_thread.kill if listen_thread
        disconnect( socket )
      end
    end
    
    def connect
      socket = TCPSocket.new( 'localhost', @port )
      raise RuntimeError, "Unable to connect to #{@port}" unless socket
      puts "Connected at #{Time.now} to #{@port}"
      welcome_msg = socket.gets
      puts welcome_msg
      print '> '
      STDOUT.flush
      return socket
    end

    def scribe( socket )
      begin
        data = socket.gets.chomp
      rescue EOFError
        # ignore End of file errors
      end

      if data && data.match( /^\^\^\[([\w]+)\](?:\[(.*)\])$/)
        cmd = Regexp.last_match(1)
        cmd_data = Regexp.last_match(2)
        process_command( cmd, cmd_data )
      elsif data
        puts data
        print '> '
        STDOUT.flush
        data = nil
      end
    end

    def deliver( socket )
      input = gets.chomp
      if input
        socket.puts input
        socket.flush
        input = nil
        print '> '
        STDOUT.flush
      end
    end

    def disconnect( socket )
      socket.close if socket
    end

  end

end