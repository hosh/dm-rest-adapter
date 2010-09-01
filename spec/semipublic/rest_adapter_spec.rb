require 'spec_helper'
require 'yajl'

describe DataMapper::Adapters::RestAdapter do

  let(:adapter) { 
    #DataMapper.setup(:default, {
    #  :adapter => :rest,
    #  :host => 'example.org',
    #  #:port => 4000
    #})
    DataMapper.setup(:default, 'rest://example.org:9999')
    DataMapper::Repository.adapters[:default] }
  let(:hydra) { Typhoeus::Hydra.hydra }

  let(:resource) { ::Resource.new(resource_attributes) }
  let(:resource_attributes) { { :name => 'Name' } }
  let(:existing_resource_attributes) { resource_attributes.merge({:id => resource_id }) }
  let(:resources) { [ resource ] }
  let(:resource_id) { 1 }

  let(:stub_url) { 'http://example.org:9999/resources' }
  let(:stub_method) { :get }
  let(:stubbed_response_code) { 200 }
  let(:stubbed_response_headers) { Hash.new }
  let(:stubbed_response_body) { Yajl::Encoder.encode(respond_with) }
  let(:respond_with) { '' }
  let(:stubbed_response) { Typhoeus::Response.new(
    :code => stubbed_response_code, 
    :headers => stubbed_response_headers, 
    :body => stubbed_response_body) }
  let(:stubbed_hydra) { hydra.clear_stubs; hydra.stub(stub_method, stub_url).and_return(stubbed_response) }


  describe '#create' do
    let(:stub_method) { :post }
    let(:stubbed_response_code) { 201 }
    let(:respond_with) { { :resource => existing_resource_attributes } }
    let(:response) { stubbed_hydra; adapter.create(resources) }
    
    it 'should return an Array containing the Resource' do
      response.should eql(resources)
    end

    it 'should set the identity field' do
      response.first.id.should eql(resource_id)
    end
  end

  pending '#read' do
    let(:collection) { [ existing_resource_attributes ] }
    let(:respond_with) { collection }
    let(:response) { stubbed_hydra; adapter.read(query) }

    describe 'with unscoped query' do
      let(:query) { Resource.all.query }

      it 'should return an array with the matching records' do
        response.should eql([ existing_resource_attributes ])
      end
    end

    describe 'with query scoped by a key' do
      let(:query) { Resource.all(:id => 1, :limit =>1).query }

      it 'should return an array with the matching records' do
        response.should eql([ existing_resource_attributes ])
      end
    end

    describe 'with query scoped by a non-key' do
      let(:collection) { [ existing_resource_attributes, { :id => 2, :name => 'Someone Else' } ] }
      let(:query) { Resource.all(:name => 'Name') }

      it 'should return an array with the matching records' do
        response.should eql([ existing_resource_attributes ])
      end
    end

    describe 'with a non-standard model <=> storage_name relationship' do
      let(:query) { NonStandardResource.all.query }

      it 'should return an array with the matching records' do
        response.should eql([ existing_resource_attributes ])
      end
    end
  end

  describe '#update' do
    let(:collection) { [ existing_resource_attributes ] }
    let(:stubbed_hydra) { hydra.clear_stubs; hydra.stub(:post, url).and_return(stubbed_response) }
    let(:stubbed_response) { Typhoeus::Response.new(:code => 200, :headers => headers, :body => Yajl::Encoder.encode(collection)) }
    let(:response) { stubbed_response; adapter.update({Resource.properties[:name] => 'Another Name'}, resources) }
    let(:resources) { Resource.all }

    pending 'should return the number of updated Resources' do
      response.should == 1
    end

    pending 'should modify the Resource' do
      resources.first.author.should == 'John Doe'
    end
  end

  describe '#delete' do
    let(:collection) { [ existing_resource_attributes ] }
    let(:stubbed_hydra) { hydra.clear_stubs; hydra.stub(:delete, url).and_return(stubbed_response) }
    let(:stubbed_response) { Typhoeus::Response.new(:code => 204, :headers => headers, :body => Yajl::Encoder.encode(collection)) }
    let(:response) { stubbed_response; adapter.delete(resources) }
    let(:resources) { Resource.all }

    pending 'should return the number of updated Resources' do
      response.should == 1
    end
  end
end
