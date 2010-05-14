require 'uwchat'

describe UWChat::Client do

  describe "Network properties" do

    before( :each ) do
      # Arrange
      @client = UWChat::Client.new
      @mock_sock = mock( 'socket' )
    end

    it "should connect to port 36963 by default" do
      # Act 
      @client.port.should == 36963
    end

    it "should prompt for username and password" do
      # Expect
      @client.should_receive( :puts ).with( 'Username:' )
      @client.should_receive( :gets ).and_return( 'User!')
      @client.should_receive( :puts ).with( 'Password:' )
      @client.should_receive( :gets ).and_return( 'pAsswurd')

      # Act
      auth_hash = @client.authentication_prompt()
      
      # Assert
      auth_hash.keys.size.should == 2
      auth_hash[:u].should == 'User!'
      auth_hash[:p].should == 'pAsswurd'
    end

    it "should display the server welcome message" do
      # Expect
      @client.should_receive( :authentication_prompt ).and_return( {:u => 'user', :p => 'pass'} )

      TCPSocket.should_receive( :new ).and_return( @mock_sock )
      @client.should_receive( :puts ).with( /^Connected at / )
      @client.should_receive( :authenticate_with_server )

      # Act
      socket = @client.connect

      # Assert
      socket.class.should == Spec::Mocks::Mock
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
      @client.should_receive( :authentication_prompt ).and_return( nil )
      TCPSocket.should_receive( :new ).and_raise( Errno::ECONNREFUSED )
      @client.should_receive( :puts ).with( /The connection was refused \(.+\). Goodbye./ )

      # Act
      @client.start()
    end

  end

end