module UWChat

  class Client
    attr_reader :port
    
    def initialize( port=36963 )
      @port = port
    end

    # start the client connection
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
    
    # create a connection to the server
    def connect

      socket = TCPSocket.new( 'localhost', @port )
      raise RuntimeError, "Unable to connect to #{@port}" unless socket
      puts "Connected at #{Time.now} to #{@port}"

      authenticate( socket )

      print '> '
      STDOUT.flush

      return socket
    end

    # collect username and password and authenticate with server
    def authenticate( socket )
      puts "Username:"
      username = gets.chomp
      puts "Password:"
      password = gets.chomp

      authenticate_with_server( socket, username, password )
    end

    # interact with server to authenticate
    def authenticate_with_server( socket, username, password )
      authkey = send_username( socket, username )
      salted_password = salt_password( authkey, password )
      response = send_salty_password( socket, salted_password )
      case response
      when "AUTHENTICATED"
        # wheee!
      when "NOT AUTHENTICATED"
        puts response
        exit
      else
        raise RuntimeError, "Server response unknown"
      end
    end

    # send username and return authkey
    def send_username( socket, username )
      socket.puts username
      socket.flush
      authkey = socket.gets
      return authkey
    end

    # send hashed password and return AUTHORIZED/NOT AUTHORIZED message
    def send_salty_password( socket, salted_password )
      socket.puts salted_password
      socket.flush
      auth_message = socket.gets
      return auth_message
    end

    # hashes a password with an authkey
    def salt_password( authkey, password )
      combined = authkey.to_s + password.to_s
      return Digest::MD5.hexdigest(combined)
    end


    # print incomming text to console
    def scribe( socket )
      begin
        data = socket.gets.chomp
      rescue EOFError
        # ignore End of file errors
      end

      # did we get a command from the client?
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

    # send console text to the server
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

    
    # close the socket
    def disconnect( socket )
      socket.close if socket
    end

  end

end