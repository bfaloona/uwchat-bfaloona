module UWChat

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
  
end