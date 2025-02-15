require 'spec_helper'

describe Export do
  include_context 'uses temp dir'

  let(:team) { Fabricate(:team) }

  before do
    allow(team.slack_client).to receive(:conversations_open).and_return(Hashie::Mash.new('channel' => { 'id' => 'dm' }))
  end

  context 'team' do
    context 'an export' do
      let(:export) { Fabricate(:team_export, team: team) }

      context 'target' do
        it 'is a team' do
          expect(export.target).to eq team
          expect(export.channel).to be_nil
        end
      end

      it 'target_s' do
        expect(export.target_s).to eq 'team'
      end

      it 'export!' do
        expect(export).to receive(:notify!)
        expect(team).to receive(:export!).with("#{Dir.tmpdir}/slack-sup2/#{export._id}/#{team.team_id}", {}).and_call_original
        filename = export.export!
        expect(File.exist?(filename)).to be true
      end

      it 'notify!' do
        allow(export).to receive(:short_lived_token).and_return('token')
        expect(export.team.slack_client).to receive(:chat_postMessage).with(
          hash_including(
            attachments: [
              actions: [
                text: 'Download',
                type: 'button',
                url: "#{SlackRubyBotServer::Service.url}/api/data/#{export.id}?access_token=token"
              ],
              attachment_type: 'default',
              text: ''
            ],
            channel: 'dm',
            text: 'Click here to download your team data.'
          )
        )
        export.notify!
      end
    end

    context 'with a max_rounds_count' do
      let(:export) { Fabricate(:team_export, team: team, max_rounds_count: 5) }

      it 'export!' do
        expect(export).to receive(:notify!)
        expect(team).to receive(:export!).with(
          "#{Dir.tmpdir}/slack-sup2/#{export._id}/#{team.team_id}", {
            max_rounds_count: 5
          }
        ).and_call_original
        export.export!
      end
    end
  end

  context 'channel' do
    let(:channel) { Fabricate(:channel, team: team) }

    context 'an export' do
      let(:export) { Fabricate(:channel_export, channel: channel) }

      context 'target' do
        it 'is a channel' do
          expect(export.target).to eq channel
          expect(export.channel).to eq channel
          expect(export.team).to eq channel.team
        end
      end

      it 'target_s' do
        expect(export.target_s).to eq "#{channel.slack_mention} channel"
      end

      it 'export!' do
        expect(export).to receive(:notify!)
        expect(channel).to receive(:export!).with("#{Dir.tmpdir}/slack-sup2/#{export._id}/#{channel.channel_id}", {}).and_call_original
        filename = export.export!
        expect(File.exist?(filename)).to be true
      end

      it 'notify!' do
        allow(export).to receive(:short_lived_token).and_return('token')
        expect(export.team.slack_client).to receive(:chat_postMessage).with(
          hash_including(
            attachments: [
              actions: [
                text: 'Download',
                type: 'button',
                url: "#{SlackRubyBotServer::Service.url}/api/data/#{export.id}?access_token=token"
              ],
              attachment_type: 'default',
              text: ''
            ],
            channel: 'dm',
            text: "Click here to download your #{channel.slack_mention} channel data."
          )
        )
        export.notify!
      end

      context 'with a max_rounds_count' do
        let(:export) { Fabricate(:channel_export, channel: channel, max_rounds_count: 7) }

        it 'export!' do
          expect(export).to receive(:notify!)
          expect(channel).to receive(:export!).with(
            "#{Dir.tmpdir}/slack-sup2/#{export._id}/#{channel.channel_id}", {
              max_rounds_count: 7
            }
          ).and_call_original
          export.export!
        end
      end
    end
  end
end
