
require 'uwchat'

describe UWChat::Server do
  before(:each) do
    @server = UWChat::Server.new( 12345 )
    @server.audit = true
    @server.debug = true
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
      @server.should_receive(:find_client_by_socket).and_return( @server.add_client(1, 'larry') )
      # Act
      @server.welcome_client( mock_io )
    end

    it "should default to port 36963" do
      @svr_36963 = UWChat::Server.new
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
      @server.add_client( 12235, sock2, 'larry' )

      client = @server.clients[0]
      client.port.should == 12234
      client.username.should == 'chat34'
      client = @server.clients[1]
      client.port.should == 12235
      client.username.should == 'larry'
    end

    it "should add clients to @clients as they connect" do
      # Arrange
      sock = stub('socket')
      @server.add_client( 1, sock, 'steve' )
      client_socket = stub(:peeraddr => [nil, 36969])

      # Act
      @server.connecting( client_socket )
      client = @server.clients[1]

      # Assert
      client.port.should == 36969
      client.username.should == 'chat69'
      @server.clients.size.should == 2
    end

    it "should remove clients at time of disconnect" do
      @server.add_client( 1, mock('steve_sock'), 'steve' )
      @server.add_client( 10_000, mock('penelope_sock'), 'penelope' )
      @server.clients.size.should == 2

      @server.disconnecting( 10_000 )
      client = @server.clients.last
      client.port.should == 1
      client.username.should == 'steve'
      @server.clients.size.should == 1
    end 

    it "should add clients to @clients via add_client()" do
      sock = stub('socket')
      @server.clients.size.should == 0
      @server.add_client( 1, sock, 'steve' )
      @server.add_client( 36966, sock, 'larry' )
      @server.clients.size.should == 2
      @server.clients.first.port == 1
      @server.clients.last.username == 'larry'
    end

    it "should remove clients from @clients via remove_client()" do
      sock = stub('socket')
      @server.add_client( 1, sock, 'steve' )
      @server.add_client( 36966, sock, 'larry' )
      @server.add_client( 100, sock, 'sue' )
      @server.clients.size.should == 3

      # Act
      @server.remove_client( 36966 )

      # Assert
      @server.clients.size.should == 2
      @server.clients.map{ |c| c.username }.should_not include( 'larry' )
    end

    it "should be able to find client by socket" do
      @server.add_client( 1, mock('steve_sock'), 'steve' )
      @server.add_client( 36966, mock('larry_sock'), 'larry' )
      @server.add_client( 100, mock('sue_sock'), 'sue' )

      mock_sock = mock()
      mock_sock.should_receive( :addr ).and_return( [nil, 36966] )
      client = @server.find_client_by_socket( mock_sock )
      client.port.should == 36966
      client.username.should == 'larry'
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
      @server.add_client( 1, mock_sock1, 'steve' )
      @server.add_client( 36966, mock_sock2, 'larry' )
      @server.add_client( 100, mock_sock3, 'sue' )

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
      sender = @server.add_client( 100, mock_sock_sender, 'larry' )
      @server.add_client( 1, mock_sock1, 'steve' )
      @server.add_client( 36966, mock_sock2, 'susan' )

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
end