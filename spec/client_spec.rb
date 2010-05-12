require 'uwchat'

describe UWChat::Client do

  describe "Network properties" do

    before( :each ) do
      # Arrange
      @client = UWChat::Client.new
      @mock_sock = mock( 'socket' )
    end

    it "should connect to port 36963 by default" do
      # Expect
      TCPSocket.should_receive( :new ).with( 'localhost', 36963 ).and_return( StringIO.new )

      # Act 
      @client.connect
    end

    it "should display the server welcome message" do
      # Expect
      TCPSocket.should_receive( :new ).and_return( @mock_sock )
      @mock_sock.should_receive( :gets ).and_return( 'Welcome user' )
      @client.should_receive( :puts ).with( 'Welcome user' )
      @client.should_receive( :puts ).with( /^Connected at / )

      # Act
      @client.connect
    end

    it "should display normal text sent from the server" do
      # Expect
      @mock_sock.should_receive( :gets ).and_return( "larry: i'm hungry" )
      @client.should_receive( :puts ).with( "larry: i'm hungry" )

      # Act
      @client.scribe( @mock_sock )
    end

    it "should process commands from the server" do
      # Expect
      @mock_sock.should_receive( :gets ).and_return( "^^[boot][you are mean]" )
      @client.should_receive( :process_command ).with( "boot", "you are mean" )

      # Act
      @client.scribe( @mock_sock )
    end

    it "should send messages to the server" do
      # Expect
      @mock_sock.should_receive( :gets ).and_return( "I'm a nut!\n")
      @client.should_receive( :puts ).with( "I'm a nut!")

      # Act
      @client.scribe( @mock_sock )
    end

    it "should quit gracefully if a network error is encountered" do
      # Expect
      TCPSocket.should_receive( :new ).and_raise( Errno::ECONNREFUSED )
      @client.should_receive( :puts ).with( /The connection was refused \(.+\). Goodbye./ )
      @client.should_receive( :disconnect )

      # Act
      @client.start()
    end

  end

end