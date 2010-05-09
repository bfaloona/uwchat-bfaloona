require 'gserver'

module UWChat

  class AuthenticationFailed < RuntimeError; end

  # a chat client connection
  class Connection

    attr_reader :port, :sock, :username

    def initialize( port, sock, username=nil )
      @port = port
      @sock = sock
      @username = username
    end

    def to_s
      "#{username || port}"
    end
  end

  class Server < GServer
    attr_reader :clients

    def initialize( port=36963, *args )
      @clients = []
      super(port, *args)
    end

    def new_client( port, sock, username=nil )
      log( "Adding client on port: #{port}" )
      client = Connection.new( port, sock, username )
      @clients.push client
      client
    end

    def remove_client( port )
      log( "Removing client on port: #{port}" )
      @clients.delete_if{ |c| c.port == port }
    end

    def connecting(client)
      new_client( client.peeraddr[1], client )
      super
    end

    def disconnecting(clientPort)
      remove_client( clientPort )
      super
    end

    def serve( io )
      begin
        welcome_client(io)
        loop do
          # nothing
          io.puts( io.gets )
        end

      rescue => e
        puts "An error occured: #{e.to_s}"
#        puts "STACK:"
#        puts $@
        raise e
      end
    end

    def find_client_by_socket( socket )      
      # choose peeraddr[1] vs. addr[1] by useing
      # the port that does not match
      # the server listen port
      port = socket.addr[1]
      if port == self.port
        port = socket.peeraddr[1]
      end
      client = @clients.select{|c| c.port == port}.first
      client
    end

    def welcome_client( sock )
      client = find_client_by_socket( sock )
      sock.puts "Welcome #{client.username}"
    end

    # send message from sender to recipient
    def private(msg, sender, recipient)
      recipient.sock.puts "#{sender}: #{msg}"
      log( "[private] #{sender} to #{recipient}: #{msg}")
    end

    # send message to all clients
    def broadcast( msg )
      @clients.each do |client|
        client.sock.puts "Announce: #{msg}"
      end
      log( "[broadcast] #{msg}" )
    end

    # send message to all clients except sender
    def message( msg, sender )
      @clients.each do |client|
        client.sock.puts "#{sender}: #{msg}" unless sender.port == client.port
      end
      log( "[message] #{sender}: #{msg}" )
    end
  end

end 