module UWChat

  class Client

    # TCPSocket connection to the server
    attr_reader :sock

    def initialize( port=36963 )
      @port = port
    end

    def start
      begin
        connect()
        listener = Thread.new do
          loop do
            scribe( @sock )
          end
        end
        loop do
          send( @sock )
        end
      rescue Errno::ECONNREFUSED => e
        puts "A network error occurred (#{e.to_s}). Goodbye."
      rescue => e
        puts "An error occured: #{e.to_s}"
      ensure
        listener.kill if listener
        disconnect
      end
    end

    def connect
      @sock = TCPSocket.new( 'localhost', @port )
      welcome_msg = @sock.gets
      puts welcome_msg
    end

    def scribe( socket )
      message = socket.gets.chomp

      if message && message.match( /^\^\^\[([\w]+)\](?:\[(.*)\])$/)
        cmd = Regexp.last_match(1)
        data = Regexp.last_match(2)
        process_command( cmd, data )
      elsif message
        puts message
      end
    end

    def await_input 

    end

    def disconnect

    end

  end

end