
require 'uwchat'

describe UWChat::Connection do

  it "should provide attributes" do
    sock = stub
    @conn = UWChat::Connection.new( 1000, sock, 'brandon')
    @conn.port.should == 1000
    @conn.sock.should be_true
    @conn.username.should == 'brandon'
  end

  it "should provide to_s method" do
    sock = stub
    @conn = UWChat::Connection.new( 1001, sock, 'larry')
    @conn.port.should == 1001
    @conn.username.should == 'larry'
    @conn.to_s.should == 'larry'
  end

  it "should provide to_s method which uses port if username is nil" do
    sock = stub
    @conn = UWChat::Connection.new( 1002, sock)
    @conn.port.should == 1002
    @conn.username.should be_nil
    @conn.to_s.should == '1002'
  end

end