require 'gserver'

module UWChat

  # basic chat server
  class Server < GServer

    # track active client connections
    attr_reader :clients

    def initialize( port=36963, *args )
      @clients = []
      super(port, *args)
      self.audit = true
    end
 
    # add client Connection instance to @clients
    def add_client( port, sock, username=nil )
      log( "Adding client on port: #{port}" )
      username ||= "chat#{port.to_s[3..-1]}"
      client = Connection.new( port, sock, username )
      @clients.push client
      client
    end

    # remove client from @clents
    def remove_client( port )
      log( "Removing client on port: #{port}" )
      @clients.delete_if{ |c| c.port == port }
    end

    # add client when GServer invokes
    def connecting(client)
      add_client( client.peeraddr[1], client )
      super
    end

    # clean up when GServer invokes
    def disconnecting(clientPort)
      remove_client( clientPort )
      super
    end

    # client session
    def serve( sock )
      begin
        welcome_client( sock )
        loop do
          # nothing
          listen( sock )
        end

      rescue => e
        puts "An error occured: #{e.to_s}"
#        puts "STACK:"
#        puts $@
        raise e
      end
    end

    # return client given socket
    def find_client_by_socket( socket )
      # choose peeraddr[1] vs. addr[1] by using
      # the port that does not match
      # the server listen port
      port = socket.addr[1]
      if port == self.port
        port = socket.peeraddr[1]
      end
      client = @clients.select{|c| c.port == port}.first
      client
    end

    # greet client
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

    def listen( sock )
      msg = sock.gets
      message( msg, find_client_by_socket(sock) )
    end
  end

end 