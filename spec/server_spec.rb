PASSWD_FILEPATH = File.join( File.dirname(__FILE__), 'passwd' )
MALFORMED_PASSWD_FILEPATH = File.join( File.dirname(__FILE__), 'passwd_malformed' )
require 'uwchat'

describe UWChat::Server do
  before(:each) do
    @server = UWChat::Server.new( PASSWD_FILEPATH, 12345 )
    @server.audit = true
  end

  describe "Project structure" do

    it "should contain required classes" do
      @server.class.ancestors.should include GServer
      UWChat::Connection.should be_true
    end

  end

  describe "Network properties" do

    it "should greet the user" do
      # Arrange
      mock_io = mock( 'socket')
      # Expect
      mock_io.should_receive(:puts).with( /^Welcome / )
      @server.should_receive(:find_client_by_socket).and_return( @server.add_client(1, stub()) )
      # Act
      @server.welcome_client( mock_io )
    end

    it "should default to port 36963" do
      @svr_36963 = UWChat::Server.new( PASSWD_FILEPATH )
      @svr_36963.start
      @svr_36963.instance_variable_get( :@port ).should == 36963
      @svr_36963.shutdown
    end

  end

  describe "Multi-Client management" do

    it "should optionally generate a username when adding clients" do
      sock1 = stub('socket')
      @server.add_client( 12234, sock1 )
      sock2 = stub('socket')
      @server.add_client( 12235, sock2 )

      client = @server.clients[0]
      client.port.should == 12234
      client = @server.clients[1]
      client.port.should == 12235
    end

    it "should add clients to @clients as they connect" do
      # Arrange
      sock = stub('socket')
      @server.add_client( 1, sock )
      client_socket = stub(:peeraddr => [nil, 36969])

      # Act
      @server.connecting( client_socket )
      client = @server.clients[1]

      # Assert
      client.port.should == 36969
      @server.clients.size.should == 2
    end

    it "should remove clients at time of disconnect" do
      @server.add_client( 1, mock('sock1') )
      @server.add_client( 10_000, mock('sock2') )
      @server.clients.size.should == 2

      @server.disconnecting( 10_000 )
      client = @server.clients.last
      client.port.should == 1
      @server.clients.size.should == 1
    end 

    it "should add clients to @clients via add_client()" do
      sock = stub('socket')
      @server.clients.size.should == 0
      @server.add_client( 1, sock )
      @server.add_client( 36966, sock )
      @server.clients.size.should == 2
      @server.clients.first.port == 1
    end

    it "should remove clients from @clients via remove_client()" do
      sock = stub('socket')
      @server.add_client( 1, sock )
      @server.add_client( 36966, sock )
      @server.add_client( 100, sock )
      @server.clients.size.should == 3

      # Act
      @server.remove_client( 36966 )

      # Assert
      @server.clients.size.should == 2
      @server.clients.map{ |c| c.port }.should_not include( 36966 )
    end

    it "should be able to find client by socket" do
      @server.add_client( 1, mock('steve_sock') )
      @server.add_client( 36966, mock('larry_sock') )
      @server.add_client( 100, mock('sue_sock') )

      mock_sock = mock()
      mock_sock.should_receive( :addr ).and_return( [nil, 36966] )
      client = @server.find_client_by_socket( mock_sock )
      client.port.should == 36966
    end

  end

  describe "Message processing" do

    it "should send and log broadcast messages to all users" do
      # Arrange
      msg = "Broadcast Message"
      expected_msg_recieved = "Announce: #{msg}"
      mock_sock1 = mock( 'socket1' )
      mock_sock2 = mock( 'socket2' )
      mock_sock3 = mock( 'socket3' )
      @server.add_client( 1, mock_sock1 )
      @server.add_client( 36966, mock_sock2 )
      @server.add_client( 100, mock_sock3 )

      # Expect
      mock_sock1.should_receive( :puts ).with( expected_msg_recieved )
      mock_sock2.should_receive( :puts ).with( expected_msg_recieved )
      mock_sock3.should_receive( :puts ).with( expected_msg_recieved )
      @server.should_receive( :log ).with( "[broadcast] #{msg}" )

      # Act
      @server.broadcast( msg )
    end

    it "should send and log private messages to one user" do

      # Arrange
      msg = "Private Message"
      sender = 'larry'
      mock_sock = mock( 'socket' )

      # Expect
      mock_sock.should_receive( :puts ).with( /^#{sender}: #{msg}$/ )
      recipient = stub(:port => 20_000, :sock => mock_sock, :username => 'recipient')
      @server.should_receive( :log ).with( "[private] #{sender} to #{recipient}: #{msg}" )

      # Act
      @server.private(msg, sender, recipient)
    end

    it "should send and log normal messages to every other user" do
      # Arrange
      msg = "Chat Message"
      expected_msg_recieved = "larry: #{msg}"

      mock_sock_sender = mock( 'socket_sender' )
      mock_sock1 = mock( 'socket1' )
      mock_sock2 = mock( 'socket2' )
      sender = @server.add_client( 100, mock_sock_sender )
      sender.instance_variable_set( :@username, 'larry')
      @server.add_client( 1, mock_sock1 )
      @server.add_client( 36966, mock_sock2 )

      # Expect
      mock_sock_sender.should_not_receive( :puts )
      mock_sock1.should_receive( :puts ).with( expected_msg_recieved )
      mock_sock2.should_receive( :puts ).with( expected_msg_recieved )
      @server.should_receive( :log ).with( "[message] larry: #{msg}" )

      # Act
      @server.message( msg, sender )
    end

  end

  describe "Network Listener" do

    it "should send received text out as a message" do
      # Assemble
      msg = 'a chat message'
      mock_socket = mock( 'socket' )

      # Expect
      mock_socket.should_receive( :gets ).and_return( msg )
      @server.should_receive( :find_client_by_socket).with( mock_socket ).and_return( mock_socket )
      @server.should_receive( :message ).with( msg, mock_socket )

      # Act
      @server.listen( mock_socket )
    end
  end

  describe "Full network stack tests" do 

    it "should add clients at time of connection - full stack" do
      @server.clients.size.should == 0
      @server.audit = true; @server.debug = true
      @server.start
      client_session1 = nil
      client_session2 = nil
      t1 = Thread.new { client_session1 = TCPSocket.new('localhost', 12345) }
      sleep 1
      client_session1.should be_true
      @server.clients.size.should == 1
      @server.clients[0].port.should == client_session1.addr[1]

      client_session2 = nil
      t2 = Thread.new { client_session2 = TCPSocket.new('localhost', 12345) }
      sleep 0.2
      @server.clients[1].port.should == client_session2.addr[1]

      t1.kill
      t2.kill 
      @server.shutdown
    end

  end

  describe "Authentication" do

    before(:each) do
      @mock_io = mock( 'socket')
      @username = 'alice'
      @password = 'p4s$w0rd!'
    end

    it "should require a passwd file to start server" do
      lambda{ UWChat::Server.new( 12345 )}.should raise_error( ArgumentError )
      lambda{ UWChat::Server.new( MALFORMED_PASSWD_FILEPATH, 12345 )}.should raise_error( ArgumentError )
    end

    it "should generate a unique salt string" do
      salt1 = @server.salt('hi')
      
      # salt is NOT unique when called within a one second window
      sleep 1

      salt2 = @server.salt('hi')
      salt1.should_not == salt2
    end

    it "should follow challange response protocol when client connects" do
      # Arrange
      @authkey = @server.salt( @username )
      @salty_password = Digest::MD5.hexdigest( @authkey + @password )
      client = stub()

      # Expect
      @mock_io.should_receive(:gets).and_return( @username )
      @mock_io.should_receive(:gets).and_return( @salty_password )
      @mock_io.should_receive(:puts).twice
      @server.should_receive(:valid_password?).with( @salty_password, @authkey, @username ).and_return( true )
      @server.should_receive(:find_client_by_socket).and_return( client )
      client.should_receive(:username=)
 
      # Act
      @server.authenticate( @mock_io )
    end

  end

  describe "Password Validation" do

    before(:each) do
      @mock_io = mock( 'socket')
      @username = 'alice'
      @password = 'p4s$w0rd!'
    end

    it "should validate a salted password" do
      # Arrange
      @authkey = @server.salt( @username )
      @salty_password = Digest::MD5.hexdigest( @authkey + @password )

      # Act
        @server.valid_password?( @salty_password, @authkey, @username ).should be_true
    end

    it "should reject an incorrect salted password" do
      # Arrange
      @authkey = @server.salt( @username )
      @salty_password = Digest::MD5.hexdigest( @authkey + @password )

      # Act
      @server.valid_password?( @salty_password << 'a', @authkey, @username ).should be_false
      @server.valid_password?( 'incorrect_salty_pass', @authkey, @username ).should be_false
    end

    it "should reject an incorrect username" do
      # Arrange
      @authkey = @server.salt( @username )
      @salty_password = Digest::MD5.hexdigest( @authkey + @password )

      # Act
      @server.valid_password?( @salty_password, @authkey, 'invalid_user' ).should be_false
    end

    it "should reject a blank username and password" do
      # Arrange
      @authkey = @server.salt( @username )
      @salty_password = Digest::MD5.hexdigest( @authkey + @password )

      # Act
      @server.valid_password?( '', @authkey, '' ).should be_false
    end

    it "should raise an error when passed a nil username and password" do
      # Arrange
      @authkey = @server.salt( @username )
      @salty_password = Digest::MD5.hexdigest( @authkey + @password )

      # Act
      @server.valid_password?( nil, @authkey, nil ).should be_false
    end

  end


end