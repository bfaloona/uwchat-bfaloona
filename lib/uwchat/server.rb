require 'gserver'

module UWChat

  # basic chat server
  class Server < GServer

    # track active connections
    attr_reader :connections

    def initialize( port=36963, *args )
      @connections = []
      super(port, *args)

      # required for connecting and disconnecting hooks to fire
      self.audit = true
    end
 
    # add connection Connection instance to @connections
    def add_connection( port, sock, username=nil )
      log( "Adding connection on port: #{port}" )

      # create a username if one does not exist
      username ||= "chat#{port.to_s[3..-1]}"
      connection = Connection.new( port, sock, username )

      # add to list of connections
      @connections.push connection
      return connection
    end

    # remove connection from @clents
    def remove_connection( port )
      log( "Removing connection on port: #{port}" )
      @connections.delete_if{ |c| c.port == port }
    end

    # add connection
    # GServer hook invokes this method
    def connecting(socket)
      add_connection( socket.peeraddr[1], socket )
      super
    end

    # remove connection
    # GServer hook invokes this method
    def disconnecting(port)
      remove_connection( port )
      super
    end

    # connection session
    def serve( sock )
      begin
        welcome_connection( sock )
        loop do
          # nothing
          listen( sock )
        end

      rescue => e
        puts "An error occured: #{e.to_s}\n #{$@}"
        raise e
      end
    end

    # return connection given socket
    def find_connection_by_socket( socket )
      # choose peeraddr[1] vs. addr[1] by using
      # the port that does not match
      # the server listen port
      port = socket.addr[1]
      if port == self.port
        port = socket.peeraddr[1]
      end
      begin
        connection = nil
        @connections.each do |c|
          puts "CONNECTION: #{c.inspect}"
          connection = c if c.port == port
        end
      rescue => e
        puts "??!!?? #{e.to_s}" # " \n #{$@}"
        raise e
      end
      return connection
    end

    # greet connection
    def welcome_connection( sock )
      connection = find_connection_by_socket( sock )
      sock.puts "Welcome #{connection.username}"
    end

    # send message from sender to recipient
    def private(msg, sender, recipient)
      recipient.sock.puts "#{sender}: #{msg}"
      log( "[private] #{sender} to #{recipient}: #{msg}")
    end

    # send message to all connections
    def broadcast( msg )
      @connections.each do |connection|
        connection.sock.puts "Announce: #{msg}"
      end
      log( "[broadcast] #{msg}" )
    end

    # send message to all connections except sender
    def message( msg, sender )
      @connections.each do |connection|
        connection.sock.puts "#{sender}: #{msg}" unless sender.port == connection.port
      end
      log( "[message] #{sender}: #{msg}" )
    end

    def listen( sock )
      msg = sock.gets
      message( msg, find_connection_by_socket(sock) )
    end
  end

end 