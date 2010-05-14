require 'uwchat'

describe UWChat::Client do

  describe "Startup" do

    before( :each ) do
      # Arrange
      @client = UWChat::Client.new
      @mock_sock = mock( 'socket' )
      @username = 'User!'
      @password = 'pAsswurd'
    end

    it "should connect to port 36963 by default" do
      # Act 
      @client.port.should == 36963
    end

    it "should prompt for username and password" do
      # Expect
      @client.should_receive( :puts ).with( 'Username:' )
      @client.should_receive( :gets ).and_return( @username )
      @client.should_receive( :puts ).with( 'Password:' )
      @client.should_receive( :gets ).and_return( @password )

      # Act
      auth_hash = @client.authentication_prompt()
      
      # Assert
      auth_hash.keys.size.should == 2
      auth_hash[:u].should == @username
      auth_hash[:p].should == @password
    end

    it "should initiate connection when connect() is called" do
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

    it "should drop the connection when NotAuthorized exception is raised" do
      # Expect
      @client.should_receive( :connect ).and_raise( UWChat::Client::NotAuthorized )
      # Ensure the listen thread is never created
      Thread.should_not_receive( :new )

      # Act
      @client.start()
    end

    it "should quit gracefully if a network error is encountered" do
      # Expect
      @client.should_receive( :authentication_prompt ).and_return( nil )
      TCPSocket.should_receive( :new ).and_raise( Errno::ECONNREFUSED )
      @client.should_receive( :puts ).with( /^The connection was refused \(.+\). Goodbye.$/ )

      # Act
      @client.start()
    end

    it "should quit gracefully if an unexpected exception is raised" do
      # Expect
      @client.should_receive( :authentication_prompt ).and_return( nil )
      TCPSocket.should_receive( :new ).and_raise( ArgumentError )
      @client.should_receive( :puts ).with( /^Failed to connect: / )

      # Act
      @client.start()
    end

    it "should handle successful authentication with server" do
      # Expect
      @client.should_receive( :send_username ).with( @mock_sock, @username ).and_return( 'authkey' )
      @client.should_receive( :salt_password ).with( 'authkey' , @password ).and_return( 'salted_password' )
      @client.should_receive( :send_salty_password ).with( @mock_sock, 'salted_password' ).and_return( "AUTHORIZED" )

      # Act
      @client.authenticate_with_server(@mock_sock, 'User!', 'pAsswurd')
    end

    it "should handle unsuccessful authentication with server" do
      # Expect
      @client.should_receive( :send_username ).with( @mock_sock, @username ).and_return( 'authkey' )
      @client.should_receive( :salt_password ).with( 'authkey' , @password ).and_return( 'salted_password' )
      @client.should_receive( :send_salty_password ).with( @mock_sock, 'salted_password' ).and_return( "NOT AUTHORIZED" )
      @client.should_receive( :puts ).with( "NOT AUTHORIZED")
      # Act
      lambda{
        @client.authenticate_with_server(@mock_sock, 'User!', 'pAsswurd')
      }.should raise_error(UWChat::Client::NotAuthorized)
    end

    it "should send username" do
      # Expect
      @mock_sock.should_receive( :puts ).with( @username )
      @mock_sock.should_receive( :flush )
      @mock_sock.should_receive( :gets ).and_return( 'authkey' )

      # Act
      ret = @client.send_username( @mock_sock, @username )
      ret.should == 'authkey'
    end

    it "should send salty password" do
      # Expect
      @mock_sock.should_receive( :puts ).with( 'salted_password' )
      @mock_sock.should_receive( :flush )
      @mock_sock.should_receive( :gets ).and_return( 'AUTHORIZED' )

      # Act
      auth_message = @client.send_salty_password(@mock_sock, 'salted_password')
      auth_message.should == 'AUTHORIZED'
    end

    it "should salt a password" do

      # Act
      salty_password = @client.salt_password( 'authkey', @password )

      # Assert
      salty_password.should == ( Digest::MD5.hexdigest('authkey' + @password) )
    end
  
  end

  describe "Messaging" do

    before( :each ) do
      # Arrange
      @client = UWChat::Client.new
      @mock_sock = mock( 'socket' )
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


  end

end