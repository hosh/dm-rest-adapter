require 'spec_helper'

describe DataMapperRest::Connection do
  subject { connection }
  let(:connection) { DataMapperRest::Connection.new({ :site_uri => uri, :format => :json}) }
  let(:username) { 'admin' }
  let(:password) { 'password' }
  let(:host) { 'example.org' }
  let(:uri) { 
    Addressable::URI.new(
      :scheme => 'http',
      :user => username,
      :password => password,
      :host => host,
      :port => '4000',
      :query => nil ) }

  context 'when constructing a valid uri' do
    subject { connection.site_uri }
    let(:connection_site_uri) { subject.to_s }
    let(:connection_host) { subject.host }
    let(:connection_user) { subject.user }
    let(:connection_password) { subject.password }
    
    it { connection_site_uri.should eql("http://#{username}:#{password}@#{host}:4000") }
    it { connection_host.should eql(host) }
    it { connection_user.should eql(username) }
    it { connection_password.should eql(password) }
  end

  pending "should return the correct extension and mime type for xml" do
    connection.format.header.should eql({'Content-Type' => "application/xml"})
  end

  pending "should return the correct extension and mime type for json" do
    connection.format.header.should == {'Content-Type' => "application/json"}
  end

  context 'when handling HTTP verbs' do
    %w(head get post put delete).each do |verb|
      it "should respond to http_#{verb}" do
        connection.should respond_to("http_#{verb}")
      end
    end
  end

  context "when receiving error response codes" do
    let(:request) { Typhoeus::Request.new(uri.to_s) }
    let(:hydra) { Typhoeus::Hydra.hydra } # Need to make a non-singleton hydra queue in the connection

    def self.expects_exception_on(status_code, exception)
      it "should raise exception #{exception} on #{status_code}" do
        _response = Typhoeus::Response.new(:code => status_code, :headers => '', :body => exception.to_s, :time => 0.1)
         hydra.clear_stubs
         hydra.stub(:post, (uri + '/').to_s).and_return(_response)
        lambda {
          connection.http_post('/', :payload => { :foo => :bar }.to_json )
        }.should raise_error(exception)
      end
    end

    expects_exception_on(301, DataMapperRest::Redirection)

    expects_exception_on(401, DataMapperRest::ClientError)
    expects_exception_on(400, DataMapperRest::BadRequest)
    expects_exception_on(404, DataMapperRest::ResourceNotFound)
    expects_exception_on(405, DataMapperRest::MethodNotAllowed)
    expects_exception_on(409, DataMapperRest::ResourceConflict)
    expects_exception_on(422, DataMapperRest::ResourceInvalid)

    expects_exception_on(500, DataMapperRest::ServerError)
  end
end
