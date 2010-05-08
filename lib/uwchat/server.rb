require 'gserver'

module UWChat

  class AuthenticationFailed < RuntimeError; end

  class Server < GServer
    attr_reader :clients

    def initialize( port=36963, *args )
      Struct.new("Client", :port, :username)
      @clients = []
      super(port, *args)
    end

    def new_client( port, username=nil )
      log( "Adding client on port: #{port}" )
      client = Struct::Client.new( port, username )
      @clients.push client
      client
    end

    def remove_client( port )
      log( "Removing client on port: #{port}" )
      @clients.delete_if{ |c| c.port == port }
    end

    def connecting(client)
      new_client( client.peeraddr[1] )
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

    def welcome_client( io )
      client = find_client_by_socket( io )
      io.puts "Welcome #{client.username}"
    end
  end

end 