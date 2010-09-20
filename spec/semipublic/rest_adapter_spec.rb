require 'spec_helper'
require 'yajl'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/hash/keys'

# Brute force stubbing
module Typhoeus
  class HydraMock
    def matches?(request)
      true
    end
  end
end

# TODO: Need helpers to generate mock attributes

describe DataMapper::Adapters::RestAdapter do

  let(:adapter) { 
    #DataMapper.setup(:default, {
    #  :adapter => :rest,
    #  :host => 'example.org',
    #  #:port => 4000
    #})
    DataMapper.setup(:default, 'rest://example.org:9999')
    DataMapper::Repository.adapters[:default] }
  let(:repository) { DataMapper.repository(:default) }
  let(:identity_map) { repository.identity_map(Resource) }
  let(:hydra) { Typhoeus::Hydra.hydra }

  let(:resource) { ::Resource.new(resource_attributes) }
  let(:resource_attributes) { { :name => 'Name' }.stringify_keys }
  let(:existing_resource_attributes) { resource_attributes.merge({:id => resource_id }).stringify_keys }
  let(:existing_nested_resource_attributes) { existing_resource_attributes.merge({:parent_id => parent_id }).stringify_keys }
  let(:resources) { [ resource ] }
  let(:resource_id) { 1 }
  let(:parent_id) { 2 }

  let(:collection_url) { 'http://example.org:9999/resources' }
  let(:resource_url) { 'http://example.org:9999/resources/1' }
  let(:stub_url) { collection_url }
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
    
    context 'with a top-level resource' do
      it 'should return an Array containing the Resource' do
        response.should eql(resources)
      end

      it 'should set the identity field' do
        response.first.id.should eql(resource_id)
      end
    end

    pending 'with a nested resource' do
      it 'should return an Array containing the Resource' do
        response.should eql(resources)
      end

      it 'should set the identity field' do
        response.first.id.should eql(resource_id)
      end
    end
  end

  describe '#read' do
    let(:respond_with) { collection }
    let(:response) { stubbed_hydra; adapter.read(query) }

    context 'with a top-level resource' do
      let(:collection) { [ { :resource => existing_resource_attributes }.with_indifferent_access ] }
      context 'with unscoped query' do
        let(:query) { Resource.all.query }

        it 'should return an array with the matching records' do
          response.should eql([ existing_resource_attributes ])
        end
      end

      context 'with query scoped by a key' do
        let(:stub_url) { resource_url }
        let(:respond_with) { { :resource => existing_resource_attributes } }
        let(:query) { Resource.all(:id => 1, :limit => 1 ).query }

        it 'should return an array with the matching records' do
          response.should eql([ existing_resource_attributes ])
        end
      end

      context 'with query scoped by a non-key' do
        let(:collection) { [ { :resource => existing_resource_attributes }, 
          { :resource => { :id => 2, :name => 'Someone Else' }.stringify_keys } ].map(&:stringify_keys) }
        let(:query) { Resource.all(:name => 'Name').query }

        it 'should return an array with the matching records' do
          response.should eql([ existing_resource_attributes ])
        end
      end

      context 'with a non-standard model <=> storage_name relationship' do
        let(:query) { NonStandardResource.all.query }

        it 'should return an array with the matching records' do
          response.should eql([ existing_resource_attributes ])
        end
      end
    end
  
    context 'with a nested resource' do
      let(:collection) { [ { :nested_resource => existing_nested_resource_attributes }.with_indifferent_access ] }
      let(:nested_resource) { { :nested_resource => existing_nested_resource_attributes }.with_indifferent_access }
      context 'with unscoped query' do
        let(:query) { NestedResource.all.query }

        it 'should return an array with the matching records' do
          response.should eql([ existing_nested_resource_attributes ])
        end
      end

      context 'with query scoped by the complete composite primary key' do
        let(:stub_url) { resource_url }
        let(:respond_with) { nested_resource }
        let(:query) { NestedResource.all(:id => 1, :parent_id => 2, :limit => 1 ).query }

        it 'should return an array with the matching records' do
          response.should eql([ existing_nested_resource_attributes ])
        end
      end

      context 'with query scoped by parent key' do
        let(:stub_url) { resource_url }
        let(:respond_with) { [ nested_resource ] }
        let(:query) { NestedResource.all(:parent_id => 2, :limit => 1 ).query }

        it 'should return an array with the matching records' do
          response.should eql([ existing_nested_resource_attributes ])
        end
      end

      context 'with query scoped by a key' do
        let(:stub_url) { resource_url }
        let(:respond_with) { [ nested_resource ] }
        let(:query) { NestedResource.all(:id => 1, :limit => 1 ).query }

        it 'should return an array with the matching records' do
          response.should eql([ existing_nested_resource_attributes ])
        end
      end

      context 'with query scoped by a non-key' do
        let(:collection) { [ { :nested_resource => existing_nested_resource_attributes }, 
          { :nested_resource => { :id => 2, :parent_id => 2, :name => 'Someone Else' }.stringify_keys } ].map(&:stringify_keys) }
        let(:query) { NestedResource.all(:name => 'Name').query }

        it 'should return an array with the matching records' do
          response.should eql([ existing_nested_resource_attributes ])
        end
      end
    end
  end

  describe '#update' do
    let(:another_name) { 'John Doe' }
    let(:response) { stubbed_hydra; adapter.update({Resource.properties[:name] => another_name}, resources) }
    let(:resources) { Resource.load([ existing_resource_attributes ], Resource.all.query ) }

    context 'with a top-level resource' do
      context 'when service does not return a json object' do
        let(:respond_with) { '' }

        it 'should return the number of updated Resources' do
          response.should eql(0)
        end

        it 'should modify the Resource' do
          response.should eql(0)
          resources.first.name.should eql(another_name)
        end
      end

      context 'when service returns a json object' do
        let(:respond_with) { { 'resource' => existing_resource_attributes.merge(:name => another_name) } }

        it 'should return the number of updated Resources' do
          response.should eql(1)
        end

        it 'should modify the Resource' do
          response.should eql(1)
          resources.first.name.should eql(another_name)
        end
      end
    end

    pending 'with a nested resource' do
      context 'when service does not return a json object' do
        let(:respond_with) { '' }

        it 'should return the number of updated Resources' do
          response.should eql(0)
        end

        it 'should modify the Resource' do
          response.should eql(0)
          resources.first.name.should eql(another_name)
        end
      end

      context 'when service returns a json object' do
        let(:respond_with) { { 'resource' => existing_resource_attributes.merge(:name => another_name) } }

        it 'should return the number of updated Resources' do
          response.should eql(1)
        end

        it 'should modify the Resource' do
          response.should eql(1)
          resources.first.name.should eql(another_name)
        end
      end
    end

  end

  describe '#delete' do
    let(:response) { stubbed_hydra; adapter.delete(resources) }
    let(:resources) { Resource.load([ existing_resource_attributes ], Resource.all.query ) }

    context 'with a top-level resource' do 
      it 'should return the number of updated Resources' do
        response.should eql(1)
      end
    end

    pending 'with a nested resource' do
      it 'should return the number of updated Resources' do
        response.should eql(1)
      end
    end
  end

  context 'private API', :private_api => true do
    describe '#collection_path' do
      it 'should generate a collection path for a resource'
      it 'should generate a nested collection path for a nested resource'
    end

    describe '#resource_path' do
      let(:resource_path) { adapter.send(:resource_path, model, key) }

      context 'with a top-level resource' do
        let (:model) { ::Resource }
        let (:key) { [ 1 ] }

        it 'should generate resource path for resource with a primary key' do
          resource_path.should eql("resources/1")
        end
      end

      context 'with a nested resource' do
        let (:model) { ::NestedResource }
        let (:key) { [ 2, 1 ] }

        it 'should generate a nested resource path for a resource with a composite primary key' do
          resource_path.should eql("parents/2/resources/1")
        end
      end
    end

    describe '#extract_id_from_query' do
      subject { adapter.send(:extract_id_from_query, query) }

      context 'with a top-level resource' do
        context 'when querying by primary key, limit 1' do
          let(:query) { Resource.all(:id => 1, :limit => 1).query }

          it 'should extract the primary key from a resource' do
            should eql([1])
          end
        end

        context 'when querying by primary key, no limit' do
          let(:query) { Resource.all(:id => 1).query }
          it { should be_nil }
        end

        context 'when querying by multiple keys, limit 1' do
          let(:query) { Resource.all(:id => 1, :name => 'example' ).query }
          it { should be_nil }
        end
      end

      context 'with a nested resource' do
        context 'when querying by composite primary key, limit 1' do
          let(:query) { NestedResource.all(:id => 1, :parent_id => 2, :limit => 1).query }
          it 'should extract the composite primary key from a nested resource' do
            should eql([2,1])
          end
        end

        context 'when querying by composite primary key, no limit' do
          let(:query) { NestedResource.all(:id => 1, :parent_id => 2).query }
          it { should be_nil }
        end

        context 'when querying by parent key, limit 1' do
          let(:query) { NestedResource.all(:parent_id => 1, :limit => 1).query }
          it { should be_nil }
        end

        context 'when querying by id, limit 1' do
          let(:query) { NestedResource.all(:id => 1, :limit => 1).query }
          it { should be_nil }
        end

        context 'when querying by non-composite keys, limit 1' do
          let(:query) { NestedResource.all(:parent_id => 1, :name => 'blah', :limit => 1).query }
          it { should be_nil }
        end
      end
    end
  end
end
