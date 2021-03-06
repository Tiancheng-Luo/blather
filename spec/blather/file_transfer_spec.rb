require 'spec_helper'
require 'blather/client/dsl'

module MockFileReceiver
  def post_init
  end
  def receive_data(data)
  end
  def unbind
  end
  def send(data, params)
  end
end

def si_xml
<<-XML
  <iq type='set' id='offer1' to='juliet@capulet.com/balcony' from='romeo@montague.net/orchard'>
    <si xmlns='http://jabber.org/protocol/si'
        id='a0'
        mime-type='text/plain'
        profile='http://jabber.org/protocol/si/profile/file-transfer'>
      <file xmlns='http://jabber.org/protocol/si/profile/file-transfer'
            name='test.txt'
            size='1022'>
        <range/>
      </file>
      <feature xmlns='http://jabber.org/protocol/feature-neg'>
        <x xmlns='jabber:x:data' type='form'>
          <field var='stream-method' type='list-single'>
            <option><value>http://jabber.org/protocol/bytestreams</value></option>
            <option><value>http://jabber.org/protocol/ibb</value></option>
          </field>
        </x>
      </feature>
    </si>
  </iq>
XML
end

describe Blather::FileTransfer do
  before do
    @host = 'host.name'
    @client = Blather::Client.setup Blather::JID.new('n@d/r'), 'pass'
  end

  it 'can select ibb' do
    iq = Blather::XMPPNode.parse(si_xml)

    @client.stubs(:write).with do |answer|
      expect(answer.si.feature.x.field('stream-method').value).to eq(Blather::Stanza::Iq::Ibb::NS_IBB)
      true
    end

    transfer = Blather::FileTransfer.new(@client, iq)
    transfer.allow_s5b = false
    transfer.allow_ibb = true
    transfer.accept(MockFileReceiver)
  end

  it 'can select s5b' do
    iq = Blather::XMPPNode.parse(si_xml)

    @client.stubs(:write).with do |answer|
      expect(answer.si.feature.x.field('stream-method').value).to eq(Blather::Stanza::Iq::S5b::NS_S5B)
      true
    end

    transfer = Blather::FileTransfer.new(@client, iq)
    transfer.allow_s5b = true
    transfer.allow_ibb = false
    transfer.accept(MockFileReceiver)
  end

  it 'can allow s5b private ips' do
    iq = Blather::XMPPNode.parse(si_xml)

    @client.stubs(:write).with do |answer|
      expect(answer.si.feature.x.field('stream-method').value).to eq(Blather::Stanza::Iq::S5b::NS_S5B)
      true
    end

    transfer = Blather::FileTransfer.new(@client, iq)
    transfer.allow_s5b = true
    transfer.allow_private_ips = true
    transfer.allow_ibb = false
    transfer.accept(MockFileReceiver)
  end

  it 'can response no-valid-streams' do
    iq = Blather::XMPPNode.parse(si_xml)

    @client.stubs(:write).with do |answer|
      expect(answer.find_first('error')['type']).to eq("cancel")
      expect(answer.find_first('.//ns:no-valid-streams', :ns => 'http://jabber.org/protocol/si')).not_to be_nil
      true
    end

    transfer = Blather::FileTransfer.new(@client, iq)
    transfer.allow_s5b = false
    transfer.allow_ibb = false
    transfer.accept(MockFileReceiver)
  end

  it 'can decline transfer' do
    iq = Blather::XMPPNode.parse(si_xml)

    @client.stubs(:write).with do |answer|
      expect(answer.find_first('error')['type']).to eq("cancel")
      expect(answer.find_first('.//ns:forbidden', :ns => 'urn:ietf:params:xml:ns:xmpp-stanzas')).not_to be_nil
      expect(answer.find_first('.//ns:text', :ns => 'urn:ietf:params:xml:ns:xmpp-stanzas').content).to eq("Offer declined")
      true
    end

    transfer = Blather::FileTransfer.new(@client, iq)
    transfer.decline
  end

  it 'can s5b post_init include the handler' do
    class TestS5B < Blather::FileTransfer::S5b::SocketConnection
      def initialize()
        super("0.0.0.0", 1, MockFileReceiver, nil)
        restore_methods
        self.post_init()
      end

      def self.new(*args)
        allocate.instance_eval do
          initialize(*args)
          self
        end
      end
    end
    expect { TestS5B.new }.not_to raise_error
  end
end
