module UWChat

  class Client

    class NotAuthorized < Exception; end

    attr_reader :port
    
    def initialize( server='localhost', port=36963 )
      @server = server
      @port = port
    end

    # start and run the client connection
    def start
      begin
        socket = connect()
      rescue NotAuthorized => e
        return nil
      rescue Errno::ECONNREFUSED => e
        puts "The connection was refused (#{e.to_s}). Goodbye."
        return nil
      rescue => e
        puts "Failed to connect: #{e.to_s}\n #{$@}"
        return nil
      end

      return nil unless socket

      begin
        listen_thread =
        Thread.new do
          print '> '
          STDOUT.flush
          loop do
            scribe( socket )
          end
        end

        loop do
          deliver( socket )
        end

      rescue => e
        puts "An error occured: #{e.to_s}\n #{$@}"
      ensure
        listen_thread.kill if listen_thread
        disconnect( socket )
      end
    end
    
    # create a connection to the server
    def connect
      auth = authentication_prompt()

      socket = TCPSocket.new( @server, @port )
      raise RuntimeError, "Unable to connect to #{@port}" unless socket
      print "Connecting at #{Time.now} to #{@port} ... "

      authenticate_with_server( socket, auth[:u], auth[:p] )

      return socket
    end

    # collect username and password and authenticate with server
    def authentication_prompt( )
      puts "Username:"
      username = $stdin.gets.chomp
      puts "Password:"
      password = $stdin.gets.chomp
      raise NotAuthorized unless username.match(/\S/)
      raise NotAuthorized unless password.match(/\S/)
      return {:u => username, :p => password}
    end

    # interact with server to authenticate
    def authenticate_with_server( socket, username, password )
      authkey = send_username( socket, username )
      salted_password = salt_password( authkey, password )
      response = send_salty_password( socket, salted_password )
      case response
      when "AUTHORIZED"
        puts response
      when "NOT AUTHORIZED"
        puts response
        raise NotAuthorized, "NOT AUTHORIZED"
      else
        puts "Server response unknown: #{response}"
        raise NotAuthorized, "NOT AUTHORIZED"
      end
    end

    # send username and return authkey
    def send_username( socket, username )
      socket.puts username
      socket.flush
      authkey = socket.gets.chomp
      return authkey
    end

    # send hashed password and return AUTHORIZED/NOT AUTHORIZED message
    def send_salty_password( socket, salted_password )
      socket.puts salted_password
      socket.flush
      auth_message = socket.gets.chomp
      return auth_message
    end

    # hashes a password with an authkey
    def salt_password( authkey, password )
      combined = authkey.to_s + password.to_s
      return Digest::MD5.hexdigest(combined)
    end


    # print incomming text to console
    def scribe( socket )
      data = nil
      data = socket.gets.chomp
      
      puts data
      print '> '
      STDOUT.flush
    end

    # send console text to the server
    def deliver( socket )
      input = $stdin.gets.chomp
      if input
        socket.puts input
        socket.flush
        input = nil
        return if socket.closed?
        print '> '
        STDOUT.flush
      end
    end

    
    # close the socket
    def disconnect( socket )
      socket.close if socket and !socket.closed?
    end

  end

end