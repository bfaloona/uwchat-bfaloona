
require 'uwchat'

describe UWChat::Server do
  before(:each) do
    @server = UWChat::Server.new
  end

  it "should inherit from GServer" do
    @server.class.ancestors.should include GServer
  end
end
