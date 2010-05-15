require 'gserver'
require 'yaml'
require 'digest/md5'
require 'timeout'

module UWChat

  # basic chat server
  class Server < GServer

    # track active client connections
    attr_reader :clients

    def initialize( passwd_filepath, port=36963, *args )
      @clients = []
      # load passwd file specified
      raise ArgumentError unless File.exists?(passwd_filepath.to_s)
      begin
        @passwds = YAML::load( File.read(passwd_filepath.to_s) )
      rescue ArgumentError => e
        raise ArgumentError, "Failed to open password file"
        exit
      end
      super(port, *args)
      # turn audit on (so connecting and disconnecting hooks are invoked)
      self.audit = true
    end
 
    # add client Connection instance to @clients
    def add_client( port, sock )
      log( "Adding client on port: #{port}" )
      client = Connection.new( port, sock )
      @clients.push client
      client
    end

    # remove client from @clents
    def remove_client( port )
      log( "Removing client on port: #{port}" )
      @clients.delete_if{ |c| c.port == port }
    end

    # add client when a socket connects
    # a GServer hook
    def connecting(socket)
      add_client( socket.peeraddr[1], socket )
      super
    end

    # remove client when a socket connects
    # a GServer hook
    def disconnecting(clientPort)
      remove_client( clientPort )
      super
    end

    # the entire client session
    def serve( sock )
      begin

        if authenticate( sock )
          welcome_client( sock )

          loop do
            listen( sock )
          end
        end

      rescue => e
        puts "An error occured: #{e.to_s}"
        raise e
      ensure
        sock.close if sock and !sock.closed?
      end
    end

    # authenticate the connecting client
    def authenticate( socket )
      username = nil
      authkey = nil
      salty_password = nil
      
      begin
        Timeout::timeout(2) do          
          username, authkey, salty_password =
            get_auth_values( socket )
        end
      rescue Timeout::Error => e
        log( "Authentication timed out.")
        socket.close
        return nil
      rescue => e
        log( "Unknown Authentication error: #{e.to_s}")
        socket.close
        return nil
      end

      if valid_password?( salty_password, authkey, username )
        socket.puts "AUTHORIZED"
        # update client's username
        client = find_client_by_socket( socket )
        client.username = username
        return true
      else
        socket.puts "NOT AUTHORIZED"
        log( "Authentication Failed #{socket.peeraddr[2]}:#{socket.peeraddr[1]}" )
        socket.close
        return nil
      end
    end

    # execute network protocol to authenticate
    def get_auth_values( socket )
      username = socket.gets.chomp
      authkey = salt(username)

      socket.puts authkey
      salty_password = socket.gets.chomp

      return [username, authkey, salty_password]
    end

    # return an authkey
    def salt( username )
      Digest::MD5.hexdigest( username + Time.now.to_s )
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

    # listen to the socket and send text to other clients
    def listen( sock )
      msg = sock.gets.chomp

      message( msg, find_client_by_socket(sock) ) if msg
    end

    # validate salty_password against passwd file using authkey
    def valid_password?( salty_password=nil, authkey=nil, username=nil )
      # nil values?
      return nil if salty_password.nil? or authkey.nil? or username.nil?
      # empty strings?
      return nil if salty_password.empty? or authkey.empty? or username.empty?
      # unknown users?
      return nil unless @passwds.keys.include?( username )

      # valid password?
      return true if salty_password == Digest::MD5.hexdigest( authkey << @passwds[username] )

      # just to be safe
      return nil
    end

  end

end
