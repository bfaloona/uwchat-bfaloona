
require 'uwchat'

describe UWChat::Server do
  before(:each) do
    @server = UWChat::Server.new( 12345 )
    @server.audit = true
    @server.debug = true
  end

  describe "Object structure" do

    it "should inherit from GServer" do
      @server.class.ancestors.should include GServer
    end

    it "should define the required exceptions" do
      UWChat::AuthenticationFailed.should be_true
    end

  end

  describe "Network properties" do

    it "should greet the user" do
      # Arrange
      mock_io = mock( 'socket')
      # Expect
      mock_io.should_receive(:puts).with( /^Welcome / )
      @server.should_receive(:find_client_by_socket).and_return( @server.new_client(1, 'larry') )
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

    it "should add clients to @clients as they connect" do
      @server.new_client( 1, 'steve' )

      client_socket = stub(:peeraddr => [nil, 36969])

      @server.connecting( client_socket )
      client = @server.clients[1]
      client.port.should == 36969
      client.username.should == nil
      @server.clients.size.should == 2
    end

    it "should remove clients at time of disconnect" do
      @server.new_client( 1, 'steve' )
      @server.new_client( 10_000, 'penelope' )
      @server.clients.size.should == 2

      @server.disconnecting( 10_000 )
      client = @server.clients.last
      client.port.should == 1
      client.username.should == 'steve'
      @server.clients.size.should == 1
    end

    it "should add clients to @clients via add_client()" do
      @server.clients.size.should == 0
      @server.new_client( 1, 'steve' )
      @server.new_client( 36966, 'larry' )
      @server.clients.size.should == 2
      @server.clients.first.port == 1
      @server.clients.last.username == 'larry'
    end

    it "should remove clients from @clients via remove_client()" do
      @server.new_client( 1, 'steve' )
      @server.new_client( 36966, 'larry' )
      @server.new_client( 100, 'sue' )
      @server.clients.size.should == 3

      # Act
      @server.remove_client( 36966 )

      # Assert
      @server.clients.size.should == 2
      @server.clients.map{ |c| c.username }.should_not include( 'larry' )
    end

    it "should be able to find client by socket" do
      @server.new_client( 1, 'steve' )
      @server.new_client( 36966, 'larry' )
      @server.new_client( 100, 'sue' )

      mock_sock = mock()
      mock_sock.should_receive( :addr ).and_return( [nil, 36966] )
      client = @server.find_client_by_socket( mock_sock )
      client.port.should == 36966
      client.username.should == 'larry'
    end

  end

  describe "Full network stack tests" do
 
    it "should add clients at time of connection - full stack" do
      @server.clients.size.should == 0
      @server.audit = true; @server.debug = true
      @server.start
      client_session1 = nil
      Thread.new { client_session1 = TCPSocket.new('localhost', 12345) }
      sleep 1
      client_session1.should be_true
      @server.clients.size.should == 1
      @server.clients[0].port.should == client_session1.addr[1]

      client_session2 = nil
      Thread.new { client_session2 = TCPSocket.new('localhost', 12345) }
      sleep 0.2
      @server.clients[1].port.should == client_session2.addr[1]

      @server.shutdown
    end

  end
end